{ config, lib, pkgs, ... }:

# Cloudflare Tunnel client (formerly Argo Tunnel). Runs `cloudflared` as a
# systemd service that makes outbound-only connections to Cloudflare's edge,
# exposing local services at public HTTPS URLs. No inbound ports required —
# bypasses NAT, CGNAT, and (importantly for this fleet) Bell HH3000 client
# isolation, since traffic egresses like any other outbound connection.
#
# Consumes per-host config from the env layer (`config.cloudflare.tunnels`,
# declared in hosts/<host>/hardware-layout/cloudflare-layout.nix). Importing
# this module installs the CLI unconditionally so `cloudflared tunnel login`
# etc. work for provisioning; the systemd service only starts when the env
# layer actually defines tunnels.

let
  hasTunnels = config.cloudflare.tunnels != { };
in
{
  environment.systemPackages = [ pkgs.cloudflared ];

  services.cloudflared = lib.mkIf hasTunnels {
    enable  = true;
    tunnels = lib.mapAttrs
      (_uuid: t: {
        credentialsFile = t.credentialsFile;
        ingress         = t.ingress;
        default         = t.default;
      })
      config.cloudflare.tunnels;
  };
}
