{ config, lib, ... }:

# Materializes the whole quickshell config directory from the registry declared
# in registry.nix. Component modules contribute QML text via config.quickshell.*
# and this module writes the files.

let
  cfg = config.quickshell;

  mkFile = subdir: name: text:
    lib.nameValuePair "quickshell/${subdir}/${name}.qml" { inherit text; };

  serviceFiles = lib.mapAttrs' (mkFile "Services") cfg.services;
  commonFiles  = lib.mapAttrs' (mkFile "Common")   cfg.commons;
  moduleFiles  = lib.mapAttrs' (mkFile "Modules")  cfg.modules;
  widgetFiles  = lib.mapAttrs' (mkFile "Widgets")  cfg.widgets;

  # Only import subdirs that actually exist. QML errors hard on a missing
  # import path, so an empty Modules/ during Phase 0 would crash startup.
  importLine = subdir: cond: lib.optionalString cond ''import "${subdir}"'';

  autoImports = lib.concatStringsSep "\n" (lib.filter (s: s != "") [
    (importLine "Common"   (cfg.commons  != {}))
    (importLine "Services" (cfg.services != {}))
    (importLine "Modules"  (cfg.modules  != {}))
    (importLine "Widgets"  (cfg.widgets  != {}))
  ]);

  extraImports = lib.concatStringsSep "\n" cfg.shellExtraImports;

  instantiations = lib.concatStringsSep "\n    " cfg.moduleInstantiations;

  shellQml = ''
    //@ pragma UseQApplication
    import Quickshell
    import QtQuick
    ${autoImports}
    ${extraImports}

    ShellRoot {
        ${instantiations}
    }
  '';
in
{
  xdg.configFile = serviceFiles // commonFiles // moduleFiles // widgetFiles // {
    "quickshell/shell.qml".text = shellQml;
  };
}
