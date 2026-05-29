# Home modules overview

Per-user (home-manager) modules. Composed via `users/<name>/default.nix`'s `home-manager.users.<name>.imports` list.

```
home-modules/
├── base.nix           home.stateVersion (do not change)
├── cli/               fish · git · superfile · neovim · appimage · compression · flatpak
├── desktop/           apps/ · services/ · tools/ · art/ · wm/ · xdg.nix
├── dev/               scripts · ai · nvf
└── themes/            palette attrsets (catppuccin, dark, everforest, gruvbox, nord)
```

## How users compose them

```nix
# users/neburion/default.nix
home-manager.users.neburion.imports = [
  ../../home-modules/base.nix
  ../../home-modules/desktop
  ../../home-modules/cli
  ./dirs.nix
  ../../home-modules/dev
  ../../home-modules/dev/nvf.nix      # neburion uses nvf, others don't
];
```

Each user picks their stack. See [[Users/Overview]] for who gets what.

## `themes` is a `_module.args`

Wired in `flake.nix`:

```nix
home-manager.sharedModules = [
  nvf.homeManagerModules.default
  { _module.args.themes = themes; }
];
```

So every home-module that needs palette data just destructures `{ themes, ... }: ...` — no `import ../../../themes` path traversal. See [[Home modules/Themes]] for the palette schema and [[Concepts/Theme switching]] for how palettes propagate at runtime.

## `hostConfig` is a `extraSpecialArgs`

Wired in `flake.nix`:

```nix
home-manager.extraSpecialArgs = {
  inherit zen-browser;
  hostConfig = config.local.host;
};
```

Home-modules destructure `{ hostConfig, ... }: ...` to read per-host data (monitors, …). See [[Concepts/Host config (data flow)]].

## Quick reference

- [[Home modules/CLI/Overview]]
- [[Home modules/Desktop/Overview]]
- [[Home modules/Dev/Overview]]
- [[Home modules/Themes]]
