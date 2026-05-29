# Hosts overview

The flake currently builds two configurations:

| Host | Purpose | Notes |
|---|---|---|
| `pod042` | Daily-driver laptop | [[Hosts/pod042]] |
| `installer` | Live USB ISO | [[Hosts/installer]] |

Both are built by `mkSystem` in `flake.nix` (except the installer, which uses a smaller inline definition since it doesn't need disko/home-manager).

## What a host directory contains

```
hosts/<name>/
├── configuration.nix          imports only (no settings)
├── host.nix                   networking.hostName + local.host.* options
├── hardware.nix               imports modules/hardware/*.nix + per-machine values
├── hardware-configuration.nix auto-generated
└── users.nix                  imports users/<name>/ for everyone on this host
```

`configuration.nix` is deliberately stripped down to imports. All actual settings live in:
- a `modules/...` import (portable)
- a `local.host.*` option set in `host.nix` (typed, host-specific)
- a `hosts/<host>/hardware.nix` setting (host-specific hardware values)

## Adding a new host

Walkthrough lives in [[How to#Add a new host]].
