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
    #openFirewall = true;  # opens port 53317 TCP+UDP automatically
  };
  #networking.firewall = {
    #enable = true;
    #allowedTCPPorts = [ 53317 ];
    #allowedUDPPorts = [ 53317 ];
  #};

  # Syncthing
  services.syncthing = {
    enable = true;
    user = "neburion";
    dataDir = "/home/neburion";
    overrideDevices = true;  # removes devices not listed here
    overrideFolders = true;  # removes folders not listed here

    settings = {
      devices = {
        "phone"  = { id = "5PLKE3M-NSHU2A4-D3QBZQA-4X3GZFV-CEXR6FM-EGVJOUW-7K3QWCS-42GQXAH"; };
      };
      folders = {
        "Passwords" = {
          path = "/home/neburion/Docs/Passwords";
          devices = [ "phone" ];
        };
      };
    };
  };
}
