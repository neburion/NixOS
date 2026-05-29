# qellyree

Gaming user. No sudo, no dev tooling.

## `modules.nix`
- `extraGroups = [ "networkmanager" ]` — NM only, **not** wheel

## `default.nix` imports

```
home-modules/base.nix
home-modules/desktop
home-modules/desktop/gaming      ← gaming opt-in
home-modules/cli
./dirs.nix
```

No `home-modules/dev`, no nvf.

## What `desktop/gaming` does

```nix
gamingLauncher.enable = true;
home.packages = [ heroic prismlauncher ];
```

Two effects:
1. Sets `gamingLauncher.enable = true` — un-hides the system-wide Steam shortcut (default is `noDisplay = true`). See [[Modules/Desktop/Gaming]] for how the gate works.
2. Installs Heroic Launcher (GOG/Epic) and Prism (Minecraft).

Steam itself is system-installed by `modules/desktop/gaming.nix`; this just makes it visible in qellyree's app menu.

## Keybinds

[[Home modules/Desktop/WM/Hyprland]]'s `SUPER+G` opens Heroic, `SUPER+SHIFT+G` opens Steam.

## See also

- [[Modules/Desktop/Gaming]]
- [[Concepts/Gaming launcher gating]]
