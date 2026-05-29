# Hyprland session restore

Saves window state on shutdown/logout/reboot, re-launches the apps that were open on the next session start.

File: `home-modules/desktop/wm/hyprland/session.nix`.

## Class-to-command map

A hardcoded attrset maps Hyprland window class names to the command that launches them:

```nix
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
```

Compiled at build time into `${classMap}` (a JSON file in /nix/store) that the scripts read with `jq`.

## `hypr-session-save`

```sh
mkdir -p $HOME/.local/share/hypr-session
hyprctl clients -j > .../last.json
```

Dumps all currently-open hyprland clients as JSON.

## `hypr-session-restore`

1. Reads `last.json`
2. Pulls each unique window class via `jq -r '.[].class'`
3. Looks up the launch command for each class in `classMap`
4. Launches each with a 0.4 s `sleep` between

If a class isn't in the map, it's skipped silently.

## Triggers

| When | How |
|---|---|
| Session start (every login) | `exec-once = "hypr-session-restore"` in [[Home modules/Desktop/WM/Hyprland]]'s `auto-exec.nix` |
| Periodic save | `hypr-session-autosave` systemd user timer fires every 5 min (`OnActiveSec = "5m"`, `OnUnitActiveSec = "5m"`) |
| Power menu actions | `wofi-power-menu` ([[Home modules/Desktop/WM/Wofi]]) runs `hypr-session-save` before Shutdown / Reboot / Logout |

## Limitations

- No workspace memory — apps re-open on whatever workspace they default to
- No window position / size memory — Hyprland's tiling resorts them anyway
- Only known classes restore — unknown apps that were open are silently dropped on next login

To support a new app: add an entry to `classToCmd` in `session.nix`. Find the class with `hyprctl clients` while the app is running.
