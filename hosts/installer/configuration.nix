{ pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix")
  ];

  environment.systemPackages = with pkgs; [
    git
    rclone
    p7zip
    jq
    parted
    gptfdisk
    e2fsprogs
    (pkgs.writeShellScriptBin "nixinstall"
      (builtins.readFile ./nixinstall.sh))
    (pkgs.writeShellScriptBin "nixshrink"
      (builtins.readFile ./nixshrink.sh))
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Serial console for headless boot (VM testing, IPMI, screen-over-SSH).
  # tty1 keeps working as the primary console.
  boot.kernelParams = [ "console=ttyS0,115200n8" "console=tty1" ];
  systemd.services."serial-getty@ttyS0".enable = true;
}
