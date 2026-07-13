{ pkgs, ... }:

let
  pythonEnv = pkgs.python3.withPackages (p: [ p.flask ]);

  printServer = pkgs.writeShellApplication {
    name = "print-server";
    # libreoffice-still for .docx/.odt/.doc/.rtf → PDF conversion.
    runtimeInputs = [ pythonEnv pkgs.cups pkgs.libreoffice-still ];
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
  users.users.print-server = {
    isSystemUser = true;
    group = "print-server";
    extraGroups = [ "lp" ];
  };
  users.groups.print-server = { };

  systemd.services.print-server = {
    description = "Web print server for Canon MF3010";
    wantedBy = [ "multi-user.target" ];
    after = [ "cups.service" "network.target" "avahi-daemon.service" ];
    requires = [ "cups.service" ];
    serviceConfig = {
      ExecStart = "${printServer}/bin/print-server";
      Restart = "on-failure";
      RestartSec = "5s";
      User = "print-server";
      Group = "print-server";
      # Let the non-root user bind port 80.
      AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
      CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];
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
