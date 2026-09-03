{ pkgs, lib, themes }:
# Per-theme GTK4 and GTK3 CSS files, baked into the nix store at build time.
# Imported by gtk.nix (rebuild-time sync) and wofi-theme-switcher.nix (runtime switch).
let
  mkGtk4Css = t: ''
    @define-color accent_color ${t.fishPrimary};
    @define-color accent_bg_color ${t.fishPrimary};
    @define-color accent_fg_color ${t.bg};
    @define-color window_bg_color ${t.bg};
    @define-color window_fg_color ${t.fg};
    @define-color view_bg_color ${t.surface};
    @define-color view_fg_color ${t.fg};
    @define-color headerbar_bg_color ${t.surface};
    @define-color headerbar_fg_color ${t.fg};
    @define-color headerbar_border_color ${t.bg};
    @define-color card_bg_color ${t.surface};
    @define-color card_fg_color ${t.fg};
    @define-color popover_bg_color ${t.surface};
    @define-color popover_fg_color ${t.fg};
    @define-color sidebar_bg_color ${t.bg};
    @define-color sidebar_fg_color ${t.fg};
  '';

  # Uses palette's selection color (not accent) so hover/selection states stay neutral.
  # This fixes the yellow nm-applet highlight introduced by gruvbox-dark-gtk's GTK3 accent.
  mkGtk3Css = t: ''
    @define-color theme_selected_bg_color ${t.selection};
    @define-color selected_bg_color ${t.selection};
    @define-color theme_selected_fg_color ${t.fg};
    @define-color selected_fg_color ${t.fg};
  '';
in {
  gtk4Files = lib.mapAttrs (name: t:
    pkgs.writeText "gtk4-${name}.css" (mkGtk4Css t)
  ) themes;
  gtk3Files = lib.mapAttrs (name: t:
    pkgs.writeText "gtk3-${name}.css" (mkGtk3Css t)
  ) themes;
}
