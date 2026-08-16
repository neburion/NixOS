{ pkgs, lib, config, ... }:

# Screen dark, for the lock screen only. The script and cover images live in
# screen-dark-pkg.nix; this file wires them into the session.
#
# Deliberately NOT dpms, NOT ddcutil:
#   - dpms off/on left the MSI G321CU presenting a stale frame while the
#     output reported healthy, recoverable only by a forced mode change.
#   - DDC brightness writes are one-way in practice: the LG on DP-1 stopped
#     answering EDID reads mid-cycle, so the saved level could never be
#     written back and the panel stayed at 0.
# Neither monitor leaves its normal power state here. The externals go black
# because they are being sent black pixels, which is all "dark" ever needed.

let
  screenDark = import ./screen-dark-pkg.nix {
    inherit pkgs;
    homeDirectory = config.home.homeDirectory;
  };
in
{
  home.packages = [ screenDark.script ];

  # `bindl` is the "still fires while the session is locked" variant, the same
  # flag lid.nix relies on.
  #
  # SHIFT is not decoration: $mod+D alone is already $discord (vesktop). Two
  # binds on one combo do not politely take turns by lock state — the plain
  # one shadows this one, which is exactly why the first version did nothing.
  wayland.windowManager.hyprland.settings.bindl = [
    "$mod SHIFT, D, exec, ${screenDark.script}/bin/screen-dark"
  ];

  # Always start clear. A rebuild while the cover happened to be black would
  # otherwise leave the next lock screen blacked out with nothing armed to
  # undo it.
  home.activation.resetLockCover = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "$(dirname "${screenDark.coverLink}")"
    ln -sfn "${screenDark.coverClear}" "${screenDark.coverLink}"
  '';
}
