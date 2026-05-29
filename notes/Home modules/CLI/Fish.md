# Fish

`home-modules/cli/fish.nix`.

## Auto-launch hyprland on TTY login

```fish
loginShellInit = ''
  if string match -q '/dev/tty*' (tty)
    exec Hyprland
  end
'';
```

When fish becomes the login shell on a tty (because the user's `shell = pkgs.fish` and they log in from a console — including TTY1 right after boot), it `exec`s hyprland. SDDM is the normal entry point, but this is a fallback that means typing the username + password on TTY1 also gets you to a graphical session.

## Aliases

| Alias | Command |
|---|---|
| `cdnixos` | `cd $HOME/NixOS` |
| `rebuild` | `sudo nixos-rebuild switch --flake $HOME/NixOS#pod042` |
| `trebuild` | `sudo nixos-rebuild test --flake $HOME/NixOS#pod042` |
| `update` | `sudo nix flake update && sudo nixos-rebuild switch …#pod042` |
| `spf` / `sspf` | superfile / `sudo superfile` |
| `cd-dev` | `cd ~/Projects/Dev` |
| `mkrepo` | `gh repo create $(basename $PWD) --public --source=. --remote=origin --push` |
| `rmrepo` | `git remote remove origin && gh repo delete neburion/$(basename $PWD)` |

## Theme-synced prompt

Two universal variables (`fish_theme_primary`, `fish_theme_secondary`) hold prompt colors. Defaults match the `dark` theme:

```fish
set -q fish_theme_primary;   or set -U fish_theme_primary   aaaaaa
set -q fish_theme_secondary; or set -U fish_theme_secondary 666666
```

When the user runs `wofi-theme-switcher` ([[Concepts/Theme switching]]), it sets these universal variables for the new palette — all running fish sessions update instantly.

## Prompt

`fish_prompt` = `user@host:pwd$ ` (single line). `fish_right_prompt` = current git branch when in a repo. `fish_greeting` is suppressed.

## See also

- [[Concepts/Theme switching]]
- [[Modules/Core]] — `programs.fish.enable` at system level (required because users use fish as login shell)
