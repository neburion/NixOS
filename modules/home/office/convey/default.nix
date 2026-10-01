{ pkgs, config, ... }:

# Convey — the mail client, and the only one, on the Posteo mailbox. A hard
# fork of Geary: the same codebase, the same conversation view, the same
# refusal to grow a calendar or a chat client, with the UI ported to
# GTK4/libadwaita. Looks were the only thing Geary was ever faulted for here,
# so this is that complaint and nothing else.
#
# A flatpak rather than a nixpkgs derivation, deliberately. Convey is
# Flathub-only, and a meson/Vala expression for it would be a package to carry
# — and to re-pin on every upstream tag — until this machine moves to Arch,
# and then throw away. The flatpak command is identical on both distros; the
# AUR carries `convey` if a native build is ever wanted instead.
#
# Requires the flathub remote at user scope: see
# modules/home/cli/flatpak/default.nix, which runs before this via the named
# DAG dependency.
#
# `flatpak` is called by absolute store path, not by name: home-manager's
# activation script runs with its own PATH, flatpak is not on it, and a bare
# `flatpak` there dies with "command not found" — which `|| true` then eats, so
# the rebuild prints Done and installs nothing.
#
# Account setup is interactive, for the usual reason: the Posteo app password
# lives in KeePassXC, not in the flake, and Convey has no declarative surface
# for accounts — no config file, no dconf keys.
#
#   host: imap.posteo.de:993 TLS / smtp.posteo.de:465 TLS, user
#   paperkite@posteo.com — Convey finds these itself from the address.
#
# ./system.nix is the half that lets it save that password at all.

{
  home.activation.installConvey =
    config.lib.dag.entryAfter [ "flatpakSetup" ] ''
      ${pkgs.flatpak}/bin/flatpak install --user --assumeyes --or-update \
        flathub net.donnybeelo.Convey || true
    '';
}
