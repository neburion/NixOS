{ disk ? "/dev/nvme0n1", ... }:

{
  disko.devices.disk.main = {
    type   = "disk";
    device = disk;
    content = {
      type = "gpt";
      partitions = {
        boot = {
          size = "1G";
          type = "EF00";
          content = {
            type         = "filesystem";
            format       = "vfat";
            mountpoint   = "/boot";
            mountOptions = [ "fmask=0077" "dmask=0077" ];
          };
        };
        root = {
          size    = "700G";
          content = { type = "filesystem"; format = "ext4"; mountpoint = "/"; };
        };
        swap = {
          size    = "20G";
          content = { type = "swap"; };
        };
      };
    };
  };
}
