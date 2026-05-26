{ ... }:

{
  services.syncthing = {
    enable = true;
    user = "neburion";
    dataDir = "/home/neburion";
    overrideDevices = true;
    overrideFolders = true;

    settings = {
      devices = {
        "phone" = { id = "5PLKE3M-NSHU2A4-D3QBZQA-4X3GZFV-CEXR6FM-EGVJOUW-7K3QWCS-42GQXAH"; };
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
