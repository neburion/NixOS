# Palette for the glass desktop preset.
#
# The glass preset itself does not read this — its shell colours are literals
# in quickshell-glass-shared/palette.nix, because "no themes" means the desktop
# does not switch. This entry exists for the tools that are still theme-driven
# by design and live outside any preset: neovim, fish, superfile, spotify. They
# follow ~/.local/state/quickshell/active-theme, and with nothing ever calling
# theme-set under glass they would otherwise sit on whatever palette was last
# picked — which is how nvim stayed gruvbox.
#
# Values match Common/Glass.qml: a neutral dark, deliberately not blue.
{
  bg             = "#101113";
  surface        = "#191B1E";
  selection      = "#26282C";
  fg             = "#E8EAEC";

  # Dead under glass — the picker filters by orientation, not by theme — but
  # the attrset is consumed by modules that still expect the field.
  wallpaperDir   = "Horizontal";

  gtkTheme       = "Adwaita-dark";
  fishPrimary    = "#C8CBCF";
  fishSecondary  = "#6E737A";
  superfileTheme = "onedark";
  nvimTheme      = "glass";
}
