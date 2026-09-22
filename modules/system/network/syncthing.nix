{ ... }:

{
  # The fleet dashboard's sync tiles come from this user's syncthing API, and
  # the key for it lives in their config.xml. Set here rather than on the host
  # for the same reason `user` is: delete this file and the question of whose
  # syncthing to report on stops existing.
  fleetStatus.syncUser = "neburion";

  services.syncthing = {
    enable           = true;
    user             = "neburion";
    dataDir          = "/home/neburion";
    configDir        = "/home/neburion/.config/syncthing";
    openDefaultPorts = true;
    settings = {
      devices.gPhone = {
        id   = "723KVGX-JPRTWOT-KL43KCK-GGP3TLY-JBC4XBF-VDP5C2V-IGN5IWG-XGCOIQC";
        name = "gPhone";
      };
      devices.iPhone = {
        id   = "UEQQRPE-PZV4OAG-753CGEL-3Y3GCHX-YIBJOEX-AULCQFG-AAKE523-KBJAGAO";
        name = "iPhone";
      };
      folders."Sync" = {
        path    = "/home/neburion/Sync";
        id      = "sync-main";
        devices = [ "gPhone" "iPhone" ];
      };

      # ~/Docs/Notes holds two Obsidian vaults, Random/ and Todo/. The folder
      # is declared here and not in modules/home/office/obsidian.nix because
      # of the Orphan Rule: delete KeePassXC and ~/Passwords is an unreadable
      # kdbx, which is why that folder lives with its app -- but delete
      # Obsidian and this is still a tree of markdown any editor opens. The
      # notes are not Obsidian's, so the folder is not either.
      folders."Notes" = {
        path    = "/home/neburion/Docs/Notes";
        id      = "notes";
        devices = [ "gPhone" "iPhone" ];

        # Notes are edited in bursts and the vaults are ~140 KB, so there is
        # nothing to gain from Passwords' one-second push. The default watch
        # delay is enough; the hourly rescan backstops changes inotify drops.
        fsWatcherEnabled = true;
        fsWatcherDelayS  = 10;
        rescanIntervalS  = 3600;

        ignorePatterns = [
          # Obsidian's per-device UI state: which panes are open, where the
          # cursor sits. Every device rewrites it at launch, so replicating
          # it is a conflict generator and nothing else. The vault content
          # and the plugin settings beside it still sync.
          ".obsidian/workspace.json"
          ".obsidian/workspace-mobile.json"
          # Todo/ carries Job Search Status.ods. LibreOffice drops a lock
          # file next to an open document naming the host holding it.
          ".~lock.*#"
          #
          # Note that ignorePatterns writes this folder's .stignore, and
          # Syncthing never syncs that file. This covers pod042 only -- the
          # two phones will still trade workspace.json with each other and
          # leave conflict copies there. Setting it on them is app-side work
          # no NixOS option reaches.
        ];

        # A phone can delete a note as easily as it edits one, and Obsidian's
        # own trash is per-vault and local. Staggered keeps hourly copies for
        # a day, daily for a month, weekly for a year, in .stversions --
        # already covered by the nightly restic run, since dirs.nix lists
        # ~/Docs under backup.paths.
        versioning = {
          type = "staggered";
          params = {
            cleanInterval = "3600";
            maxAge        = "31536000";
          };
        };
      };
    };
  };
}
