# Desktop — Gaming

`modules/desktop/gaming.nix`.

## What it enables (system)
- Steam (with `remotePlay.openFirewall`, Proton GE Bin as extra compat package)
- `jdk25` system-wide for Minecraft v26 (Java requirement)

## The launcher gate (clever bit)

`programs.steam` installs `steam.desktop` system-wide, which would otherwise show up in every user's app launcher. The module gates that visibility per-user via a custom option:

```nix
home-manager.sharedModules = [
  ({ config, lib, ... }: {
    options.gamingLauncher.enable = lib.mkEnableOption
      "showing system-wide gaming launchers (Steam, …) in the application menu";

    config.xdg.desktopEntries.steam = lib.mkIf (!config.gamingLauncher.enable) {
      name = "Steam"; noDisplay = true; exec = "steam %U"; type = "Application";
    };
  })
];
```

Default: every user gets a shadowed (`noDisplay = true`) Steam entry. Users that want it visible set `gamingLauncher.enable = true` in their home-modules.

Currently only [[Users/qellyree]] enables it (via `home-modules/desktop/gaming/default.nix` which `qellyree` imports — see [[Home modules/Overview]] notes on gaming).

More detail in [[Concepts/Gaming launcher gating]].

## See also

- [[Users/qellyree]] — the gaming user
- [[Home modules/Desktop/WM/Hyprland]] — keybind `SUPER+G` → heroic, `SUPER+SHIFT+G` → steam
