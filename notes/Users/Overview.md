# Users overview

Two users on pod042. Each lives in `users/<name>/` with the same three-file shape:

```
users/<name>/
├── default.nix      imports modules.nix + lists home-manager modules
├── modules.nix      users.users.<name> (groups, shell, linger)
└── dirs.nix         systemd.tmpfiles for XDG directory tree
```

`hosts/pod042/users.nix` imports both directories.

## Who gets what

| User | wheel | shell | gaming | nvf | XDG tree |
|---|---|---|---|---|---|
| [[Users/neburion]] | ✓ | fish | ✓ | ✓ | full (Docs, Downloads, Media, Projects/{Dev,Art,Tower}, Wallpapers per theme) |
| [[Users/nululy]] | ✓ | — (no shell set, defaults to bash) | ✗ | ✗ | minimal |

Both are in `networkmanager` group ([[Modules/Network]]).

## Home-modules stacks

Read the `home-manager.users.<name>.imports` in each user's `default.nix` for the canonical list.

- **neburion**: base + desktop + desktop/gaming + cli + dirs + dev + nvf
- **nululy**: base + desktop + cli + dirs + dev (no nvf)

`desktop/gaming` opt-in (neburion only) → un-hides the system-wide Steam shortcut. See [[Modules/Desktop/Gaming]] and [[Concepts/Gaming launcher gating]].

## Lingering

[[Users/neburion]] has `systemd.tmpfiles` rule creating `/var/lib/systemd/linger/neburion` so user services keep running when neburion isn't logged in (relevant for any always-on services neburion runs). Nululy doesn't.
