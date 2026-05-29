# Core

`modules/core/` — essentials any system in this config wants. Four files; `default.nix` imports all.

## `nix.nix`
- `allowUnfree = true` (NVIDIA, spotify, …)
- Flakes + nix-command experimental features
- `auto-optimise-store`, `max-jobs = auto`, `cores = 0`
- Weekly automatic GC: `--delete-older-than 14d`
- `system.stateVersion = "25.11"` (do not change — pinned at install)

## `locale.nix`
- `time.timeZone = "Asia/Tokyo"`
- `i18n.defaultLocale = "en_US.UTF-8"`

## `security.nix`
- `security.sudo.wheelNeedsPassword = false`

`security.rtkit.enable` is NOT here — it lives in `modules/audio/pipewire.nix` because it exists for audio scheduling.

## `shell.nix`
- `programs.fish.enable = true` (system-wide — needed because users have `shell = pkgs.fish`)
- `EDITOR = "nvim"`, `SUDO_EDITOR = "nvim"` for all sessions

## See also

- [[Modules/Overview]]
- [[Home modules/CLI/Fish]] — user-level fish config (prompt, aliases)
- [[Home modules/CLI/Neovim]] — user-level neovim config
