{ pkgs, ... }:

# Anki — spaced repetition.
#
# `pkgs.anki`, the source build, not `anki-bin`. They are the same program, but
# the binary drop in this channel sits at 25.02.5 while the built one is
# 25.09.4, and the client talks to AnkiWeb over a versioned sync protocol: an
# old Anki is one that eventually refuses to sync. Both are cached, so the
# source build costs nothing here.
#
# Decks are not packaged, and no Nix answer for them exists. nixpkgs has
# exactly three Anki programs — anki, anki-bin, anki-sync-server — plus the
# addon set ./addons.nix draws on, and nothing that carries cards. Shared decks
# are .apkg files from ankiweb.net/shared/decks, pulled in through File ▸
# Import; they land in the collection at ~/.local/share/Anki2, which is
# mutable user data of the same kind as a save file and deliberately outside
# the flake. Pinning the .apkg with fetchurl would not change that — the import
# is still a manual step, and AnkiWeb's download URLs are hash-stamped and do
# not survive a deck being updated.

{
  home.packages = [
    (pkgs.anki.withAddons (import ./addons.nix { inherit pkgs; }))
  ];
}
