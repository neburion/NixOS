{ config, lib, pkgs, ... }:

# Cloudflare Tunnel — outbound-only WireGuard-style tunnel to Cloudflare's
# edge that exposes local services at public HTTPS URLs. No inbound ports
# needed, so bypasses NAT / CGNAT / Bell HH3000 Plume Pod isolation.
#
# Declarative schema: each host declares hostname → local service:
#
#   config.cloudflare.declaredTunnels."printer.azuresalt.app" = {
#     service = "http://localhost:80";
#   };
#
# The `cf-reconcile` script (see modules/system/rebuild-hooks/cf-reconcile.nix)
# runs before every rebuild, calls the Cloudflare API to create any missing
# tunnels + DNS records, writes credentials into secrets/<host>.yaml (encrypted),
# and updates the plaintext lock file at hosts/<host>/hardware-layout/cf-tunnels.lock.json
# with the hostname → UUID mapping. This module then reads the lock file and
# generates the concrete `services.cloudflared.tunnels.<uuid>` entries.
#
# Two files, distinct concerns:
#   secrets/<host>.yaml            — sops-encrypted; per-tunnel credentials JSON
#   hosts/<host>/hardware-layout/  — committed plaintext; hostname → UUID mapping
#     cf-tunnels.lock.json           (UUIDs are not sensitive on their own)

let
  hostName = config.networking.hostName;
  lockFile = ../../../hosts + "/${hostName}/hardware-layout/cf-tunnels.lock.json";
  mapping  = if builtins.pathExists lockFile
             then builtins.fromJSON (builtins.readFile lockFile)
             else { };
  declared = config.cloudflare.declaredTunnels;

  # Each key of `mapping` is a hostname; value is { uuid, credentialsSecret }
  # where credentialsSecret is the sops key name (e.g. "cloudflared-printer").
  tunnelEntries = lib.mapAttrs' (hostname: entry:
    lib.nameValuePair entry.uuid {
      credentialsFile = config.sops.secrets.${entry.credentialsSecret}.path;
      ingress = { "${hostname}" = declared.${hostname}.service; };
      default = "http_status:404";
    }
  ) (lib.filterAttrs (h: _: declared ? "${h}") mapping);

  # The upstream services.cloudflared systemd unit uses `DynamicUser=true`
  # and reads the credentials file via `LoadCredential=`, which runs as root
  # BEFORE the dynamic user is applied. So the secret must be root:root
  # 0400 — a `cloudflared` user doesn't exist to chown to.
  sopsSecretsForTunnels = lib.mapAttrs' (_hostname: entry:
    lib.nameValuePair entry.credentialsSecret {
      mode = "0400";
    }
  ) (lib.filterAttrs (h: _: declared ? "${h}") mapping);
in
{
  options.cloudflare.declaredTunnels = lib.mkOption {
    type    = lib.types.attrsOf (lib.types.submodule {
      options.service = lib.mkOption {
        type = lib.types.str;
        description = "Local service URL to route this hostname to (e.g. http://localhost:80).";
      };
    });
    default = { };
    description = ''
      Cloudflare tunnels this host should expose. Keyed by public hostname
      (e.g. "printer.azuresalt.app"). `cf-reconcile` runs before nixos-rebuild
      to converge Cloudflare's control plane with what's declared here.
    '';
  };

  config = {
    environment.systemPackages = [ pkgs.cloudflared ];

    services.cloudflared = lib.mkIf (tunnelEntries != { }) {
      enable  = true;
      tunnels = tunnelEntries;
    };

    sops.secrets = sopsSecretsForTunnels;
  };
}
