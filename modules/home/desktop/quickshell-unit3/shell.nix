{ ... }:

# Materializes every Unit-3 QML file under ~/.config/quickshell/.
# Layout mirrors upstream conventions with directory names capitalized to
# match Qt's module-import naming (Common/Widgets/Modules).

let
  qml = ./qml;
in
{
  xdg.configFile = {
    "quickshell/shell.qml".source          = qml + "/shell.qml";

    "quickshell/Common/qmldir".source      = qml + "/Common/qmldir";
    "quickshell/Common/Theme.qml".source   = qml + "/Common/Theme.qml";
    "quickshell/Common/Settings.qml".source = qml + "/Common/Settings.qml";

    "quickshell/Widgets/qmldir".source        = qml + "/Widgets/qmldir";
    "quickshell/Widgets/CornerDeco.qml".source  = qml + "/Widgets/CornerDeco.qml";
    "quickshell/Widgets/NierButton.qml".source  = qml + "/Widgets/NierButton.qml";
    "quickshell/Widgets/Scanlines.qml".source   = qml + "/Widgets/Scanlines.qml";
    "quickshell/Widgets/WipeCurtain.qml".source = qml + "/Widgets/WipeCurtain.qml";

    "quickshell/Modules/qmldir".source              = qml + "/Modules/qmldir";
    "quickshell/Modules/Menu.qml".source            = qml + "/Modules/Menu.qml";
    "quickshell/Modules/Player.qml".source          = qml + "/Modules/Player.qml";
    "quickshell/Modules/Notifications.qml".source   = qml + "/Modules/Notifications.qml";
    "quickshell/Modules/VolumeBar.qml".source       = qml + "/Modules/VolumeBar.qml";
    "quickshell/Modules/ControlCenter.qml".source   = qml + "/Modules/ControlCenter.qml";
    "quickshell/Modules/WallpaperPicker.qml".source = qml + "/Modules/WallpaperPicker.qml";

    # active-monitor.sh sits alongside shell.qml because Menu resolves it as
    # Qt.resolvedUrl("active-monitor.sh") from the shell root.
    "quickshell/active-monitor.sh" = {
      source     = ./scripts/active-monitor.sh;
      executable = true;
    };
  };
}
