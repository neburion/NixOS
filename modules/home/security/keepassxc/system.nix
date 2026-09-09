{ ... }:

# Syncthing's half of KeePassXC: the folder that carries ~/Passwords to both
# phones. It lives here rather than in modules/system/network/syncthing.nix
# for the same reason the printer's tunnel lives with the printer -- delete
# KeePassXC and this folder is junk. syncthing.nix owns the transport and the
# device list; this owns one folder on it.
#
# Declaring it here is not optional. services.syncthing.overrideFolders
# defaults to true, so a folder added through the Syncthing web UI is deleted
# on the next rebuild -- ~/Sync/.stfolder.removed-20260716-180448 is the
# fossil of that happening once already.

{
  services.syncthing.settings.folders."Passwords" = {
    path    = "/home/neburion/Passwords";
    id      = "passwords";
    devices = [ "gPhone" "iPhone" ];

    # The conflict window is exactly the span a save sits unpropagated, so
    # this is the setting that actually prevents conflicts rather than
    # cleaning up after them: push about a second after KeePassXC writes,
    # instead of waiting out a rescan. The hourly rescan stays as a backstop
    # for changes inotify misses.
    fsWatcherEnabled = true;
    fsWatcherDelayS  = 1;
    rescanIntervalS  = 3600;

    ignorePatterns = [
      # KeePassXC writes {DB_FILENAME}.old.kdbx before every save. Syncing it
      # doubles the traffic and lets the backup generate conflicts of its own.
      "*.old.kdbx"
      # Per-machine state. Replicated, it tells the phones the database is
      # held open by a host they cannot see.
      "*.lock"
      #
      # Deliberately NOT ignoring *.sync-conflict-* here, which is the usual
      # advice elsewhere. Syncthing writes the conflict copy on whichever
      # device pulled the losing change -- and when that device is a phone,
      # ignoring the pattern strands those edits on the phone, where no app
      # can merge them. Letting them replicate means every conflict lands on
      # the one machine that has keepassxc-cli and pwmerge. They are ~300 KB.
    ];

    # A merge only becomes dangerous if the pre-merge file is gone. Staggered
    # keeps hourly copies for a day, daily for a month, weekly for a year, in
    # ~/Passwords/.stversions -- which restic already backs up nightly, since
    # users/neburion/dirs.nix lists ~/Passwords under backup.paths.
    versioning = {
      type = "staggered";
      params = {
        cleanInterval = "3600";
        maxAge        = "31536000";
      };
    };
  };
}
