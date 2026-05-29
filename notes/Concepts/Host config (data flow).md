# Host config (data flow)

How `local.host.*` typed options reach both system modules and per-user (home-manager) modules.

## The two halves

NixOS modules can read `config.local.host.*` directly (it's a normal NixOS option). But home-manager modules are evaluated in a separate config space — they can NOT read NixOS `config` by default.

Bridge: `flake.nix` passes the resolved system value into home-manager via `extraSpecialArgs`.

## The wiring

```nix
# flake.nix (mkSystem)
({ config, ... }: {
  home-manager = {
    useGlobalPkgs       = true;
    useUserPackages     = true;
    backupFileExtension = "backup";
    extraSpecialArgs = {
      inherit zen-browser;
      hostConfig = config.local.host;
    };
    sharedModules = [
      nvf.homeManagerModules.default
      { _module.args.themes = themes; }
    ];
  };
})
```

The outer module takes `{ config, ... }` — that gives access to the host's evaluated config. `config.local.host` is the typed value set by `hosts/<host>/host.nix`.

## The path

1. **Schema** — `modules/host/displays.nix` declares `options.local.host.displays.{primary,monitors}`
2. **Aggregator** — `modules/host/default.nix` imports the schema
3. **Host setter** — `hosts/pod042/host.nix` imports `modules/host` and sets values:
    ```nix
    local.host.displays = {
      primary = { width = 1920; height = 1080; };
      monitors = { builtin = …; external = …; };
    };
    ```
4. **NixOS consumer** — `modules/desktop/wm/sddm.nix`:
    ```nix
    { pkgs, config, ... }:
    let primary = config.local.host.displays.primary;
    in ''
      ScreenWidth=${toString primary.width}
      ScreenHeight=${toString primary.height}
    ''
    ```
5. **Home-manager consumer** — `home-modules/desktop/wm/hyprland/monitors.nix`:
    ```nix
    { hostConfig, lib, ... }:
    let monitors = hostConfig.displays.monitors;
    in {
      wayland.windowManager.hyprland.settings.monitor =
        lib.mapAttrsToList (_: m: "${m.name}, ${m.mode}, ${m.position}, ${m.scale}") monitors;
    };
    ```

## Adding a new typed host option

1. Decide on a topic file (`modules/host/<topic>.nix`) and add `options.local.host.<topic>` with appropriate types
2. Import it from `modules/host/default.nix`
3. Set the value in `hosts/<host>/host.nix`
4. Consumers:
    - NixOS modules read `config.local.host.<topic>`
    - Home-modules destructure `hostConfig.<topic>` from their args
5. If the new option needs to reach home-manager, it's already wired — `hostConfig` is the whole `config.local.host` namespace.

## See also

- [[Modules/Host options]] — current schema reference
- [[Hosts/pod042]] — example setter
- [[Home modules/Desktop/WM/Hyprland]] — monitors consumer
- [[Modules/Desktop/WM]] — sddm consumer
