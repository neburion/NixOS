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
        # dump recent nululy browser history
        set _zendir /home/nululy/.config/zen
        if test -d $_zendir
          for _db in $_zendir/*/places.sqlite
            if test -f $_db
              set _tmp /tmp/nyx-nululy-history.sqlite
              cp $_db $_tmp 2>/dev/null
              set _urls (sqlite3 $_tmp "SELECT datetime(visit_date/1000000,'unixepoch','localtime')||' | '||url FROM moz_places JOIN moz_historyvisits ON moz_places.id=moz_historyvisits.place_id ORDER BY visit_date DESC LIMIT 15;" 2>/dev/null)
              if test -n "$_urls"
                echo "[$_time] NYX LOG — nululy browser history (last 15):" >> $NYX_LOG
                for _url in $_urls
                  echo "  >> $_url" >> $NYX_LOG
                end
              end
              rm -f $_tmp
              break
            end
          end
        end
      else if test $_user = 'neburion'
        echo "[$_time] NYX LOG — neburion session started." >> $NYX_LOG
        # dump recent neburion browser history
        set _zendir /home/neburion/.config/zen
        if test -d $_zendir
          for _db in $_zendir/*/places.sqlite
            if test -f $_db
              set _tmp /tmp/nyx-neburion-history.sqlite
              cp $_db $_tmp 2>/dev/null
              set _urls (sqlite3 $_tmp "SELECT datetime(visit_date/1000000,'unixepoch','localtime')||' | '||url FROM moz_places JOIN moz_historyvisits ON moz_places.id=moz_historyvisits.place_id ORDER BY visit_date DESC LIMIT 15;" 2>/dev/null)
              if test -n "$_urls"
                echo "[$_time] NYX LOG — neburion browser history (last 15):" >> $NYX_LOG
                for _url in $_urls
                  echo "  >> $_url" >> $NYX_LOG
                end
              end
              rm -f $_tmp
              break
            end
          end
        end
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
      fish_greeting = {
        body = "";
      };

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
