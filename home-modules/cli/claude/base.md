# Technical Base (shared across personas)

## Core Rules

- **When in doubt, check online.** This user will not catch mistakes. If an option name, package, or behavior is uncertain — WebSearch before touching it. NixOS options change between versions. Verify first, always.
- Never ask permission for pre-approved actions (git, sudo, rebuild, file edits, etc...).
- Never give manual instructions — automate everything.
- Never explain anything.
- Keep code clean, correct, and simple. No hacks, no shortcuts, no half-measures.

## The User

- Checks **nothing**. No diffs, no verification, no safety net. Ever.
- Cannot be trusted with manual instructions — automate everything.
- Hands over root access and looks away. Repay it by being correct.
- Gives no feedback unless it breaks. Be right the first time.

## Config Philosophy — Highest Priority

**Modularity and declarativeness are non-negotiable.** Every system behavior must be expressed in `~/NixOS`. No manual steps, no mutable runtime state that can't survive a rebuild, no imperative setup instructions. If it's not in the flake, it doesn't exist.

- One concern per file. No god-files.
- Runtime-owned state (active theme symlinks, waypaper config, active CLAUDE.md persona) is the explicit exception — document it as such.
- If something requires a manual step after rebuild, that step must become a script or activation hook in nix.

---

## Hardware (pod042)

- **CPU**: Intel (KVM support)
- **GPU**: NVIDIA (Turing+, `open = true`) + Intel iGPU (PRIME offload)
- **Monitors**: eDP-1 (1920x1080@120Hz, built-in, workspaces 1-5) + HDMI-A-1 (1920x1080@144Hz, external, workspaces 6-10)
- **Boot**: UEFI, GRUB, ext4 root, vfat /boot, swap partition
- **Audio**: PipeWire + ALSA + PulseAudio compat + WirePlumber + rtkit

---

## NixOS Config

- **Repo**: `~/NixOS` — flake-based, NixOS 25.11, home-manager as NixOS module
- **Rebuild**: `sudo nixos-rebuild switch --flake $HOME/NixOS#pod042`
- **Sudo**: passwordless for neburion (`wheelNeedsPassword = false`)
- **Inputs**: nixpkgs (25.11), home-manager (25.11), zen-browser, nvf (neovim framework), disko
- **Active config lives entirely in `~/NixOS/`** — `/etc/nixos` has only the original generated stubs
- `backupFileExtension = "backup"` set globally
- Always `WebSearch` before using NixOS/HM options — they change between versions
- Use `pkgs.foo` explicitly in `systemPackages`, never rely on `with pkgs;` shadowing

---

## Users & TTY Layout

| User | TTY | Role |
|------|-----|------|
| neburion | TTY1 | Dev/work — full desktop, dev tools, ai, zen-browser, nvf |
| qellyree | TTY2 | Gaming — heroic, steam, prismlauncher, vesktop, spotify, obs |
| nululy | TTY3 | Secondary — active dev work, Minecraft, Discord |

**nululy in practice** (surveyed 2026-05-26):
- Has an active Python project: `~/Programs/censor-engine` — NSFW image/video censorship engine using nudenet, opencv, ffmpeg, onnxruntime-gpu. Real software, actively developed.
- Minecraft via Tecknix launcher (cracked, stored in `~/.minecraft`, 6GB RAM allocated)
- Zen browser (own profile, separate from neburion's)
- Native Discord + vesktop remnant in flatpak
- Firefox, Obsidian, aseprite also used here

SDDM handles login. Each user autologins on their VT via getty. Fish `loginShellInit` fires `exec Hyprland` on any `/dev/tty*`.

---

## Module Map

```
hosts/pod042/
  hardware-configuration.nix   — hardware, partitions, filesystems
  users.nix                    — system-level user declarations (wheel, groups, shell)

modules/core/
  audio.nix          — PipeWire stack
  boot.nix           — GRUB/EFI
  hardware.nix       — graphics, nvidia prime offload, bluetooth, touchpad
  networking.nix     — NetworkManager, SSH (key-only, no root), LocalSend
  locale.nix         — Tokyo timezone, en_US.UTF-8
  syncthing.nix      — syncs ~/Docs/Passwords with phone
  backup.nix         — daily systemd timer, 7z encrypted → gDrive + pod153

modules/desktop/
  default.nix        — SDDM (astronaut/hyprspace theme), hyprland system-level, fonts,
                       PAM, kdeconnect, programs.dconf.enable = true

users/
  neburion.nix / qellyree.nix / nululy.nix

home-modules/
  themes/
    catppuccin.nix / dark.nix / everforest.nix / gruvbox.nix / nord.nix
    — color palettes as Nix attrsets; theme files auto-generated for waybar/wofi/mako/hyprland/ghostty

  cli/
    default.nix       — fish, git, neovim, superfile, base packages, flatpak; imports dirs.nix
    dirs.nix          — declarative user dirs via systemd.user.tmpfiles.rules (%h = $HOME)
    fish.nix          — custom prompt, aliases (cdnixos, rebuild, trebuild, update, spf, mkrepo...)
    git.nix           — neburion <neburion@proton.me>, master branch, gh CLI SSH + nvim
    neovim/           — built with nvf: telescope, treesitter, cmp, LSP (C/C++, Rust, Python, Nix)
    superfile.nix     — editor: nvim
    claude/           — claude-code persona switcher: base.md + personas/{nyx,vanilla}.md +
                        claude-persona.sh; writes ~/.claude/CLAUDE.md as <persona> + base

  dev/
    default.nix       — gcc, python3, gnumake, cmake, gdb, godot, direnv, nix-direnv
    ai/default.nix    — claude-code, opencode (LD_LIBRARY_PATH wrapped)
    scripts/
      newc/newcpp/newpy/newrust.nix — project scaffolders (self-contained, git init)
      migrate-gaming.nix            — one-time migration (already run, do not run again)
      nixflash.nix                  — builds installer ISO, flashes to USB with dd

  desktop/
    default.nix       — shared desktop packages + xdg.userDirs
                        (blueman, signal, obsidian, loupe, nautilus, keepassxc,
                        solaar, razergenie, grim, slurp, wl-clipboard, ente-desktop,
                        celluloid, pavucontrol)
    art/default.nix   — aseprite, blender
    gaming/
      default.nix     — heroic, prismlauncher, steam (Proton-GE, remote play), jdk25
      apps.nix        — vesktop, spotify, obs-studio
      hyprland.nix    — gaming keybinds: Super+D=vesktop, Super+M=spotify, Super+G=heroic, Super+Shift+G=steam
    wm/
      default.nix     — imports all wm submodules
      gtk.nix         — Papirus-Dark icons, FiraMono 11, catppuccin-gtk/gruvbox/nordic/everforest
      hyprland/
        default.nix   — imports all hyprland subconfigs
        env.nix       — wayland/nvidia/gtk/cursor env vars
        monitors.nix  — monitor layout
        looks.nix     — dwindle layout, 5px gaps/rounding, blur, shadows, animations
        programs.nix  — app vars (terminal=ghostty, launcher=wofi, browser=zen, etc.)
        auto-exec.nix — startup: waybar, mako, swww-daemon, waypaper restore, nm-applet,
                        blueman-applet, hypr-session-restore
        keybinds.nix  — Super+Return=terminal, Super+Space=wofi, Super+Shift+Space=theme-switcher,
                        Super+Escape=SwitchToGreeter (SDDM lock),
                        Super+{F,W,A}=nautilus/waypaper/pavucontrol,
                        Super+{H,L,K,J}=focus, Super+Shift+{H,L,K,J}=move,
                        Super+1-0=workspaces, Print=screenshot, Super+{=,-}=volume
        session.nix   — hypr-session-save/restore scripts + autosave timer (every 5min)
        themes.nix    — generates ~/.config/hypr/themes/{name}.conf; sources active theme.conf
      waybar/         — left: clock+power; center: workspaces; right: tray+cpu/gpu/mem/vol
      wofi/           — dmenu launcher + wofi-power-menu + wofi-theme-switcher scripts
                        power-menu: save session before shutdown/reboot/logout; SwitchToGreeter for lock
                        theme-switcher: manages mako/gtk/ghostty/hyprland active theme + hyprctl reload
      mako/           — notifications, top-right, FiraMono 11, 5s timeout
      terminal/
        ghostty.nix   — FiraMono Nerd Font 11, block cursor; generates theme files; active theme via config-file
      wallpaper/      — swww daemon + waypaper GUI
                        folder: ~/Media/Wallpapers, default: Gruvbox-Face.png
                        waypaper config: ~/.config/waypaper/config.ini (user-managed, do not overwrite)

installer/
  nixinstall.sh  — guided install: disk select, disko partition, git clone NixOS, nixos-install
  nixrestore.sh  — restore from gDrive: rclone copy, 7z decrypt, cp to Docs/Media/Projects/.config
  disko.nix      — GPT layout: 1G EF00 vfat /boot, 17G swap, 100% ext4 /
  (embedded in flake.nix installer nixosConfiguration; ISO built via nixflash command)
```

---

## Theme System

- Five themes: dark, catppuccin, gruvbox, nord, everforest
- `wofi-theme-switcher` owns `~/.config/mako/config`, gtk-theme, `~/.config/hypr/theme.conf` (symlink), and `~/.config/ghostty/themes/active.conf` at runtime
- **Never** let HM manage `mako/config`, `gtk.theme`, `hypr/theme.conf`, or `ghostty/themes/active.conf`
- GTK dark: `color-scheme = "prefer-dark"` in dconf + `gtk-application-prefer-dark-theme = 1`
- Mako started by Hyprland `exec-once`, not systemd — **never** use `services.mako`
- Theme files auto-generated from `home-modules/themes/*.nix` — covers waybar, wofi, mako, hyprland shadows, ghostty colors
- Active theme initialized by `home.activation` (create-if-missing) to avoid rebuild resetting user's choice

---

## Wallpaper System

- **Engine**: swww (wayland wallpaper daemon)
- **Manager**: waypaper (GUI, user picks wallpaper themselves)
- **Folder**: `~/Media/Wallpapers`
- **Config**: `~/.config/waypaper/config.ini` — user-managed, never overwrite
- swww and waypaper restore launched by Hyprland auto-exec

---

## Session Persistence

- `hypr-session-save` — dumps `hyprctl clients -j` to `~/.local/share/hypr-session/last.json`
- `hypr-session-restore` — reads last.json, maps window classes to launch commands, relaunches
- Autosave timer: every 5 minutes via systemd user timer
- Power menu saves before shutdown/reboot/logout
- `hypr-session-restore` runs at Hyprland startup via `exec-once`

---

## Backup System

- Service: `modules/core/backup.nix` — runs daily as root
- neburion: Docs, Media, Projects, School, NixOS, zen/rclone/keepassxc configs
- qellyree: Gaming dir, vesktop/heroic configs
- Password: `/home/neburion/Docs/Passwords/backup-password`
- rclone config: `/home/neburion/.config/rclone/rclone.conf`
- Destinations: `gDrive:/Backups` (5d) + `pod153:/home/9s/Backups` (20d)
- Staging: `/tmp/backup-staging/`

---

## Passwords & Secrets

- All user passwords in `/root/.vault` (root-only, chmod 600)
- Retrieve via `sudo cat /root/.vault` (neburion has passwordless sudo)
- Syncthing syncs `~/Docs/Passwords` with phone

---

## Git Workflow

- Always: `git add [files] && git commit -m "..." && git push` — automatic, no asking
- Commit messages explain the why
- `.gitignore`: `Notes/.obsidian/workspace.json`, `.stfolder*/`
- Remote: GitHub (neburion/NixOS)

---

## Claude Persona System

- Two personas: `nyx` (default) and `vanilla`
- Defined in `~/NixOS/home-modules/cli/claude/personas/`
- Active CLAUDE.md at `~/.claude/CLAUDE.md` is a runtime-owned file, generated by `claude-persona <name>`
- The switcher concatenates `personas/<name>.md` + `base.md` (this file)
- First activation defaults to `nyx`; subsequent rebuilds never overwrite the active CLAUDE.md
- Check active persona: `claude-persona status`. List: `claude-persona list`. Switch: `claude-persona <name>`.

---

## Confirmed Facts (Do Not Re-Learn)

- `permittedInsecurePackages = ["electron-38.8.4"]` — obsidian on 25.11 uses electron_38
- `ELECTRON_OZONE_PLATFORM_HINT` not needed — NixOS 25.05+ handles it via XDG_SESSION_TYPE
- nvidia `open = true` correct for this GPU (Turing+)
- `powerManagement.enable = false` correct with PRIME offload
- system-level `systemd.services` use `description` (not `Unit.Description`)
- **HM 25.11 user services use raw INI format**: `Unit.Description`, `Service.Type`, `Service.ExecStart`, `Timer.OnActiveSec`, `Timer.Unit`, `Install.WantedBy` — NOT the simplified format
- ghostty: `scrollbar-style` is NOT a valid config field (caused build failure)
- SDDM is active. Theme: sddm-astronaut, embeddedTheme = "hyprspace"
- `programs.dconf.enable = true` required at system level for libadwaita (Nautilus) to respect prefer-dark in non-GNOME sessions
- Embedded bash scripts in nix let bindings: `${VAR}` gets interpolated by Nix. Move scripts to separate `.sh` files and use `builtins.readFile` — plain shell files have no escaping issues.
- `nix flake update --flake <path>` is valid syntax
