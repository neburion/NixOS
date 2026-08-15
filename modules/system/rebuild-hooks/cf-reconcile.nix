{ pkgs, ... }:

# cf-reconcile — reads declared tunnels from every host's nix config,
# ensures each exists in Cloudflare's control plane, writes any created
# credentials into secrets/<host>.yaml (sops-encrypted) and the plaintext
# UUID mapping into hosts/<host>/hardware-layout/cf-tunnels.lock.json.
#
# Registers as `rebuild.preHooks.cf-tunnels` so `rebuild` runs it
# automatically before every deploy. Adding a tunnel is:
#   1. Edit hosts/<host>/hardware-layout/cloudflare-layout.nix
#   2. `rebuild <host>` (or just `rebuild` if editing the local host)
#
# Requires:
#   - `cloudflare-api-token` present in secrets/common.yaml
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

      # Decrypt the CF API token (needs sudo to read /var/lib/sops-nix/key.txt).
      TOKEN="$(sudo env SOPS_AGE_KEY_FILE=/var/lib/sops-nix/key.txt \
        sops --decrypt --extract '["cloudflare-api-token"]' "$REPO/secrets/common.yaml")"

      cf_api() {
        local method="$1" path="$2" data="''${3:-}"
        if [[ -n "$data" ]]; then
          curl -sS -X "$method" \
            -H "Authorization: Bearer $TOKEN" \
            -H "Content-Type: application/json" \
            -d "$data" \
            "https://api.cloudflare.com/client/v4$path"
        else
          curl -sS -X "$method" \
            -H "Authorization: Bearer $TOKEN" \
            "https://api.cloudflare.com/client/v4$path"
        fi
      }

      # Discover fleet hosts from the flake.
      mapfile -t HOSTS < <(nix eval --json --impure --expr \
        "builtins.attrNames (builtins.getFlake \"path:$REPO\").nixosConfigurations" \
        | jq -r '.[]')

      any_changed=false

      for host in "''${HOSTS[@]}"; do
        [[ "$host" == "installer" ]] && continue

        # Read this host's declaredTunnels attrset as JSON.
        declared_json="$(nix eval --json --impure --expr \
          "let cfg = (builtins.getFlake \"path:$REPO\").nixosConfigurations.\"$host\".config.cloudflare.declaredTunnels or {}; in cfg")"

        lock_file="$REPO/hosts/$host/hardware-layout/cf-tunnels.lock.json"
        current_lock="$(cat "$lock_file" 2>/dev/null || echo '{}')"

        # Loop over declared tunnels for this host.
        for hostname in $(echo "$declared_json" | jq -r 'keys[]'); do
          # Check the lock file — do we already have a UUID for this hostname?
          existing_uuid="$(echo "$current_lock" | jq -r --arg h "$hostname" '.[$h].uuid // ""')"

          if [[ -n "$existing_uuid" ]]; then
            # Verify tunnel still exists on CF side.
            check="$(cf_api GET "/accounts/$ACCOUNT_ID/cfd_tunnel/$existing_uuid")"
            if [[ "$(echo "$check" | jq -r '.success')" == "true" && \
                  "$(echo "$check" | jq -r '.result.deleted_at // ""')" == "" ]]; then
              echo "  ✓ $hostname → $existing_uuid (exists)"
              continue
            fi
            echo "  ⚠ $hostname → $existing_uuid was deleted upstream; recreating"
          fi

          echo "  + creating tunnel for $hostname on $host"

          # Generate a random 32-byte tunnel secret (base64-encoded).
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

          # Build the credentials JSON that cloudflared expects.
          creds_json="$(jq -n \
            --arg AccountTag "$ACCOUNT_ID" \
            --arg TunnelSecret "$tunnel_secret_b64" \
            --arg TunnelID "$uuid" \
            '{AccountTag: $AccountTag, TunnelSecret: $TunnelSecret, TunnelID: $TunnelID}')"

          # Discover the zone for this hostname (e.g. "printer.azuresalt.app" → "azuresalt.app").
          zone_name="$(echo "$hostname" | awk -F. '{n=NF; print $(n-1)"."$n}')"
          zone_resp="$(cf_api GET "/zones?name=$zone_name")"
          zone_id="$(echo "$zone_resp" | jq -r '.result[0].id')"

          if [[ "$zone_id" == "null" || -z "$zone_id" ]]; then
            echo "  ✗ zone $zone_name not found in this Cloudflare account" >&2
            exit 1
          fi

          # Create or update the DNS record: <hostname> CNAME <uuid>.cfargotunnel.com
          dns_payload="$(jq -n \
            --arg name "$hostname" \
            --arg content "$uuid.cfargotunnel.com" \
            '{type: "CNAME", name: $name, content: $content, proxied: true, ttl: 1}')"

          # Check for an existing record first (idempotent).
          existing_dns="$(cf_api GET "/zones/$zone_id/dns_records?name=$hostname&type=CNAME")"
          existing_record_id="$(echo "$existing_dns" | jq -r '.result[0].id // ""')"

          if [[ -n "$existing_record_id" ]]; then
            cf_api PUT "/zones/$zone_id/dns_records/$existing_record_id" "$dns_payload" > /dev/null
            echo "    → DNS updated: $hostname CNAME $uuid.cfargotunnel.com"
          else
            cf_api POST "/zones/$zone_id/dns_records" "$dns_payload" > /dev/null
            echo "    → DNS created: $hostname CNAME $uuid.cfargotunnel.com"
          fi

          # Encrypt credentials into secrets/<host>.yaml.
          # Secret name: cloudflared-<sanitized-hostname>. Sanitize to attrname-safe chars.
          secret_name="cloudflared-$(echo "$hostname" | tr '.' '-')"
          host_secrets="$REPO/secrets/$host.yaml"

          if [[ ! -f "$host_secrets" ]]; then
            # Create empty encrypted file with a placeholder so sops has something to work with.
            # Must be inside the repo so .sops.yaml creation rules match.
            echo "placeholder: init" > "$host_secrets"
            (cd "$REPO" && sops --encrypt --in-place "$host_secrets")
          fi

          # `sops set` expects a JSON value; wrap the credentials JSON blob
          # as a JSON string literal via `jq -Rs .` (slurp so newlines are
          # preserved, produce a single JSON string).
          creds_json_string="$(printf '%s' "$creds_json" | jq -Rs .)"
          sudo env SOPS_AGE_KEY_FILE=/var/lib/sops-nix/key.txt \
            sops set "$host_secrets" "[\"$secret_name\"]" "$creds_json_string"

          # Update the lock file.
          current_lock="$(echo "$current_lock" | jq \
            --arg h "$hostname" \
            --arg u "$uuid" \
            --arg s "$secret_name" \
            '. + {($h): {uuid: $u, credentialsSecret: $s}}')"

          any_changed=true
        done

        # Persist the lock file if any tunnels were touched for this host.
        mkdir -p "$(dirname "$lock_file")"
        echo "$current_lock" | jq -S . > "$lock_file"
      done

      if [[ "$any_changed" == "true" ]]; then
        echo ""
        echo "▸ cf-reconcile made changes — remember to commit updated secrets/*.yaml"
        echo "  and hosts/*/hardware-layout/cf-tunnels.lock.json files."
      fi
    '';
  };
in
{
  rebuild.preHooks.cf-tunnels = cfReconcile;
}
