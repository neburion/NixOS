# How to

Common tasks. Each section is self-contained — jump to what you need.

---

## Add a new app (system level)

For services / system-wide packages (Steam, OBS via OBS Studio's system flatpak, etc.).

1. Pick a subdir in `modules/desktop/`:
    - `integrations/` if it's a service users will interact with through other apps (kdeconnect-style)
    - `tools/` if it's a CLI utility
    - top-level (flat `<name>.nix`) if it's a self-contained capability (`gaming.nix`-style)
2. Create `<name>.nix`:
    ```nix
    { pkgs, ... }:
    {
      environment.systemPackages = with pkgs; [ <package> ];
      # … any services.X.enable / programs.X.enable
    }
    ```
3. If you put it in a subdir, add it to that subdir's `default.nix` imports.
4. `rebuild`

---

## Add a new app (user level)

For desktop apps, CLI tools — the usual case.

1. Pick where it belongs ([[Home modules/Desktop/Overview]] / [[Home modules/CLI/Overview]]).
2. Either:
    - Bundle into an existing capability file (`apps/comms.nix`, `apps/media.nix`, etc.) — for apps that share a clear capability
    - OR create a new capability file — for apps that don't fit
3. If the app needs a hyprland keybind:
    - Add a `$variable` in `home-modules/desktop/wm/hyprland/programs.nix`
    - Add the bind in `home-modules/desktop/wm/hyprland/keybinds.nix`
4. If it should show as default for a mime type, add it to `xdg.mimeApps.defaultApplications` in the same module:
    ```nix
    xdg.mimeApps.defaultApplications = {
      "image/png" = "org.gnome.Loupe.desktop";
    };
    ```
5. `rebuild`

---

## Add a new user

1. Create `users/<name>/`:
    - `modules.nix` — `users.users.<name>` with `extraGroups`, optional `shell`
    - `default.nix` — imports `modules.nix` + sets `home-manager.users.<name>.imports` (pick from [[Home modules/Overview]])
    - `dirs.nix` — XDG tmpfiles for any user-owned dirs
2. Add `../../users/<name>` to `hosts/<host>/users.nix`
3. `rebuild` will create the user account
4. `sudo passwd <name>` to set the initial password

For reference shapes: [[Users/neburion]] (full stack), [[Users/qellyree]] (gaming opt-in), [[Users/nululy]] (minimal).

---

## Add a new host

1. Create `hosts/<name>/`:
    - `configuration.nix` — imports-only:
      ```nix
      { ... }:
      {
        imports = [
          ./hardware-configuration.nix
          ./hardware.nix
          ./host.nix
          ./users.nix
          ../../modules/audio
          ../../modules/boot
          ../../modules/core
          ../../modules/desktop      # if this host has a desktop
          ../../modules/network
        ];
      }
      ```
    - `host.nix` — `networking.hostName = "<name>"` + `local.host.displays = …` ([[Modules/Host options]])
    - `hardware.nix` — imports `modules/hardware/*.nix` à la carte + any per-machine values (PRIME bus IDs, etc.)
    - `users.nix` — imports `users/<name>/` for every user on this host
    - `hardware-configuration.nix` — generate with `sudo nixos-generate-config --root /mnt --no-filesystems` (or similar)
2. Add to `flake.nix`'s `nixosConfigurations`:
    ```nix
    <hostname> = mkSystem { host = "<hostname>"; };
    ```
3. Build / install per [[Hosts/installer]]'s flow, with `<name>` instead of `pod042`.

---

## Add a new theme

1. Create `home-modules/themes/<name>.nix` matching the palette schema ([[Home modules/Themes]]):
    ```nix
    {
      bg             = "#…";
      surface        = "#…";
      selection      = "#…";
      fg             = "#…";
      wallpaperDir   = "MyTheme";          # ~/Media/Wallpapers/MyTheme
      gtkTheme       = "<gtk-theme-name>"; # must be installed in gtk module
      fishPrimary    = "#…";
      fishSecondary  = "#…";
      superfileTheme = "<spf-name>";       # one of superfile's built-ins
    }
    ```
2. Add to `home-modules/themes/default.nix`:
    ```nix
    <name> = import ./<name>.nix;
    ```
3. Create the wallpaper directory: `mkdir ~/Media/Wallpapers/<dir>` and drop some images in (or extend [[Users/neburion]]'s `dirs.nix`)
4. If the GTK theme isn't already installed, add the package to `home-modules/desktop/wm/gtk/default.nix`'s `home.packages`
5. `rebuild` then `SUPER+SHIFT+Space` to switch

The theme generators (each WM/CLI module's `mapAttrs'` over `themes`) automatically pick up the new entry — no other edits needed.

---

## Customize keybindings

All Hyprland binds: `home-modules/desktop/wm/hyprland/keybinds.nix`.

App-launching binds reference `$variables` declared in `programs.nix` — change the variable definition there if you want to swap which app a key launches. Edit the `bind = [ … ]` list for new binds.

Three bind types:
- `bind` — normal press
- `bindm` — mouse (movewindow / resizewindow)
- `bindel` — locked (e.g. volume keys that work even when input is locked)

After editing: `rebuild` rewrites the config, then `hyprctl reload` (or just log out / in).

---

## Switch theme

`SUPER+SHIFT+Space` — pops a wofi menu of every theme. Pick one. Full pipeline: [[Concepts/Theme switching]].

If a tool isn't updating: it might need to be restarted manually. The switcher restarts waybar, mako, ghostty (live), and Nautilus, but does not restart all apps that read GTK CSS on startup.

---

## Update flake inputs

```sh
update           # alias: nix flake update + rebuild
# or
sudo nix flake update              # update lock file
sudo nix flake update nixpkgs      # specific input
sudo nixos-rebuild switch …
```

---

## Rebuild

```sh
rebuild     # sudo nixos-rebuild switch --flake $HOME/NixOS#pod042
trebuild    # same but `test` — applies without making it a boot entry
```

See [[Build & rebuild]] for manual / debug invocations.

---

## Bootstrap a fresh machine

See [[Hosts/installer]].

```sh
nixflash /dev/sdX   # build + flash the installer ISO
# boot from USB, login (no password), run:
nixinstall
```
