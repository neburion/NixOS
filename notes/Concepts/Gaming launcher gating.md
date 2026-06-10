# Gaming launcher gating

System-wide Steam install would put `steam.desktop` in EVERY user's app launcher. Only neburion wants it. The gating mechanism is in `modules/desktop/gaming.nix`.

## The custom option

```nix
home-manager.sharedModules = [
  ({ config, lib, ... }: {
    options.gamingLauncher.enable = lib.mkEnableOption
      "showing system-wide gaming launchers (Steam, …) in the application menu";

    config.xdg.desktopEntries.steam = lib.mkIf (!config.gamingLauncher.enable) {
      name = "Steam";
      noDisplay = true;
      exec = "steam %U";
      type = "Application";
    };
  })
];
```

`home-manager.sharedModules` makes the option appear in every user's home-manager config. Default: `enable = false` → per-user `xdg.desktopEntries.steam` writes a `Hidden=true` desktop entry that shadows the system one. With `enable = true` the override doesn't apply and the system entry shows normally.

## Opting in

[[Users/neburion]] imports `home-modules/desktop/gaming/default.nix` which sets:

```nix
gamingLauncher.enable = true;
```

That's the entire opt-in. The other users don't import gaming, so their `enable` stays false and Steam stays hidden in their app menu.

## Why not just install steam per-user

`programs.steam.enable = true` HAS to be system-level (it wires up `hardware.steam-hardware.enable`, opens firewall ports, etc.). It can't live in home-manager. So the package gets installed once at system level for everyone; the visibility gate is the per-user toggle.

## See also

- [[Modules/Desktop/Gaming]]
- [[Users/neburion]]
