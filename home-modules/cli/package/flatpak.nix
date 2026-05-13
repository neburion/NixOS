{ config, ... }:

{
  home.activation.flatpakSetup =
    config.lib.dag.entryAfter [ "writeBoundary" ] ''
      flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || true
    '';
}
