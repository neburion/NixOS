# Disko disk layout for pod042 fresh installs.
# Used by nixinstall — NOT imported by the running system config.
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
        swap = {
          size    = "17G";
          content = { type = "swap"; };
        };
        root = {
          size    = "100%";
          content = { type = "filesystem"; format = "ext4"; mountpoint = "/"; };
        };
      };
    };
  };
}
