{ ... }:

{
  services.syncthing = {
    enable           = true;
    user             = "neburion";
    dataDir          = "/home/neburion";
    configDir        = "/home/neburion/.config/syncthing";
    openDefaultPorts = true;
    settings = {
      devices.gPhone = {
        id   = "5PLKE3M-NSHU2A4-D3QBZQA-4X3GZFV-CEXR6FM-EGVJOUW-7K3QWCS-42GQXAH";
        name = "gPhone";
      };
      folders."Sync" = {
        path    = "/home/neburion/Sync";
        id      = "sync-main";
        devices = [ "gPhone" ];
      };
    };
  };
}
