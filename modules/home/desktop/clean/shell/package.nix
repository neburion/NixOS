{ pkgs, config, lib, ... }:

let
  qsFiles = lib.filterAttrs (n: _: lib.hasPrefix "quickshell/" n) config.xdg.configFile;
  # sd-switch restarts a service when its unit file changes. Fingerprinting the
  # QML store paths makes the unit change whenever any generated QML changes,
  # so a home-manager rebuild live-reloads the bar.
  qmlFingerprint = builtins.hashString "sha256"
    (lib.concatStringsSep "\n"
      (lib.mapAttrsToList (n: v: "${n}=${toString v.source}") qsFiles));
in
{
  home.packages = with pkgs; [
    quickshell
  ];

  home.activation.initQuickshellState = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    STATE_DIR="$HOME/.local/state/quickshell"
    mkdir -p "$STATE_DIR"
    if [ ! -f "$STATE_DIR/active-theme" ]; then
      echo "dark" > "$STATE_DIR/active-theme"
    fi
  '';

  systemd.user.services.quickshell = {
    Unit = {
      Description = "Quickshell";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      X-Restart-Triggers = [ qmlFingerprint ];
    };
    Service = {
      ExecStart = "${pkgs.quickshell}/bin/quickshell";
      Restart = "on-failure";
      RestartSec = 3;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
