{ ... }:

{
  # Serial console for headless boot (VM testing, IPMI, screen-over-SSH).
  # tty1 keeps working as the primary console.
  boot.kernelParams = [ "console=ttyS0,115200n8" "console=tty1" ];
  systemd.services."serial-getty@ttyS0".enable = true;
}
