{ config, pkgs, ... }:

# /var/backup, served read-only over the tailnet so a machine being
# reinstalled can pull its own snapshot before it has keys for anything.

{
  systemd.tmpfiles.rules = [
    "d /var/backup     0755 root         root -"
    "d /var/backup/1B  0755 server-admin root -"
    "d /var/backup/1O  0755 server-admin root -"
  ];

  # No nixpkgs option for serve, and the CLI keeps its config in tailscaled's
  # state, so reassert it on every boot to make this file the source of truth.
  systemd.services.tailscale-serve-backup = {
    description = "Serve /var/backup on the tailnet";
    after       = [ "tailscaled.service" ];
    wants       = [ "tailscaled.service" ];
    wantedBy    = [ "multi-user.target" ];

    serviceConfig = {
      Type             = "oneshot";
      RemainAfterExit  = true;
      ExecStart = pkgs.writeShellScript "tailscale-serve-backup" ''
        ${config.services.tailscale.package}/bin/tailscale serve reset
        ${config.services.tailscale.package}/bin/tailscale serve \
            --bg --yes --http=80 --set-path=/backup /var/backup
      '';
    };
  };
}
