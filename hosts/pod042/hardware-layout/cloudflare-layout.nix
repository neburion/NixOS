{ lib, ... }:

# Cloudflare Tunnel per-host facts. Behavior module lives at
# modules/system/networking/cloudflare-tunnel.nix.
#
# Provisioning flow (one-time per host, done from that host's shell):
#   1. `cloudflared tunnel login`
#        Opens a browser, writes ~/.cloudflared/cert.pem — the account cert.
#   2. `cloudflared tunnel create <name>`
#        Creates a tunnel with a UUID, writes ~/.cloudflared/<uuid>.json.
#   3. `sudo install -Dm640 ~/.cloudflared/<uuid>.json /etc/cloudflared/<host>.json`
#        Move the credentials out-of-band (never commit to the repo).
#   4. `cloudflared tunnel route dns <name> <hostname.yourdomain.com>`
#        Points the DNS name at the tunnel via Cloudflare's zone API.
#   5. Populate config.cloudflare.tunnels below with the UUID + ingress map.

{
  options.cloudflare = {
    tunnels = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          credentialsFile = lib.mkOption { type = lib.types.str; };
          ingress = lib.mkOption {
            type    = lib.types.attrsOf lib.types.str;
            default = { };
          };
          default = lib.mkOption {
            type    = lib.types.str;
            default = "http_status:404";
          };
        };
      });
      default = { };
      description = "Cloudflare tunnels this host serves. Keyed by tunnel UUID.";
    };
  };

  # pod042 is the groundwork/test host — real deploy target is home-server.
  # To wire a test tunnel here, fill in (after doing steps 1–4 above):
  #
  # config.cloudflare.tunnels."00000000-0000-0000-0000-000000000000" = {
  #   credentialsFile = "/etc/cloudflared/pod042.json";
  #   ingress."pod042-test.yourdomain.com" = "http://localhost:8080";
  # };
  config.cloudflare.tunnels = { };
}
