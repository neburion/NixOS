{ config, pkgs, ... }:

let
  pythonEnv = pkgs.python3.withPackages (p: [ p.flask ]);

  printServer = pkgs.writeShellApplication {
    name = "print-server";
    # libreoffice-still: .docx/.odt/.doc/.rtf → PDF for printing.
    # sane-backends: scanimage for the Canon MF3010 scanner (pixma backend).
    # img2pdf: stitches per-page PNGs into a single multi-page PDF.
    runtimeInputs = [
      pythonEnv
      pkgs.cups
      pkgs.libreoffice-still
      pkgs.sane-backends
      pkgs.img2pdf
    ];
    text = "exec python3 ${./server.py}";
  };
in
{
  # SANE for the MF3010 scanner side of the MFP. hardware.sane.enable also
  # creates the "scanner" group and installs udev rules so the print-server
  # user can access the USB scanner device without root.
  hardware.sane.enable = true;

  users.users.print-server = {
    isSystemUser = true;
    group = "print-server";
    extraGroups = [ "lp" "scanner" ];
    # UID pinned so `RuntimeDirectory = "user/996"` below (which mirrors
    # /run/user/$UID for LibreOffice's soffice wrapper) always matches
    # this user's actual UID. GID is intentionally NOT pinned — RuntimeDirectory
    # cares about UID only, and pinning GID 996 collided with polkituser
    # (auto-created at 996 by the polkit module).
    uid = 996;
  };
  users.groups.print-server = { };

  # HTTP Basic Auth password for the print/scan UI. Sops-decrypted at
  # activation to /run/secrets/print-server-password, then wrapped in a
  # KEY=VALUE env file that the systemd unit loads via EnvironmentFile.
  # Rotation: `sops set secrets/home-server.yaml '["print-server-password"]'
  # '"newpass"'` + rebuild.
  #
  # `restartUnits` is what makes that rotation actually take effect.
  # LoadCredential snapshots the password at unit start and the app reads it
  # once, so rewriting /run/secrets changes nothing on its own: without this the
  # unit is never restarted and the retired password keeps working, while the
  # deploy prints "modifying secret" and "Done.".
  sops.secrets.print-server-password = {
    sopsFile = ../../../../secrets/home-server.yaml;
    mode     = "0400";
    owner    = "print-server";
    restartUnits = [ "print-server.service" ];
  };

  # LoadCredential= reads the sops-decrypted secret as root at unit startup
  # and hands it to the service at $CREDENTIALS_DIRECTORY/password after the
  # User/Group drop. Avoids the EnvironmentFile chicken-egg (systemd loads
  # env files BEFORE ExecStartPre runs) and keeps the secret out of the
  # process env table. server.py reads it from that path.
  systemd.services.print-server = {
    description = "Web print server for Canon MF3010";
    wantedBy = [ "multi-user.target" ];
    after = [ "cups.service" "network.target" ];
    requires = [ "cups.service" ];
    serviceConfig = {
      ExecStart = "${printServer}/bin/print-server";
      LoadCredential = "password:${config.sops.secrets.print-server-password.path}";
      Restart = "on-failure";
      RestartSec = "5s";
      User = "print-server";
      Group = "print-server";
      # Let the non-root user bind port 80.
      AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
      CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];
      # NixOS' soffice wrapper hardcodes `mkdir -p /run/user/$(id -u)/
      # libreoffice-dbus` before consulting XDG_RUNTIME_DIR. Without a
      # session, /run/user/996 doesn't exist and doc conversion fails.
      RuntimeDirectory = "user/996";
      RuntimeDirectoryMode = "0700";
    };
  };

  # Reachable only over the tailnet and through the Cloudflare tunnel.
  # cloudflared proxies to http://localhost:80 (loopback, no firewall rule
  # needed), so this interface-scoped rule is the only host-facing exposure —
  # the LAN can't reach the UI. The old printer.local mDNS alias + avahi
  # publishing were removed with this change; nothing on the LAN resolves or
  # reaches the printer anymore.
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 80 ];

  # The tunnel is declared here, not by the host, because it exists only
  # because this UI does — turn the web server off and a tunnel to port 80 is
  # pointing at nothing. paisa and the app platform already declared their own
  # this way; the host was the odd one out, and it was the only line in its
  # policy/cloudflare.nix.
  cloudflare.declaredTunnels."printer.azuresalt.app" = {
    service = "http://localhost:80";
  };
}
