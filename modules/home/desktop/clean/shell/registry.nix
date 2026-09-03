{ lib, ... }:

# Internal registry used by component modules to contribute QML files and
# top-level Scope instantiations. Not a user-facing knob — same latitude the
# environment layer gets. See ARCHITECTURE.md → "Behavior modules never expose
# user-facing options".

{
  options.quickshell = {
    services = lib.mkOption {
      type    = lib.types.attrsOf lib.types.lines;
      default = {};
      description = ''
        QML singleton files written to ~/.config/quickshell/main/Services/<name>.qml
        Each entry's value must be the full QML text (including `pragma Singleton`).
      '';
    };

    commons = lib.mkOption {
      type    = lib.types.attrsOf lib.types.lines;
      default = {};
      description = ''
        Shared QML files (theme palettes, constants, helper singletons) written to
        ~/.config/quickshell/main/Common/<name>.qml
      '';
    };

    modules = lib.mkOption {
      type    = lib.types.attrsOf lib.types.lines;
      default = {};
      description = ''
        Visible component QML files written to ~/.config/quickshell/main/Modules/<name>.qml
      '';
    };

    widgets = lib.mkOption {
      type    = lib.types.attrsOf lib.types.lines;
      default = {};
      description = ''
        Reusable QML controls written to ~/.config/quickshell/main/Widgets/<name>.qml
      '';
    };

    moduleInstantiations = lib.mkOption {
      type    = lib.types.listOf lib.types.lines;
      default = [];
      description = ''
        QML snippets placed inside the top-level ShellRoot in shell.qml.
        Each entry is typically one component invocation, e.g. "Bar {}".
      '';
    };

    shellExtraImports = lib.mkOption {
      type    = lib.types.listOf lib.types.str;
      default = [];
      description = ''
        Extra QML import statements added to shell.qml, e.g. "import QtQuick.Layouts".
        Standard imports (Quickshell, QtQuick, Common, Services, Modules, Widgets)
        are always included.
      '';
    };
  };
}
