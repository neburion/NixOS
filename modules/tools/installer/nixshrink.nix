{ pkgs, ... }:

# `nixshrink` — in-place shrink of an installed NixOS root to free space for
# a Windows dual-boot partition. Live-USB only; refuses to run if the target
# partitions are mounted.
#
# runtimeInputs carries every binary the script calls:
#   e2fsprogs  — e2fsck, resize2fs
#   gptfdisk   — sgdisk (partition table surgery)
#   parted     — layout printing + partprobe
#   util-linux — mount, blkid, mkswap
#   gawk/gnused/gnugrep — parsing sgdisk output
#   coreutils  — sleep, echo and friends

{
  environment.systemPackages = [
    (pkgs.writeShellApplication {
      name = "nixshrink";
      runtimeInputs = with pkgs; [
        coreutils
        e2fsprogs
        gawk
        gnugrep
        gnused
        gptfdisk
        parted
        util-linux
      ];
      text = builtins.readFile ./nixshrink.sh;
    })
  ];
}
