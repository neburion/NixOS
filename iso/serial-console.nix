{ ... }:

{
  boot.kernelParams = [ "console=ttyS0,115200n8" "console=tty1" ];
  systemd.services."serial-getty@ttyS0".enable = true;
}
