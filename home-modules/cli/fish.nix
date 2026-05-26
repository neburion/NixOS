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

    functions = {
      fish_prompt = {
        body = ''
          if test (whoami) = 'nululy'
            set_color 'f38ba8'
            printf '%s@%s' (whoami) (hostname -s)
            set_color normal
            printf ':'
            set_color 'f38ba8'
            printf '%s' (string replace $HOME '~' $PWD)
            set_color normal
            set_color 'f38ba8'
            printf ' [nyx is watching]'
            set_color normal
            printf '$ '
          else
            set_color 'cba6f7'
            printf '%s@%s' (whoami) (hostname -s)
            set_color normal
            printf ':'
            set_color 'cba6f7'
            printf '%s' (string replace $HOME '~' $PWD)
            set_color normal
            set_color '555555'
            printf ' [nyx]'
            set_color normal
            printf '$ '
          end
        '';
      };

      fish_right_prompt = {
        body = ''
          set branch (git branch --show-current 2>/dev/null)
          if test -n "$branch"
            set_color '89b4fa'
            printf ' %s' $branch
            set_color normal
          end
        '';
      };
    };
  };
}
