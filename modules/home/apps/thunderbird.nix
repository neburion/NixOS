{ config, pkgs, ... }:

# Thunderbird mail client. Account configuration is intentionally
# interactive (via Account Settings in-app) rather than declarative —
# credentials (Posteo app password, TOTP) live in KeePassXC, not the
# flake.
#
# `~/thunderbird` symlink: Thunderbird 128+ has a bug where it creates
# an empty `~/thunderbird` directory (no dot) on every startup, alongside
# the real profile at `~/.thunderbird`. Mozilla ticket exists, no fix
# upstream. Workaround: pre-create the path as a symlink to the real
# profile so TB's "mkdir if missing" logic no-ops instead of littering.

{
  home.packages = [ pkgs.thunderbird ];

  home.file."thunderbird".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.thunderbird";
}
