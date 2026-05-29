# Principles

The three rules every change is measured against, in priority order:

## 1. Modularity

Each module = one concern. Capabilities grouped into subdirs.

- One concern per file, even if 1–3 lines (a 1-line module is still a discrete opt-in/opt-out unit)
- **Never** merge unrelated concerns into a junk-drawer file
- A "file too small" critique is invalid on its own — it has to be paired with "and these belong together as one concern"
- Subdirs group related modules; each subdir's `default.nix` imports everything in the group
- Apps that share a capability (chat, productivity) can bundle in one capability-named file (`comms.nix`, `productivity.nix`) — that's grouping, not junk-drawering. Apps that don't share a capability stay separate (image viewer ≠ music player ≠ streaming)

## 2. Declarativity

- Prefer NixOS/home-manager options over `home.activation` shell scripts whenever an option exists
- Typed options (`lib.types.submodule`, `lib.types.attrsOf`, etc.) when host-level data needs structure — see [[Modules/Host options]]
- Existing imperative bits (theme symlinks, waypaper bootstrap, sddm wallpaper sync) are runtime-mutable by design — they're imperative because the data changes at runtime, not because of laziness. Don't propose collapsing them unless asked.

## 3. Portability

- `modules/` is host-agnostic; modules don't know what host imports them
- Host-specific values live in `hosts/<name>/`:
    - hostname → `hosts/<name>/host.nix`
    - typed host data (display resolution, monitors, …) → `local.host.*` options set in `host.nix`
    - PCI bus IDs and other hardware-specifics → `hosts/<name>/hardware.nix`
- A future host can pick any subset of modules. `modules/hardware/` is deliberately à la carte (no `default.nix`) so a desktop without NVIDIA doesn't accidentally pull in NVIDIA config.

## Close second: readability & simplicity

These matter, but only after the three above. So:
- Subdir names should make the category obvious (`wm/`, `integrations/`, `tools/`, `quirks/`)
- File names should match content (`hyprland.nix`, `flatpak.nix`)
- `default.nix` files stay short — pure imports, no logic
- Don't subdivide if there's truly only one concern in a category and no growth expected (e.g. `fonts.nix` is flat, not `fonts/fira-mono.nix`)

## What goes where (the test)

Before adding code, ask:

| Question | Answer | Goes in |
|---|---|---|
| Does every host want this exact value? | Yes | `modules/` |
| Different hosts will want different values? | Yes | `local.host.*` option in `modules/host/`, set in `hosts/<host>/host.nix` |
| Only this one host has this hardware? | Yes | `hosts/<host>/hardware.nix` |
| Only this user wants this app? | Yes | `home-modules/` (added per-user via `users/<user>/default.nix`) |
| Every user on every host wants it? | Yes | `home-modules/` imported by all users |
