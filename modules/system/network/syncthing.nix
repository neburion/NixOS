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
        id   = "723KVGX-JPRTWOT-KL43KCK-GGP3TLY-JBC4XBF-VDP5C2V-IGN5IWG-XGCOIQC";
        name = "gPhone";
      };
      devices.iPhone = {
        id   = "UEQQRPE-PZV4OAG-753CGEL-3Y3GCHX-YIBJOEX-AULCQFG-AAKE523-KBJAGAO";
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
