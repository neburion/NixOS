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

}
