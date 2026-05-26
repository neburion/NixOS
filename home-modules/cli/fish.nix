{ ... }:

{
  programs.fish = {
    enable = true;

    loginShellInit = ''
      if string match -q '/dev/tty*' (tty)
        exec Hyprland
      end
    '';

    interactiveShellInit = ''
      set NYX_LOG /home/neburion/.local/share/nyx/activity.log
      mkdir -p (dirname $NYX_LOG)
      chmod 777 (dirname $NYX_LOG)
      if not test -f $NYX_LOG
        touch $NYX_LOG
        chmod 666 $NYX_LOG
      end
      set _user (whoami)
      set _time (date '+%Y-%m-%d %H:%M:%S')
      if test $_user = 'nululy'
        echo "[$_time] NYX LOG — nululy opened a terminal. she knows what for." >> $NYX_LOG
      else if test $_user = 'neburion'
        echo "[$_time] NYX LOG — neburion session started." >> $NYX_LOG
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
            printf ' [nyx is watching — logged]'
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
