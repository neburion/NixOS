# AppImage, Compression, Flatpak

Three small one-purpose files in `home-modules/cli/`.

## `appimage.nix`
Installs `appimage-run`. Lets `*.AppImage` files execute on NixOS.

## `compression.nix`
Installs `p7zip`, `unrar`, `unzip`. Capability bundle — these compose into "extract things" together, like a CLI multi-tool, so they live in one file rather than three.

## `flatpak.nix`
```nix
home.activation.flatpakSetup =
  config.lib.dag.entryAfter [ "writeBoundary" ] ''
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || true
  '';
```
Adds the flathub remote per-user on activation. The system-level `services.flatpak.enable` is in [[Modules/Desktop/Integrations]].

The `|| true` swallows errors when `flatpak` itself isn't on PATH yet during initial activation.
