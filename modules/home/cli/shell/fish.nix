{ pkgs, lib, themes, ... }:

let
  strip = lib.removePrefix "#";
  fishColorMap = lib.mapAttrs (_: t: {
    primary   = strip (t.fishPrimary   or "#ffffff");
    secondary = strip (t.fishSecondary or "#aaaaaa");
  }) themes;

  caseLines = lib.concatStringsSep "\n      " (lib.mapAttrsToList (n: c:
    ''${n}) primary="${c.primary}"; secondary="${c.secondary}" ;;''
  ) fishColorMap);
in
{
  programs.fish = {
    enable = true;

    loginShellInit = ''
      if string match -q '/dev/tty*' (tty)
        exec Hyprland
      end
    '';

    shellAliases = {
      # NixOS
      cdnixos = "cd $HOME/NixOS";
      # rebuild / trebuild / update: shell-agnostic scripts, see
      # modules/home/cli/nixos-scripts.nix

      # Superfile
      spf  = "superfile";
      sspf = "sudo superfile";

      # Quickshell
      qs = "quickshell --path $HOME/NixOS/modules/home/desktop/quickshell-shared";

      # Dev
      cddev = "cd ~/Projects/Dev";
      mkrepo = "gh repo create (basename $PWD) --public --source=. --remote=origin --push";
      rmrepo = "git remote remove origin && gh repo delete neburion/(basename $PWD)";
    };

    # Defaults match the `dark` theme (themes/dark.nix). Switching themes via
    # theme-set overwrites these as universal variables.
    interactiveShellInit = ''
      set -q fish_theme_primary;   or set -U fish_theme_primary   aaaaaa
      set -q fish_theme_secondary; or set -U fish_theme_secondary 666666
    '';

    functions = {
      fish_greeting = {
        body = "";
      };

      fish_prompt = {
        body = ''
          set_color $fish_theme_primary
          printf '%s@%s' (whoami) (hostname -s)
          set_color normal
          printf ':'
          set_color $fish_theme_primary
          printf '%s' (string replace $HOME '~' $PWD)
          set_color normal
          printf '$ '
        '';
      };

      fish_right_prompt = {
        body = ''
          set branch (git branch --show-current 2>/dev/null)
          if test -n "$branch"
            set_color $fish_theme_secondary
            printf ' %s' $branch
            set_color normal
          end
        '';
      };
    };
  };

  themeHooks.fish = pkgs.writeShellScript "theme-hook-fish" ''
    theme="$1"
    primary="aaaaaa"
    secondary="666666"
    case "$theme" in
      ${caseLines}
      *) ;;
    esac
    ${pkgs.fish}/bin/fish -c \
      "set -U fish_theme_primary $primary; set -U fish_theme_secondary $secondary" \
      2>/dev/null || true
  '';
}
