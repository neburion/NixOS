{ ... }:

{
  # Networking
  networking.hostName = "pod153";
  networking.networkmanager.enable = true;

  # OpenSSH
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = true;
      PermitRootLogin = "no";
    };
  };

  # Avahi (Connecting with user and host names with ssh)
  services.avahi = {
    enable = true;
    nssmdns4 = true;
  };
  environment.sessionVariables = {TERM = "xterm-256color";}; # Adds shell colors with ssh

  # Syncthing
  services.syncthing = {
    enable = true;
    user = "9s";
    dataDir = "/home/9s";
    overrideDevices = true;  # Removes devices not listed here
    overrideFolders = true;  # Removes folders not listed here
    settings = {
      devices = {
        "pod042" = { id = "IVUC2PY-JFITI56-W2QKPJA-GFTHVZN-IW2X5JW-PFAPJQJ-FRWS5D7-ZNWPJAN"; };
      };
      folders = {
        "Config" = {
          path = "/home/9s/NixOS";
          devices = [ "pod042" ];
        };
      };
    };
  };
}
