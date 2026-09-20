{ pkgs, lib, ... }:

# The one tool here that carves a diff up rather than reading one. tig can do
# the same from the keyboard; this does it by dragging across lines, which is
# the difference that matters when a session ends with six unrelated changes
# sitting in one working tree.
#
# Not in git.nix beside tig, because server-admin imports that file directly
# and a headless host has no use for a window.

{
  home.packages = [ pkgs.sublime-merge ];

  # Sublime rewrites Preferences.sublime-settings itself whenever a setting is
  # changed from a menu, so a store symlink would break the menus rather than
  # pin them. Seeded once and then left alone, the way active.conf is in
  # clean/terminal.nix.
  #
  # Only one key is worth seeding: the binary lives in the store and cannot
  # replace itself, so an update check can do nothing but raise a dialog that
  # is wrong on this system. It fired on the very first launch.
  home.activation.initSublimeMergePrefs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    PREFS="$HOME/.config/sublime-merge/Packages/User/Preferences.sublime-settings"
    if [ ! -f "$PREFS" ]; then
      mkdir -p "$(dirname "$PREFS")"
      echo '{ "update_check": false }' > "$PREFS"
    fi
  '';
}
