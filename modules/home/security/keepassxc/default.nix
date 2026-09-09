{ pkgs, ... }:

# KeePassXC, plus the machinery for surviving a synced database.
#
# The database lives in ~/Passwords and is carried to both phones by
# Syncthing (see ./system.nix). Syncthing has no idea what a .kdbx is: it
# sees one opaque 300 KB blob, so two devices editing between syncs cannot
# be reconciled by it. It keeps one version and renames the loser to
# `Passwords.sync-conflict-<date>-<device>.kdbx`. Nothing is deleted -- both
# files sit in the folder, and it is our job to fold them back together.
#
# That fold is well-defined rather than a guess, because KDBX 4.1 stores a
# modification timestamp on every entry and a tombstone list for deletions.
# `keepassxc-cli merge` reads both, takes the newer side of any collision,
# and pushes the older value into that entry's history -- so even a losing
# edit stays recoverable. `pwmerge` below is the front-end for it.

{
  home.packages = with pkgs; [
    keepassxc
  ];

  programs.fish.functions = {
    # Fold every sync-conflict copy back into the real database.
    #
    # Always previews first: `--dry-run` prints the entry-level changes and
    # writes nothing, and only an explicit y applies them. The preview for a
    # second conflict file is computed against the pre-merge database, so it
    # can slightly understate what the second merge does -- harmless, since
    # timestamp resolution gives the same result in either order.
    pwmerge = {
      body = ''
        set -l dir "$HOME/Passwords"
        set -l db  "$dir/Passwords.kdbx"

        if not test -f "$db"
          echo "pwmerge: no database at $db" >&2
          return 1
        end

        set -l conflicts (find "$dir" -maxdepth 1 -name '*.sync-conflict-*.kdbx' | sort)

        if test (count $conflicts) -eq 0
          echo "pwmerge: no conflicts"
          return 0
        end

        echo "pwmerge: "(count $conflicts)" conflict file(s) to merge into Passwords.kdbx"

        # One prompt for the whole run. --same-credentials reuses it for the
        # conflict copy, which always shares the master key: Syncthing only
        # ever duplicated our own file. keepassxc-cli reads the password from
        # stdin when stdin is not a terminal, so it never reaches argv.
        #
        # stderr carries only the "Enter password to unlock" echo; the actual
        # change list goes to stdout, hence the 2>/dev/null.
        read -s -l -P "Master password: " pw
        echo

        for c in $conflicts
          echo
          echo "--- "(basename $c)
          printf '%s\n' $pw | keepassxc-cli merge -s --dry-run "$db" "$c" 2>/dev/null
          or begin
            echo "pwmerge: cannot read "(basename $c)" (wrong password?); nothing written" >&2
            set -e pw
            return 1
          end
        end

        echo
        read -l -P "Apply? [y/N] " ok
        if not string match -qi y -- $ok
          echo "pwmerge: aborted, nothing written"
          set -e pw
          return 1
        end

        for c in $conflicts
          printf '%s\n' $pw | keepassxc-cli merge -s "$db" "$c" 2>/dev/null
          or begin
            echo "pwmerge: merging "(basename $c)" failed; leaving it in place" >&2
            set -e pw
            return 1
          end
          # Safe to drop: the pre-merge database is in .stversions, and the
          # losing side of any collision is in the entry's history.
          rm -- "$c"
          echo "pwmerge: merged and removed "(basename $c)
        end

        set -e pw
      '';
    };
  };

  # A conflict is silent by default -- the database keeps working, it just
  # quietly stops carrying the other device's edits. Left unnoticed the two
  # sides drift for weeks. This says so the moment a conflict file lands.
  #
  # PathChanged, not PathExistsGlob. PathExistsGlob stays *satisfied* while
  # the file exists, so systemd re-triggers the service the instant it exits
  # and spins until it trips the start limit -- measured, not theorised.
  # PathChanged is edge-triggered on the directory, so it fires once per
  # change. The service is what decides whether a conflict is actually there.
  systemd.user.paths.keepassxc-conflict = {
    Unit.Description = "Watch ~/Passwords for Syncthing conflict copies";
    Path.PathChanged = "%h/Passwords";
    Install.WantedBy = [ "default.target" ];
  };

  systemd.user.services.keepassxc-conflict = {
    Unit.Description = "Report a KeePassXC sync conflict";
    Service = {
      Type = "oneshot";
      # Every save and every Syncthing write changes the directory, so this
      # runs often and must be cheap: it exits in milliseconds when there is
      # nothing to report, and stays quiet about a conflict set it has
      # already announced. The stamp lives in the runtime dir -- outside
      # ~/Passwords, so writing it cannot retrigger the path unit or sync to
      # the phones -- which also means one reminder per login. Deliberate.
      ExecStart = toString (pkgs.writeShellScript "keepassxc-conflict-notify" ''
        set -u
        stamp="''${XDG_RUNTIME_DIR:-/tmp}/keepassxc-conflict.stamp"
        conflicts=$(find "$HOME/Passwords" -maxdepth 1 -name '*.sync-conflict-*.kdbx' | sort)

        if [ -z "$conflicts" ]; then
          rm -f "$stamp"
          exit 0
        fi

        now=$(printf '%s\n' "$conflicts" | ${pkgs.coreutils}/bin/sha256sum | cut -d' ' -f1)
        [ -f "$stamp" ] && [ "$(cat "$stamp")" = "$now" ] && exit 0
        printf '%s\n' "$now" > "$stamp"

        n=$(printf '%s\n' "$conflicts" | wc -l)
        ${pkgs.libnotify}/bin/notify-send \
          --urgency=critical \
          --icon=dialog-warning \
          "KeePassXC: $n sync conflict(s)" \
          "Two devices edited the database. Run <b>pwmerge</b> to fold them back together."
      '');
    };
  };
}
