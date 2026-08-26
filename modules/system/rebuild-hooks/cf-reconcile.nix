{ pkgs, ... }:

# cf-reconcile — reads Cloudflare-related declarations from the flake and
# converges Cloudflare's control plane to match. Registers as
# `rebuild.preHooks.cf-tunnels` so `rebuild` runs it automatically before
# every deploy.
#
# Resources it manages:
#   - Tunnels + DNS records (per-host declaredTunnels)
#     Adding: edit hosts/<host>/hardware-layout/cloudflare-layout.nix, or add a
#             hostname to the `urls` of an app.json — apps/platform.nix turns
#             those into declaredTunnels entries and they arrive here the same way
#     Removing: NOT YET (manual via API/dashboard for now)
#   - Email routing rules (fleet-wide cloudflare.email.rules)
#     Adding: edit modules/system/networking/cloudflare-email.nix
#     Removing: warns; delete manually
#   - R2 buckets (fleet-wide cloudflare.r2.buckets)
#     Adding: edit modules/system/networking/cloudflare-r2.nix
#     Removing: NEVER auto-deletes (data loss risk); warns
#
# Authenticates with the Global API Key (X-Auth-Email + X-Auth-Key headers)
# instead of a scoped bearer token — one credential for the whole fleet
# instead of juggling scoped tokens per capability. Global Key rotation
# is done by changing your Cloudflare account password (regenerates the
# key as a side effect), then re-run `sops set` in secrets/common.yaml.
#
# Requires:
#   - `cloudflare-api-key` + `cloudflare-email` in secrets/common.yaml
#   - Age key at /var/lib/sops-nix/key.txt (sudo readable)
#   - Repo at $HOME/NixOS on the invoking machine

let
  cfAccountId = "9d41f4bba622cd7819f194785e1b9155";

  cfReconcile = pkgs.writeShellApplication {
    name = "cf-reconcile";
    runtimeInputs = with pkgs; [ nix jq curl sops coreutils ];
    text = ''
      set -euo pipefail

      REPO="''${NIXOS_REPO:-$HOME/NixOS}"
      ACCOUNT_ID="${cfAccountId}"

      # Decrypt the CF Global API Key + email (needs sudo to read the age key).
      CF_KEY="$(sudo env SOPS_AGE_KEY_FILE=/var/lib/sops-nix/key.txt \
        sops --decrypt --extract '["cloudflare-api-key"]' "$REPO/secrets/common.yaml")"
      CF_EMAIL="$(sudo env SOPS_AGE_KEY_FILE=/var/lib/sops-nix/key.txt \
        sops --decrypt --extract '["cloudflare-email"]' "$REPO/secrets/common.yaml")"

      cf_api() {
        local method="$1" path="$2" data="''${3:-}"
        if [[ -n "$data" ]]; then
          curl -sS -X "$method" \
            -H "X-Auth-Email: $CF_EMAIL" \
            -H "X-Auth-Key: $CF_KEY" \
            -H "Content-Type: application/json" \
            -d "$data" \
            "https://api.cloudflare.com/client/v4$path"
        else
          curl -sS -X "$method" \
            -H "X-Auth-Email: $CF_EMAIL" \
            -H "X-Auth-Key: $CF_KEY" \
            "https://api.cloudflare.com/client/v4$path"
        fi
      }

      zone_id_for() {
        local zone="$1"
        cf_api GET "/zones?name=$zone" | jq -r '.result[0].id // empty'
      }

      # ────────────────────────────────────────────────────────────────
      # 1. Tunnels + DNS
      # ────────────────────────────────────────────────────────────────
      echo "▸ tunnels"

      mapfile -t HOSTS < <(nix eval --json --impure --expr \
        "builtins.attrNames (builtins.getFlake \"path:$REPO\").nixosConfigurations" \
        | jq -r '.[]')

      any_changed=false

      for host in "''${HOSTS[@]}"; do
        [[ "$host" == "installer" ]] && continue

        declared_json="$(nix eval --json --impure --expr \
          "let cfg = (builtins.getFlake \"path:$REPO\").nixosConfigurations.\"$host\".config.cloudflare.declaredTunnels or {}; in cfg")"

        lock_file="$REPO/hosts/$host/hardware-layout/cf-tunnels.lock.json"
        current_lock="$(cat "$lock_file" 2>/dev/null || echo '{}')"

        for hostname in $(echo "$declared_json" | jq -r 'keys[]'); do
          existing_uuid="$(echo "$current_lock" | jq -r --arg h "$hostname" '.[$h].uuid // ""')"

          if [[ -n "$existing_uuid" ]]; then
            check="$(cf_api GET "/accounts/$ACCOUNT_ID/cfd_tunnel/$existing_uuid")"
            if [[ "$(echo "$check" | jq -r '.success')" == "true" && \
                  "$(echo "$check" | jq -r '.result.deleted_at // ""')" == "" ]]; then
              echo "  ✓ $hostname → $existing_uuid"
              continue
            fi
            echo "  ⚠ $hostname → $existing_uuid was deleted upstream; recreating"
          fi

          echo "  + creating tunnel for $hostname on $host"
          tunnel_secret_b64="$(head -c 32 /dev/urandom | base64)"

          create_payload="$(jq -n \
            --arg name "$host-$hostname" \
            --arg secret "$tunnel_secret_b64" \
            '{name: $name, tunnel_secret: $secret, config_src: "local"}')"
          create_resp="$(cf_api POST "/accounts/$ACCOUNT_ID/cfd_tunnel" "$create_payload")"

          if [[ "$(echo "$create_resp" | jq -r '.success')" != "true" ]]; then
            echo "  ✗ CF API error creating tunnel:" >&2
            echo "$create_resp" | jq . >&2
            exit 1
          fi

          uuid="$(echo "$create_resp" | jq -r '.result.id')"
          echo "    → UUID $uuid"

          creds_json="$(jq -n \
            --arg AccountTag "$ACCOUNT_ID" \
            --arg TunnelSecret "$tunnel_secret_b64" \
            --arg TunnelID "$uuid" \
            '{AccountTag: $AccountTag, TunnelSecret: $TunnelSecret, TunnelID: $TunnelID}')"

          zone_name="$(echo "$hostname" | awk -F. '{n=NF; print $(n-1)"."$n}')"
          zone_id="$(zone_id_for "$zone_name")"

          if [[ -z "$zone_id" ]]; then
            echo "  ✗ zone $zone_name not found in this Cloudflare account" >&2
            exit 1
          fi

          dns_payload="$(jq -n \
            --arg name "$hostname" \
            --arg content "$uuid.cfargotunnel.com" \
            '{type: "CNAME", name: $name, content: $content, proxied: true, ttl: 1}')"

          existing_dns="$(cf_api GET "/zones/$zone_id/dns_records?name=$hostname&type=CNAME")"
          existing_record_id="$(echo "$existing_dns" | jq -r '.result[0].id // ""')"

          if [[ -n "$existing_record_id" ]]; then
            cf_api PUT "/zones/$zone_id/dns_records/$existing_record_id" "$dns_payload" > /dev/null
            echo "    → DNS updated: $hostname CNAME $uuid.cfargotunnel.com"
          else
            cf_api POST "/zones/$zone_id/dns_records" "$dns_payload" > /dev/null
            echo "    → DNS created: $hostname CNAME $uuid.cfargotunnel.com"
          fi

          secret_name="cloudflared-$(echo "$hostname" | tr '.' '-')"
          host_secrets="$REPO/secrets/$host.yaml"

          if [[ ! -f "$host_secrets" ]]; then
            echo "placeholder: init" > "$host_secrets"
            (cd "$REPO" && sops --encrypt --in-place "$host_secrets")
          fi

          creds_json_string="$(printf '%s' "$creds_json" | jq -Rs .)"
          sudo env SOPS_AGE_KEY_FILE=/var/lib/sops-nix/key.txt \
            sops set "$host_secrets" "[\"$secret_name\"]" "$creds_json_string"

          current_lock="$(echo "$current_lock" | jq \
            --arg h "$hostname" \
            --arg u "$uuid" \
            --arg s "$secret_name" \
            '. + {($h): {uuid: $u, credentialsSecret: $s}}')"

          any_changed=true
        done

        mkdir -p "$(dirname "$lock_file")"
        echo "$current_lock" | jq -S . > "$lock_file"
      done

      # ────────────────────────────────────────────────────────────────
      # 2. Email routing rules
      # ────────────────────────────────────────────────────────────────
      echo "▸ email routing"

      # Read fleet-wide rules from any host's config (they're the same).
      email_rules_json="$(nix eval --json --impure --expr \
        "let cfg = (builtins.getFlake \"path:$REPO\").nixosConfigurations.pod042.config.cloudflare.email.rules or {}; in cfg")"

      for zone_name in $(echo "$email_rules_json" | jq -r 'keys[]'); do
        zone_id="$(zone_id_for "$zone_name")"
        if [[ -z "$zone_id" ]]; then
          echo "  ✗ zone $zone_name not found; skipping"
          continue
        fi

        # Fetch current rules
        current_rules="$(cf_api GET "/zones/$zone_id/email/routing/rules")"

        # Declared rules for this zone
        declared_rules="$(echo "$email_rules_json" | jq --arg z "$zone_name" '.[$z]')"

        for i in $(seq 0 $(($(echo "$declared_rules" | jq 'length') - 1))); do
          rule="$(echo "$declared_rules" | jq ".[$i]")"
          is_catch_all="$(echo "$rule" | jq -r '.catch_all // false')"
          forward_to="$(echo "$rule" | jq -r '.forward')"
          local_part="$(echo "$rule" | jq -r '.local_part // empty')"

          if [[ "$is_catch_all" == "true" ]]; then
            # Check if a catch-all rule to $forward_to already exists
            existing="$(echo "$current_rules" | jq --arg fwd "$forward_to" \
              '[.result[] | select(.matchers[0].type == "all" and .actions[0].value[0] == $fwd)] | .[0].id // ""' -r)"
            if [[ -n "$existing" ]]; then
              echo "  ✓ $zone_name: catch-all → $forward_to"
              continue
            fi
            echo "  + $zone_name: creating catch-all → $forward_to"
            payload="$(jq -n --arg fwd "$forward_to" \
              '{matchers:[{type:"all"}], actions:[{type:"forward", value:[$fwd]}], enabled:true, priority:2147483647}')"
            cf_api POST "/zones/$zone_id/email/routing/rules" "$payload" > /dev/null
            any_changed=true
          elif [[ -n "$local_part" ]]; then
            # Literal match: <local_part>@<zone> → forward_to
            match_val="$local_part@$zone_name"
            existing="$(echo "$current_rules" | jq --arg m "$match_val" --arg fwd "$forward_to" \
              '[.result[] | select(.matchers[0].type == "literal" and .matchers[0].value == $m and .actions[0].value[0] == $fwd)] | .[0].id // ""' -r)"
            if [[ -n "$existing" ]]; then
              echo "  ✓ $zone_name: $match_val → $forward_to"
              continue
            fi
            echo "  + $zone_name: creating $match_val → $forward_to"
            payload="$(jq -n --arg m "$match_val" --arg fwd "$forward_to" \
              '{matchers:[{type:"literal", field:"to", value:$m}], actions:[{type:"forward", value:[$fwd]}], enabled:true, priority:0}')"
            cf_api POST "/zones/$zone_id/email/routing/rules" "$payload" > /dev/null
            any_changed=true
          fi
        done

        # Warn about rules present in CF but not declared
        declared_forwards="$(echo "$declared_rules" | jq -r '[.[] | .forward] | unique | .[]')"
        for extra_rule_id in $(echo "$current_rules" | jq -r '.result[] | .id'); do
          extra_fwd="$(echo "$current_rules" | jq --arg id "$extra_rule_id" \
            '[.result[] | select(.id == $id)] | .[0].actions[0].value[0]' -r)"
          if ! echo "$declared_forwards" | grep -qx "$extra_fwd"; then
            :  # A rule with an unexpected forward target — could warn, but noisy
          fi
        done
      done

      # ────────────────────────────────────────────────────────────────
      # 3. R2 buckets
      # ────────────────────────────────────────────────────────────────
      echo "▸ R2 buckets"

      r2_buckets_json="$(nix eval --json --impure --expr \
        "let cfg = (builtins.getFlake \"path:$REPO\").nixosConfigurations.pod042.config.cloudflare.r2.buckets or {}; in cfg")"

      current_buckets="$(cf_api GET "/accounts/$ACCOUNT_ID/r2/buckets" | jq -r '.result.buckets[]?.name')"

      for bucket_name in $(echo "$r2_buckets_json" | jq -r 'keys[]'); do
        if echo "$current_buckets" | grep -qx "$bucket_name"; then
          echo "  ✓ $bucket_name"
          continue
        fi
        echo "  + creating R2 bucket $bucket_name"
        location="$(echo "$r2_buckets_json" | jq -r --arg b "$bucket_name" '.[$b].location')"
        payload="$(jq -n --arg name "$bucket_name" --arg loc "$location" \
          'if $loc == "auto" then {name:$name} else {name:$name, locationHint:$loc} end')"
        cf_api POST "/accounts/$ACCOUNT_ID/r2/buckets" "$payload" > /dev/null
        any_changed=true
      done

      # Warn about R2 buckets in CF but not declared (never auto-delete)
      for existing_bucket in $current_buckets; do
        if ! echo "$r2_buckets_json" | jq -e --arg b "$existing_bucket" 'has($b)' > /dev/null; then
          echo "  ⚠ R2 bucket '$existing_bucket' exists in CF but not declared — leaving alone (never auto-deleting R2 data)"
        fi
      done

      # ────────────────────────────────────────────────────────────────
      # R2 free-tier guardrail — total storage across all buckets vs 10GB
      # ────────────────────────────────────────────────────────────────
      # CF R2 free tier: 10GB storage. Overage: $0.015/GB/month.
      # Warn at 80% (8GB), hard-warn at 100% (10GB). Doesn't block anything —
      # just flags before a rebuild that a bill is imminent.
      total_bytes=0
      for bucket_name in $current_buckets; do
        # bucket usage endpoint returns payloadSize as a string number
        u="$(cf_api GET "/accounts/$ACCOUNT_ID/r2/buckets/$bucket_name/usage" \
             | jq -r '.result.payloadSize // "0"')"
        total_bytes=$((total_bytes + u))
      done
      total_gb=$(awk "BEGIN {printf \"%.2f\", $total_bytes / (1024*1024*1024)}")
      if [[ "$total_bytes" -gt 10737418240 ]]; then
        echo "  ✗ R2 usage $total_gb GB > 10 GB free tier — you WILL be charged (\$0.015/GB/mo overage)"
      elif [[ "$total_bytes" -gt 8589934592 ]]; then
        echo "  ⚠ R2 usage $total_gb GB > 8 GB — approaching 10 GB free-tier cap"
      else
        echo "  ✓ R2 usage $total_gb GB / 10 GB (free tier)"
      fi

      # ────────────────────────────────────────────────────────────────
      # Summary
      # ────────────────────────────────────────────────────────────────
      if [[ "$any_changed" == "true" ]]; then
        echo ""
        echo "▸ cf-reconcile made changes — commit updated secrets/*.yaml and"
        echo "  hosts/*/hardware-layout/cf-tunnels.lock.json files."
      fi
    '';
  };
in
{
  rebuild.preHooks.cf-tunnels = cfReconcile;
}
