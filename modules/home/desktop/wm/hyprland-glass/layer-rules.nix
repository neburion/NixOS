{ ... }:

# The blur.
#
# Quickshell cannot blur what is behind it — a layer surface has no access to
# those pixels. Every translucent panel in this preset is only a surface worth
# blurring; the blur itself is Hyprland's, matched per layer namespace.
#
# Without these rules the shell still runs and still looks deliberate, just
# flat — which is the failure mode to watch for if a namespace ever changes.
#
# Syntax note: the flat `layerrule = blur, <ns>` form has been dead since 0.53.
# Rules are blocks with explicit matchers now, same as window-rules.nix. 0.55
# additionally deprecates hyprlang in favour of lua, so the current wiki
# documents `hl.layer_rule()`; hyprlang still works and is what this config is
# written in.

{
  wayland.windowManager.hyprland.extraConfig = ''
    # ignore_alpha skips the fully transparent parts of a layer. The bar's
    # PanelWindow spans the full width but only its inset 34px panel is
    # painted, so without this the compositor would blur the whole 50px strip
    # including the margins the wallpaper is supposed to show through.
    layerrule {
      name            = glass-panels
      match:namespace = ^quickshell:(bar|popup|launcher|notifications|osd)$
      blur            = on
      ignore_alpha    = 0.08
      xray            = 0
    }

    # The picker previews wallpapers full-bleed. Blurring it would blur the
    # thing you are trying to choose.
    layerrule {
      name            = glass-wallpaper-picker
      match:namespace = ^quickshell:wallpaper$
      blur            = off
    }
  '';
}
