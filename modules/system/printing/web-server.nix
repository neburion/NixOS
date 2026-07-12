{ pkgs, ... }:

let
  pythonEnv = pkgs.python3.withPackages (p: [ p.flask ]);

  printServer = pkgs.writeShellApplication {
    name = "print-server";
    runtimeInputs = [ pythonEnv pkgs.cups ];
    text = "exec python3 ${./server.py}";
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
    after = [ "cups.service" "network.target" ];
    requires = [ "cups.service" ];
    serviceConfig = {
      ExecStart = "${printServer}/bin/print-server";
      Restart = "on-failure";
      RestartSec = "5s";
      User = "print-server";
      Group = "print-server";
    };
  };

  networking.firewall.allowedTCPPorts = [ 8080 ];
}
