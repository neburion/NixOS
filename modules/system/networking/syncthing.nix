{ ... }:

{
  services.syncthing = {
    enable          = true;
    user            = "neburion";
    dataDir         = "/home/neburion";
    configDir       = "/home/neburion/.config/syncthing";
    openDefaultPorts = true;
    settings.folders = {
      "Sync" = {
        path   = "/home/neburion/Sync";
        id     = "sync-main";
        devices = [];
      };
    };
  };
}
