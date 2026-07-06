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
      devices.iPhone = {
        id   = "UEQQRPE-PZV40AG-753CGEL-3Y3GCHX-YIBJ0EX-AULCQFG-AAKE523-KBJAGA0";
        name = "iPhone";
      };
      folders."Sync" = {
        path    = "/home/neburion/Sync";
        id      = "sync-main";
        devices = [ "gPhone" "iPhone" ];
      };
    };
  };
}
