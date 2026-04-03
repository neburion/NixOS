{ ... }:

{
  # Networking Host Name
  networking.hostName = "pod042";

  # Enable Network Manager
  networking.networkmanager.enable = true;

  # Enable OpenSSH
  services.openssh.enable = true;

  # Local Send
  programs.localsend = {
    enable = true;
    openFirewall = true;  # opens port 53317 TCP+UDP automatically
  };
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 53317 ];
    allowedUDPPorts = [ 53317 ];
  };

  # Syncthing
  services.syncthing = {
    enable = true;
    user = "neburion";
    dataDir = "/home/neburion";
    overrideDevices = true;  # removes devices not listed here
    overrideFolders = true;  # removes folders not listed here

    settings = {
      devices = {
        "pod153" = { id = "L6DR4TI-AB4NCIU-D4QXLPE-UP4OT6U-7VAHLU4-ODYQ44D-4J7SLPC-GDMKBAQ"; };
        "phone" = { id = "D7S7PTY-ZKFQBRV-5QQCRGV-O5M6SWS-TMAZLSO-HLOCN4X-QTHJ7LR-CXIIFQ5"; };
      };

      folders = {
        "Passwords" = {
          path = "/home/neburion/Docs/Passwords";
          devices = [ "phone" ];
        };

        "Reading" = {
          path = "/home/neburion/Media/Books/Reading-Ob";
          devices = [ "phone" ];
        };

        "School" = {
          path = "/home/neburion/School";
          devices = [ "phone" ];
        };

        "Config" = {
          id = "config";
          path = "/home/neburion/NixOS";
          devices = [ "pod153" ];
          type = "sendonly";
        };
      };
    };
  };

}
