{ ... }:

# The one thing every home-manager user needs regardless of what the machine
# is for.
#
# It used to import the theme switcher, which meant a headless server got
# `theme-set` and the whole themeHooks registry because it happened to import
# base.nix. Theme switching is a property of a desktop that has more than one
# palette — clean — and lives in desktop/clean/themes/ now.

{
  home.stateVersion = "25.11";
}
