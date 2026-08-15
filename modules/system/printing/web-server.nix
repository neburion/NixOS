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

  # Publish "printer.local" via mDNS pointing at this host's LAN IP.
  # We resolve the IP at start time so it works over Wi-Fi / DHCP moves.
  publishAlias = pkgs.writeShellApplication {
    name = "publish-printer-alias";
    runtimeInputs = with pkgs; [ avahi iproute2 gawk coreutils ];
    text = ''
      ip=$(ip -4 -o addr show scope global | awk '{print $4}' | cut -d/ -f1 | head -n1)
      if [[ -z "$ip" ]]; then
        echo "No global IPv4 address found; retrying via service restart."
        exit 1
      fi
      exec avahi-publish -a -R printer.local "$ip"
    '';
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
  sops.secrets.print-server-password = {
    sopsFile = ../../../secrets/home-server.yaml;
    mode     = "0400";
    owner    = "print-server";
  };

  # LoadCredential= reads the sops-decrypted secret as root at unit startup
  # and hands it to the service at $CREDENTIALS_DIRECTORY/password after the
  # User/Group drop. Avoids the EnvironmentFile chicken-egg (systemd loads
  # env files BEFORE ExecStartPre runs) and keeps the secret out of the
  # process env table. server.py reads it from that path.
  systemd.services.print-server = {
    description = "Web print server for Canon MF3010";
    wantedBy = [ "multi-user.target" ];
    after = [ "cups.service" "network.target" "avahi-daemon.service" ];
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

  # Advertise "printer.local" over mDNS so family devices can visit
  # http://printer.local without knowing the IP or a port.
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
    publish = {
      enable = true;
      addresses = true;
      workstation = true;
      # Allow the printer-mdns-alias service to publish printer.local.
      userServices = true;
    };
  };

  systemd.services.printer-mdns-alias = {
    description = "mDNS alias printer.local → this host";
    wantedBy = [ "multi-user.target" ];
    after = [ "avahi-daemon.service" "network-online.target" ];
    wants = [ "network-online.target" ];
    requires = [ "avahi-daemon.service" ];
    serviceConfig = {
      ExecStart = "${publishAlias}/bin/publish-printer-alias";
      Restart = "on-failure";
      RestartSec = "10s";
      User = "avahi";
      Group = "avahi";
    };
  };

  networking.firewall.allowedTCPPorts = [ 80 ];
}
