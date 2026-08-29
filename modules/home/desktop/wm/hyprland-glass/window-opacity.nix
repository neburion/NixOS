{ ... }:

# Which windows are translucent, and why the compositor does it rather than
# the app.
#
# The shell's own glass is a layer-surface problem, solved in ./layer-rules.nix.
# This is the window-surface half: apps that should be part of the same
# material but cannot paint themselves that way.
#
# Ghostty is not here — it has a real alpha channel and sets its own
# `background-opacity`, so ../../terminal/ghostty-glass.nix owns that value.
# Spotify cannot: it is CEF on XWayland, whose window has no alpha channel at
# all, so anything it paints transparent comes out black. Forcing the opacity
# at the compositor is the only transparency available to it — and it is the
# cheap one, since the blur is a pass Hyprland already runs for every other
# window. The alternative, a `backdrop-filter` inside the renderer, is what
# makes glassy spicetify themes stutter; see ../../theming/spotify-glass.nix.
#
# 0.92 matches ghostty-glass. Above ~0.95 the blur stops reading; below ~0.85
# album art starts looking washed out, because compositor opacity applies to
# the whole finished frame — text and artwork included — not just the chrome.
#
# `decoration:blur:ignore_opacity` in ./looks.nix is the other half of this:
# without it Hyprland skips the blur pass behind a window whose surface is
# opaque, and a forced-opacity Spotify would show the desktop unblurred.

{
  wayland.windowManager.hyprland.extraConfig = ''
    windowrule {
      name        = glass-spotify
      opacity     = 0.92 0.92
      match:class = ^([Ss]potify)$
    }
  '';
}
