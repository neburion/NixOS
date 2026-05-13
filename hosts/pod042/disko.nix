{
  disko.devices = {
    disk = {
      nvme0n1 = {
        type = "disk";
        device = "/dev/nvme0n1";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "fmask=0077" "dmask=0077" ];
              };
            };
            luks = {
              size = "700G";
              content = {
                type = "luks";
                name = "cryptroot";
                extraFormatArgs = [ "--type" "luks1" ];
                extraOpenArgs = [ "--allow-discards" ];
                content = {
                  type = "filesystem";
                  format = "ext4";
                  mountpoint = "/";
                };
              };
            };
            swap = {
              size = "16G";
              content = {
                type = "swap";
              };
            };
            # Remaining ~237GB left unallocated for AtlasOS
          };
        };
      };
    };
  };
}
