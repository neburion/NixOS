## Location
Config lives at `/home/neburion/NixOS/`

## Top-level Structure

```
NixOS/
├── flake.nix              # Entry point — inputs, mkSystem helper, host definitions
├── flake.lock             # Auto-generated lockfile
├── hosts/                 # Per-host module selection
│   └── pod042/
│       ├── configuration.nix      # Imports for this host
│       ├── hardware-configuration.nix
│       └── users.nix              # Which users exist on this host
├── users/                 # Per-user home-manager module selection
│   ├── neburion.nix
│   └── nululy.nix
├── modules/               # NixOS (system-level) modules
│   └── see [[Modules List]]
├── home-modules/          # Home-manager modules
│   └── see [[Home Module List]]
└── Notes/                 # This Obsidian vault
```

## How a new host is added
1. Create `hosts/<hostname>/` with `configuration.nix`, `hardware-configuration.nix`, `users.nix`
2. Add an entry to the `nixosConfigurations` attrset in `flake.nix` using `mkSystem`
3. Assign users via the `users` argument in `mkSystem`

## How modules are organized

**`modules/`** — system-level config (runs as root, affects all users)
- Things like drivers, networking, display manager, system packages, services

**`home-modules/`** — home-manager config (runs per user, scoped to `$HOME`)
- Things like dotfiles, user packages, shell config, desktop environment

A host's `configuration.nix` selects which `modules/` to import.
A user's file in `users/` selects which `home-modules/` to import.
