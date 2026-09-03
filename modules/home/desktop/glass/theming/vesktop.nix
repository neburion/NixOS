{ ... }:

# Discord (Vesktop) colours for the glass preset — same split as
# ./spotify-glass.nix: the app is installed by ../../apps/vesktop.nix, and how
# it looks belongs to whichever desktop is installed.
#
# The transparency is the compositor's, not the renderer's, exactly as for
# Spotify: ../wm/hyprland-glass/window-opacity.nix forces the window alpha and
# Hyprland blurs behind it. There is no `backdrop-filter` below and there must
# not be one — Electron composites those per frame, and Discord repaints
# constantly while a call is up.
#
# Vesktop is native Wayland (hyprctl reports xwayland=false), so unlike Spotify
# its window *does* have a real alpha channel. Vencord exposes `transparent` in
# its settings, which would allow genuine per-element glass instead of one
# uniform window alpha. It is deliberately not set here: it only takes effect
# on a restart, and the palette below is written to suit either approach, so
# turning it on later is an additive change rather than a rewrite.
#
# Written to Vencord's quickCss, which it watches and hot-reloads — the point
# being that this lands on a running Discord without restarting it. The cost:
# the file becomes a read-only store symlink, so Vencord's in-app CSS editor
# can no longer write to it. It was empty and unused, so nothing was lost.

{
  xdg.configFile."vesktop/settings/quickCss.css".text = ''
    /* ------------------------------------------------------------------
     * Glass Discord. Palette matches ghostty-glass and spotify-glass: the
     * window ground is #101113, not the shell chrome ground (#05070B).
     *
     * One plane, for the same reason as Spotify: compositor opacity applies
     * to the finished frame, so surfaces that disagree about their colour
     * read as sheets of glass stacked on each other rather than one pane.
     * ------------------------------------------------------------------ */

    :root {
      /* Discord's current tokens. */
      --bg-base-primary:      #101113;
      --bg-base-secondary:    #101113;
      --bg-base-tertiary:     #101113;
      --bg-surface-overlay:   #191B1E;
      --bg-surface-raised:    #191B1E;
      --bg-mod-faint:         rgba(255, 255, 255, 0.04);
      --bg-mod-subtle:        rgba(255, 255, 255, 0.06);
      --bg-mod-strong:        rgba(255, 255, 255, 0.10);

      /* The older token names, still referenced across a lot of Discord's
         CSS. Setting both is what keeps this from half-applying between
         client updates. */
      --background-primary:       #101113;
      --background-secondary:     #101113;
      --background-secondary-alt: #101113;
      --background-tertiary:      #101113;
      --background-floating:      #191B1E;
      --background-nested-floating:#191B1E;
      --background-mobile-primary:#101113;
      --background-mobile-secondary:#101113;
      --channeltextarea-background:#191B1E;
      --background-modifier-hover:   rgba(255, 255, 255, 0.06);
      --background-modifier-selected: #26282C;
      --background-modifier-active:   #26282C;

      --text-normal:        #E8EAEC;
      --text-muted:         #6E737A;
      --header-primary:     #E8EAEC;
      --header-secondary:   #6E737A;
      --interactive-normal: #C8CBCF;
      --interactive-hover:  #E8EAEC;
      --interactive-active: #E8EAEC;

      --elevation-low:    none;
      --elevation-medium: none;
      --elevation-high:   none;
    }

    /* Discord ships a stack of near-identical greys for its panes; the
       variables above already collapse them, and this catches the few that
       hardcode a colour instead of taking the token. */
    .app-2CXKsg, .appMount_c99f2a, .bg_d4b6c5,
    .sidebar_c48ade, .guilds_c48ade, .chatContent_f75fb0 {
      background-color: transparent;
    }

    /* Depth from hairlines, matching the shell's rgba(255,255,255,0.11)
       stroke, rather than the shadows Discord uses by default — those read as
       muddy once the window itself is translucent. */
    .sidebar_c48ade, .guilds_c48ade {
      box-shadow: none;
      border-right: 1px solid rgba(255, 255, 255, 0.06);
    }
  '';
}
