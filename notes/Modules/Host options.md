# Host options (`local.host.*`)

`modules/host/` declares typed NixOS options under the `local.host.*` namespace for host-specific data that needs to reach BOTH system modules (NixOS) AND user modules (home-manager).

## Files

| File | Options declared |
|---|---|
| `displays.nix` | `local.host.displays.primary.{width,height}` + `local.host.displays.monitors` (`attrsOf submodule`) |
| `default.nix` | imports `./displays.nix` |

## Why options, not specialArgs

A typed option gives:
- Validation at evaluation time (wrong field name → clear error)
- Defaults
- Documentation strings
- Composition with other modules (multiple modules can contribute, NixOS merges them)

specialArgs would have worked but skips all of that.

## Schema: `displays`

```nix
local.host.displays = {
  primary = { width = <int>; height = <int>; };
  monitors = {
    <role> = {
      name     = "eDP-1";          # output identifier
      mode     = "1920x1080@120";  # resolution@refresh
      position = "0x0";            # placement relative to origin
      scale    = "1";              # optional, default "1"
    };
    # …
  };
};
```

Roles are convention-named (`builtin`, `external`, …). [[Home modules/Desktop/WM/Hyprland]]'s `monitors.nix` uses `monitors.builtin.name` and `monitors.external.name` for `$builtInMonitor` / `$externalMonitor` variables.

## How home-manager sees it

`flake.nix` passes `hostConfig = config.local.host` into `home-manager.extraSpecialArgs`. Home-manager modules destructure `{ hostConfig, ... }: { ... }` to read it.

Full flow in [[Concepts/Host config (data flow)]].

## Consumers

| Module | Reads | Uses for |
|---|---|---|
| `modules/desktop/wm/sddm.nix` | `config.local.host.displays.primary` | `ScreenWidth` / `ScreenHeight` in the SDDM theme config |
| `home-modules/desktop/wm/hyprland/monitors.nix` | `hostConfig.displays.monitors` | Generates `monitor =` list + `$builtInMonitor` / `$externalMonitor` variables |

## Adding a new option

1. Create `modules/host/<topic>.nix` with `options.local.host.<topic> = ...`
2. Add it to `modules/host/default.nix` imports
3. Set the value in `hosts/<host>/host.nix`
4. Read from `config.local.host.<topic>` (system modules) or `hostConfig.<topic>` (home-modules)
