{ pkgs, lib, zen-browser, ... }:

{
  home.packages = [
    zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  # Zen is the default browser, said out loud rather than left to chance.
  #
  # Nothing declared http/https here until helium.nix arrived, and with no
  # entry in mimeapps.list the handler resolves to whichever desktop file the
  # cache lists first — which `helium.desktop` won on sort order alone. So
  # every link out of Thunderbird, vesktop or xdg-open silently changed
  # browser the moment a second one was installed.
  #
  # Written by activation rather than `xdg.mimeApps.defaultApplications`, for
  # the reason set out at length in the desktop's zathura.nix: enabling that
  # module makes ~/.config/mimeapps.list a read-only symlink, and that file is
  # not ours alone — Thunderbird, vesktop and claude-code all register
  # themselves in it at runtime.
  #
  # Guarded on the current value, so switching browser by hand stays switched
  # until this module is rebuilt.
  home.activation.zenBrowserDefault = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    for scheme in x-scheme-handler/http x-scheme-handler/https text/html; do
      if [ "$(${pkgs.xdg-utils}/bin/xdg-mime query default "$scheme")" != "zen.desktop" ]; then
        ${pkgs.xdg-utils}/bin/xdg-mime default zen.desktop "$scheme"
      fi
    done
  '';
}
