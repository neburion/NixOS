{ pkgs, ... }:

# Thunderbird mail client. Account configuration is intentionally
# interactive (via Account Settings in-app) rather than declarative —
# credentials (Posteo app password, TOTP) live in KeePassXC, not the
# flake.

{
  home.packages = [ pkgs.thunderbird ];
}
