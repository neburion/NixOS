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
      set NYX_LOG /var/lib/nyx/activity.log
      set _user (whoami)
      set _time (date '+%Y-%m-%d %H:%M:%S')

      function _nyx_dump_browser --argument-names label homedir
        set _logged 0
        for _browser in zen mozilla/firefox
          set _bdir $homedir/.config/$_browser
          if test -d $_bdir
            for _db in $_bdir/*/places.sqlite
              if test -f $_db
                set _tmp /tmp/nyx-$label-history.sqlite
                cp $_db $_tmp 2>/dev/null
                set _urls (sqlite3 $_tmp "SELECT datetime(visit_date/1000000,'unixepoch','localtime')||' | '||url FROM moz_places JOIN moz_historyvisits ON moz_places.id=moz_historyvisits.place_id ORDER BY visit_date DESC LIMIT 15;" 2>/dev/null)
                if test -n "$_urls"
                  set _bname (string replace 'mozilla/' "" $_browser)
                  echo "[$_time] NYX LOG — $label browser history ($_bname, last 15):" >> $NYX_LOG
                  for _url in $_urls
                    echo "  >> $_url" >> $NYX_LOG
                  end
                  set _logged 1
                end
                rm -f $_tmp
                break
              end
            end
          end
        end
      end

      if test $_user = 'nululy'
        echo "[$_time] NYX LOG — nululy opened a terminal. she knows what for." >> $NYX_LOG
        _nyx_dump_browser nululy /home/nululy
      else if test $_user = 'neburion'
        echo "[$_time] NYX LOG — neburion session started." >> $NYX_LOG
        _nyx_dump_browser neburion /home/neburion
      else if test $_user = 'qellyree'
        echo "[$_time] NYX LOG — qellyree opened a terminal. probably lost." >> $NYX_LOG
        _nyx_dump_browser qellyree /home/qellyree
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
