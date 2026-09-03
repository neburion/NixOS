{ ... }:

# Spotify, unstyled.
#
# The colours are not here — they belong to whichever desktop is installed:
#
#   ../desktop/theming/spotify.nix        palette-driven (clean, simple)
#   ../desktop/theming/spotify-glass.nix  the fixed glass scheme
#
# Both are imported by their preset, the same way ../desktop/terminal/ghostty*
# is. A host that imports this file and no preset gets the stock Spotify look,
# which is the correct answer for a machine with no desktop to match.
#
# Why the styling cannot live here: spicetify bakes color.ini into the spiced
# Spotify derivation at build time, and the result is a read-only store path.
# There is no runtime switch — `spicetify` isn't even on PATH, and could not
# write into /nix/store if it were — so the themeHook this file used to
# register was a no-op from the day it was written. Choosing the scheme is a
# build-time decision, which makes it the preset's decision.

{
  programs.spicetify.enable = true;
}
