{ ... }:

{
  # Networking Host Name
  networking.hostName = "pod042";

  # Enable Network Manager
  networking.networkmanager.enable = true;

  # Enable OpenSSH
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin        = "no";
    };
  };

  # Local Send
  programs.localsend.enable = true;

}
