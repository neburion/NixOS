{ ... }:

# Unit-3 quickshell stack (NieR:Automata aesthetic, port of samyns/Unit-3).
#
# Unit-3's design is monolithic — a single shell.qml hosts every widget with
# shared state. This differs from the composable per-widget registry used by
# modules/home/desktop/quickshell/. As a result the QML payload is installed
# as a batch in shell.nix rather than one file per widget module. The
# per-role side-modules (menu, player, ...) still own their Hyprland vars,
# script installs, and package deps so keybind auto-wiring works the same.

{
  imports = [
    ./core.nix
    ./shell.nix
    ./assets.nix
    ./menu.nix
    ./player.nix
    ./control-center.nix
    ./notifications.nix
    ./volume-bar.nix
    ./wallpaper-picker.nix
  ];
}
