{ pkgs, lib, ... }:

let
  # Maps Hyprland window class names to their launch commands
  classToCmd = {
    "ghostty"                  = "ghostty";
    "zen"                      = "zen";
    "zen-alpha"                = "zen";
    "obsidian"                 = "obsidian";
    "org.keepassxc.KeePassXC"  = "keepassxc";
    "signal"                   = "signal";
    "org.gnome.Nautilus"       = "nautilus";
    "pavucontrol"              = "pavucontrol";
    "vesktop"                  = "vesktop";
  };

  classMap = pkgs.writeText "hypr-session-classes.json"
    (builtins.toJSON classToCmd);

  hypr-session-save = pkgs.writeShellScriptBin "hypr-session-save" ''
    SESSION_DIR="$HOME/.local/share/hypr-session"
    mkdir -p "$SESSION_DIR"
    hyprctl clients -j > "$SESSION_DIR/last.json"
  '';

  hypr-session-restore = pkgs.writeShellScriptBin "hypr-session-restore" ''
    SESSION_FILE="$HOME/.local/share/hypr-session/last.json"
    [[ ! -f "$SESSION_FILE" ]] && exit 0

    CLASS_MAP="${classMap}"

    ${pkgs.jq}/bin/jq -r '.[].class' "$SESSION_FILE" 2>/dev/null \
      | sort -u \
      | while IFS= read -r class; do
          cmd=$(${pkgs.jq}/bin/jq -r --arg c "$class" '.[$c] // empty' "$CLASS_MAP")
          [[ -n "$cmd" ]] && { $cmd & sleep 0.4; }
        done
  '';
in
{
  home.packages = [ hypr-session-save hypr-session-restore pkgs.jq ];

  # Auto-save session every 5 minutes while Hyprland is running
  systemd.user.services.hypr-session-autosave = {
    Unit.Description    = "Periodic Hyprland session save";
    Service.Type        = "oneshot";
    Service.ExecStart   = "${hypr-session-save}/bin/hypr-session-save";
  };

  systemd.user.timers.hypr-session-autosave = {
    Unit.Description          = "Save Hyprland session every 5 minutes";
    Timer.OnActiveSec         = "5m";
    Timer.OnUnitActiveSec     = "5m";
    Timer.Unit                = "hypr-session-autosave.service";
    Install.WantedBy          = [ "timers.target" ];
  };
}
