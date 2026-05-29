# Desktop — Remote access

`modules/desktop/remote-access.nix`.

```nix
environment.systemPackages = [ pkgs.rustdesk-flutter ];
```

Just installs the RustDesk Flutter client. Server-side / always-on config is not enabled here.
