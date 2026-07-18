{ pkgs, ... }:

# Player widget uses playerctl for MPRIS metadata + transport control.
# Toggle via /tmp/qs-toggle (Super+Return) — see shell.qml polling.

{
  home.packages = [ pkgs.playerctl ];
}
