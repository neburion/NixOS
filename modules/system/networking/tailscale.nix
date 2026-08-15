{ config, ... }:

# Fleet-wide Tailscale — every host joins your tailnet on boot, gets a
# stable MagicDNS name (`<hostname>.<tailnet>.ts.net`), and is reachable
# from any device anywhere. Handles NAT/CGNAT/Plume-Pod-isolation by
# tunnelling over WireGuard through the coordinator, so LAN-visibility
# problems (see project_bell_hh3000) simply don't apply on the tailnet.
#
# Auth key lives in secrets/common.yaml (fleet-wide, since every host
# uses the same one — it's a reusable preauthorized key). Sops decrypts
# to /run/secrets/tailscale-auth-key at activation, tailscaled reads it,
# host self-registers on first boot.
#
# We deliberately don't pass --ssh: Tailscale-managed SSH intercepts port
# 22 on the tailnet interface and requires an interactive browser-based
# auth per session (needs an ACL policy to auto-approve). Regular sshd
# still works fine over the tailnet interface with normal key auth, which
# is what `rebuild <host>` uses. If we later want Tailscale SSH's identity
# gating for humans, add --ssh + write an ACL policy in the admin console.
#
# --accept-dns   — respect MagicDNS resolution from the coordinator.

{
  sops.secrets.tailscale-auth-key = {
    sopsFile = ../../../secrets/common.yaml;
    mode     = "0400";
  };

  services.tailscale = {
    enable         = true;
    authKeyFile    = config.sops.secrets.tailscale-auth-key.path;
    extraUpFlags   = [ "--accept-dns" ];
    # Persist state across reboots. Default location works.
    openFirewall   = true;
  };
}
