# Modules overview

System-level (NixOS) modules. Reusable across hosts.

```
modules/
├── audio/           pipewire
├── boot/            grub-efi
├── core/            nix · locale · security · shell
├── desktop/         wm/ · integrations/ · tools/ · quirks/ · fonts · gaming · remote-access
├── hardware/        bluetooth · graphics · nvidia · power-profiles · touchpad
├── host/            local.host.* typed options
└── network/         networkmanager · ssh · localsend
```

## Convention

Every subdir except `hardware/` and `host/` has a `default.nix` that imports all its files. That means:
- Importing `modules/network` enables NetworkManager + SSH + localsend together
- Importing `modules/network/ssh.nix` enables just SSH

`modules/hardware/` deliberately has NO `default.nix` — no host wants every hardware module. Hosts pick à la carte (see [[Hosts/pod042]] for an example).

`modules/host/` is options-only — it declares schemas in `local.host.*` for typed per-host data. Hosts SET those options in their `host.nix`.

## Quick reference

| Subdir | What it provides | Notes |
|---|---|---|
| [[Modules/Audio]] | PipeWire stack | rtkit + alsa + pulse + wireplumber |
| [[Modules/Boot]] | GRUB EFI bootloader | os-prober on, 10 generations |
| [[Modules/Core]] | Essentials any system wants | nix flakes, gc, locale, sudo no-pwd, fish |
| [[Modules/Desktop/Overview]] | Desktop stack | hyprland + sddm + apps + integrations |
| [[Modules/Hardware]] | Per-machine hardware drivers | opt-in per host |
| [[Modules/Host options]] | `local.host.*` typed options | currently `displays.{primary,monitors}` |
| [[Modules/Network]] | Network services | NM, SSH, localsend |
