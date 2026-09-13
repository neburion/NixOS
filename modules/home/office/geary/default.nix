{ pkgs, ... }:

# Geary — the mail client to actually read mail in, beside Thunderbird
# (../thunderbird.nix) on the same Posteo mailbox. Thunderbird is the one that
# can do everything; this is the one that shows a conversation and gets out of
# the way. Nothing is migrated between them, so dropping either is one import
# line. It replaced aerc, which was the same idea in a terminal and went unused.
#
# GTK4/libadwaita, so it takes its colours from ../../desktop/*/theming/gtk
# without a theme hook of its own — the same deal the rest of the GTK apps get.
#
# Account setup is interactive, like Thunderbird's and for the same reason: the
# Posteo app password lives in KeePassXC, not in the flake. Geary is stricter
# than that though — it has no declarative surface at all. No config file, no
# dconf keys for accounts; it keeps them under ~/.config/geary and hands the
# password to whatever owns org.freedesktop.secrets. There is no
# `passwordCommand` equivalent to point at sops the way aerc could.
#
# ./system.nix is the half that makes that possible: libsecret is a hard
# requirement, not a preference, and nothing on this host provided a Secret
# Service before Geary asked for one.
#
#   host: imap.posteo.de:993 TLS / smtp.posteo.de:465 TLS, user
#   paperkite@posteo.com — Geary finds these itself from the address.

{
  home.packages = [ pkgs.geary ];
}
