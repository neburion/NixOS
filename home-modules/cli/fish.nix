{ ... }:

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
      cdnixos  = "cd $HOME/NixOS";
      rebuild  = "sudo nixos-rebuild switch --flake $HOME/NixOS#pod042";
      trebuild = "sudo nixos-rebuild test --flake $HOME/NixOS#pod042";
      update   = "sudo nix flake update --flake $HOME/NixOS && sudo nixos-rebuild switch --flake $HOME/NixOS#pod042";

      # Superfile
      spf  = "superfile";
      sspf = "sudo superfile";

      # Dev
      cd-dev = "cd ~/Projects/Dev";
      mkrepo = "gh repo create (basename $PWD) --public --source=. --remote=origin --push";
      rmrepo = "git remote remove origin && gh repo delete neburion/(basename $PWD)";
    };

    # Defaults match the `dark` theme (themes/dark.nix). Switching themes via
    # wofi-theme-switcher overwrites these as universal variables.
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
}
