{ ... }:

{
  # The fleet dashboard's sync tiles come from this user's syncthing API, and
  # the key for it lives in their config.xml. Set here rather than on the host
  # for the same reason `user` is: delete this file and the question of whose
  # syncthing to report on stops existing.
  fleetStatus.syncUser = "neburion";

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
