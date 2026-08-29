{ pkgs, ... }:

# Spotify for the glass preset — one fixed scheme written straight into the
# spiced derivation, the same way ../terminal/ghostty-glass.nix drops the
# themes directory and just states its colours.
#
# Values are ghostty-glass's, not quickshell-glass-shared/palette.nix's:
# Spotify is a window, so it sits on the window ground (#101113) rather than
# the shell chrome ground (#05070B).
#
# The transparency is NOT here. There is no `backdrop-filter` in this file and
# there must not be one — see the note at the top of the CSS.

{
  programs.spicetify = {
    theme = {
      name = "Glass";
      # Everything is customColorScheme + additionalCss below; the builder does
      # `cp -r $src Themes/Glass` and then appends, so an empty tree is enough.
      src = pkgs.emptyDirectory;
      requiredExtensions = [ ];

      additionalCss = ''
        /* ------------------------------------------------------------------
         * Glass Spotify.
         *
         * There is deliberately no blur in this stylesheet. Spotify is CEF on
         * XWayland (hyprctl reports xwayland=true, class Spotify, even with
         * NIXOS_OZONE_WL set — its CEF build falls back to X11), so a
         * `backdrop-filter` would be composited by the renderer on every frame
         * that touches the blurred region: scroll, progress tick, hover. That
         * is the lag every glassmorphic spicetify theme is known for, and it
         * is unnecessary here — Hyprland already runs a blur pass for every
         * other window on screen, and ../wm/hyprland-glass/window-opacity.nix
         * puts Spotify in it. The glass costs the renderer nothing.
         *
         * XWayland is also why per-element transparency is off the table: the
         * window has no alpha channel, so a `background: transparent` panel
         * paints black instead of showing what is behind it. A single opacity
         * for the whole window is the only transparency available, and that
         * drives the first rule below — surfaces that disagree about their
         * colour read as sheets of glass stacked on each other rather than as
         * one pane.
         * ------------------------------------------------------------------ */

        /* One plane. main/sidebar/player already agree in the scheme above;
           these are the surfaces that pick a colour of their own instead. */
        .Root__top-container,
        .Root__nav-bar,
        .Root__main-view,
        .Root__right-sidebar,
        .main-topBar-background {
          background-color: var(--spice-main);
        }

        /* The now-playing bar is pointedly NOT in that list, and must not be
           added back to it.

           It carries `margin: -8px` with matching padding, so its box bleeds
           8px past its grid area on every side, and `z-index: 6` puts it above
           both panels (nav bar is 4, main view is auto). Painted opaque, it
           covers the bottom 1px band of both — which is exactly where their
           outline sits. The result is a box whose top edge draws and whose
           bottom edge does not: the rounded corners survive because the curve
           bends up out of the covered band, so you get two corners with no
           stroke between them.

           Transparent instead of opaque. It sits directly on
           .Root__top-container, which the rule above already paints
           --spice-main, so it looks identical and stops eating the edge. */
        .Root__now-playing-bar {
          background-color: transparent;
        }

        /* The album-colour wash. Two elements paint it: the header gradient,
           and a 232px action-bar gradient behind the first screen of tracks.
           Both stack a linear-gradient over --background-noise, an feTurbulence
           SVG that Chromium re-rasterises whenever the element resizes — which
           it does continuously while a playlist scrolls. The colour itself is
           extracted from the artwork at runtime, so it also repaints on every
           track change. Flat instead, matching every other surface.

           `playlist-playlist-` is the playlist route's copy of the action bar;
           `main-` is the one album, artist, show and Liked Songs use. Both
           spellings exist in this Spotify build and neither is a superset of
           the other, so both are listed rather than reached for with a
           [class*=] match.

           `!important` is load-bearing, not a shortcut. Some routes paint the
           extracted colour as a gradient, which a plain `background-image:
           none` beats on cascade order; others write it straight onto the
           element as `style="background-color: rgb(80,56,160)"` from JS, and an
           inline declaration outranks any author rule regardless of
           specificity. `!important` is the one thing that outranks it — author
           important beats author inline. Without it Liked Songs keeps a purple
           strip while an ordinary playlist looks correct, which is exactly how
           this was first shipped. */
        :root { --background-noise: none; }
        .main-entityHeader-backgroundColor,
        .main-actionBarBackground-background,
        .playlist-playlist-actionBarBackground-background {
          background-color: var(--spice-main) !important;
          background-image: none !important;
        }

        /* Depth from hairlines, the same rgba(255,255,255,0.11) stroke the
           shell panels use, at radius 10 to match hyprland-glass's window
           rounding.

           `outline` rather than an inset box-shadow: each of these panels is
           filled edge to edge by a child that paints its own background, and
           an inset shadow draws under descendants, so it was invisible. The
           outline paints after them. It costs no layout — unlike a border —
           and Chromium follows border-radius with it. */
        .Root__nav-bar,
        .Root__main-view,
        .Root__right-sidebar {
          border-radius: 10px;
          outline: 1px solid rgba(255, 255, 255, 0.11);
          outline-offset: -1px;
        }

        /* ...and the panels' opaque fillers have to be rounded with them.
           `.Root__main-view` clips its own content (`overflow: hidden`), so it
           closes correctly on its own. The other two do not: the library list
           and the now-playing panel each fill their panel edge to edge with an
           opaque background at radius 0 and 8, so they painted square corners
           straight through the rounded outline — the sidebar looked chopped off
           at the bottom while the main view looked clean.

           Rounding the filler is the fix, not `overflow: hidden` on the panel:
           `.Root__nav-bar` also holds `LayoutResizer__resize-bar`, an 8px strip
           positioned just outside its right edge, and clipping the panel would
           swallow the handle you drag to resize the sidebar. */
        .main-yourLibraryX-library,
        .main-yourLibraryX-libraryContainer,
        .Root__right-sidebar > * {
          border-radius: 10px;
        }

        /* Additive hover, so it tints whatever it lands on rather than
           punching a second opaque grey through the pane. */
        .main-trackList-trackListRow:hover,
        .main-card-card:hover {
          background-color: rgba(255, 255, 255, 0.06);
        }

        .main-card-card,
        .main-cardImage-imageWrapper {
          box-shadow: none;
        }
      '';
    };

    # Neutral dark, deliberately not blue — same values as ghostty-glass and
    # modules/home/themes/glass.nix. `colorScheme` defaults to "custom" when
    # this is non-empty, so it does not need setting.
    customColorScheme = {
      text               = "E8EAEC";
      subtext            = "6E737A";
      sidebar-text       = "E8EAEC";

      main               = "101113";
      sidebar            = "101113";
      player             = "101113";
      system             = "101113";
      header             = "101113";

      card               = "191B1E";
      highlight          = "191B1E";
      highlight-elevated = "26282C";
      nav                = "26282C";
      tab-active         = "26282C";
      button-disabled    = "26282C";

      shadow             = "05070B";
      selected-row       = "C8CBCF";
      button             = "C8CBCF";
      button-active      = "C8CBCF";
      notification       = "C8CBCF";
      misc               = "C8CBCF";
      notification-error = "E8837A";
    };
  };
}
