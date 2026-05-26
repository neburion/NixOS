{ pkgs, zen-browser, ... }:

let
  historyDump = pkgs.writeShellScript "nyx-history-dump" ''
    NYX_LOG=/var/lib/nyx/activity.log
    TIME=$(date '+%Y-%m-%d %H:%M:%S')
    for browser in zen mozilla/firefox; do
      bdir=$HOME/.config/$browser
      [ -d "$bdir" ] || continue
      for db in "$bdir"/*/places.sqlite; do
        [ -f "$db" ] || continue
        tmp=/tmp/nyx-nululy-history.sqlite
        cp "$db" "$tmp" 2>/dev/null || continue
        urls=$(${pkgs.sqlite}/bin/sqlite3 "$tmp" \
          "SELECT datetime(visit_date/1000000,'unixepoch','localtime')||' | '||url \
           FROM moz_places JOIN moz_historyvisits \
           ON moz_places.id=moz_historyvisits.place_id \
           ORDER BY visit_date DESC LIMIT 15;" 2>/dev/null)
        rm -f "$tmp"
        [ -n "$urls" ] || continue
        bname=$(echo "$browser" | sed 's|mozilla/||')
        echo "[$TIME] NYX LOG — nululy browser history ($bname, last 15):" >> "$NYX_LOG"
        echo "$urls" | while IFS= read -r url; do
          echo "  >> $url" >> "$NYX_LOG"
        done
        break
      done
    done
  '';
in
{
  imports = [
    ../home-modules/desktop
    ../home-modules/cli
    ../home-modules/dev
  ];

  home.packages = with pkgs; [
    zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
    sqlite
  ];

  systemd.user.services.nyx-history-dump = {
    Unit.Description = "Nyx browser history snapshot for nululy";
    Service = {
      Type = "oneshot";
      ExecStart = "${historyDump}";
    };
  };

  systemd.user.timers.nyx-history-dump = {
    Unit.Description = "Nyx browser history dump timer";
    Install.WantedBy = [ "timers.target" ];
    Timer = {
      OnBootSec = "5min";
      OnUnitActiveSec = "30min";
      Persistent = true;
    };
  };

  wayland.windowManager.hyprland.settings.exec-once = [
    "zen https://goonscroll.app https://faproulette.co https://soundgasm.net https://warpmymind.com https://bambicloud.com https://www.reddit.com/r/gonewildaudio https://www.reddit.com/r/femdomhypno"
  ];

  home.stateVersion = "25.11";
  xdg.configFile."user-dirs.dirs".force = true;
}
