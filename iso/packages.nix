{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    e2fsprogs
    git
    gptfdisk
    jq
    openssl
    p7zip
    parted
    rclone
  ];
}
