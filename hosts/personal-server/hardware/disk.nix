{ disk ? "/dev/sda", ... }:

# Small-disk layout for old laptops. Boots UEFI + systemd-boot.
#
# Consumed by modules/tools/installer/nixinstall.sh, which runs disko against this file
# directly (`--arg disk "/dev/sdX"`) — that's why it isn't imported by
# hardware/default.nix. Post-install the machine's filesystems come
# from the generated generated/hardware.nix instead.
#
# 8G swap rather than home-server's 4G: this box runs my own services and
# occasionally builds its own closures, and an old laptop's RAM is the first
# thing to run out. Swap on spinning rust is slow, but slow beats OOM-killed.

{
  disko.devices.disk.main = {
    type   = "disk";
    device = disk;
    content = {
      type = "gpt";
      partitions = {
        boot = {
          size = "512M";
          type = "EF00";
          content = {
            type         = "filesystem";
            format       = "vfat";
            mountpoint   = "/boot";
            mountOptions = [ "fmask=0077" "dmask=0077" ];
          };
        };
        swap = {
          size    = "8G";
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
