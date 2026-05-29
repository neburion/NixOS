# Network

`modules/network/` — three independently-importable services. `default.nix` imports all.

| File | What it enables |
|---|---|
| `networkmanager.nix` | `networking.networkmanager.enable = true` |
| `ssh.nix` | OpenSSH key-only (`PasswordAuthentication = false`), no root login |
| `localsend.nix` | `programs.localsend.enable = true` — opens firewall, runs the daemon |

Hostname does NOT live here — it's in [[Hosts/pod042]]'s `host.nix` (`networking.hostName = "pod042"`). That keeps the network module portable.

## Per-user prerequisite

NetworkManager requires users be in the `networkmanager` group:

```nix
# users/<name>/modules.nix
users.users.<name>.extraGroups = [ "wheel" "networkmanager" ];
```

See [[Users/Overview]] for the standard groups.

## See also

- [[Home modules/Desktop/Services]] installs `networkmanagerapplet` for the tray
- [[Home modules/Desktop/WM/Hyprland]] auto-exec's `nm-applet` on session start
