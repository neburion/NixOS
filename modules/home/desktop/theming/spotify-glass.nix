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
        .Root__now-playing-bar,
        .Root__right-sidebar,
        .main-topBar-background {
          background-color: var(--spice-main);
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

        /* Rows come to rest flush with the panel's bottom edge instead of
           being cut in half by it.

           `proximity`, never `mandatory`. With `scroll-snap-align: end` the
           only legal rest positions are the ones where a row's bottom meets
           the viewport's, and scrollTop 0 is not one of them — under
           `mandatory` Chromium drags you off the top of the list to the
           nearest legal stop, measured here at 1286px, which lands you past
           the header and two dozen tracks every time a playlist opens.
           `proximity` snaps when a snap point is close and otherwise leaves
           the scroller alone, so the top of the list stays reachable.

           `proximity` alone is not enough either: its pull range scales with
           the viewport, so on a tall window scroll position 0 sits close
           enough to the first row-aligned stop to be dragged there — measured
           at 295px, which scrolls the header half out of view the moment a
           playlist opens. The zero-height `::before` fixes that by making 0 a
           snap point in its own right, at distance zero, so nothing outranks
           it. It has to be an empty box rather than the content wrapper
           itself: a snap area taller than the snapport makes every position
           where it covers the snapport valid, which would switch the row
           snapping off across the whole middle of the list.

           What remains, stated plainly: the end of a list is a legal rest
           position and is not row-aligned, so a partial row can still show
           when scrolled all the way down. Everywhere else lands flush.

           The viewport is OverlayScrollbars', not a Spotify element, so the
           handle is its data attribute. That applies snap-type to every
           scroller in the app, which costs nothing where nothing declares a
           snap target — only the track list does. */
        [data-overlayscrollbars-viewport] { scroll-snap-type: y proximity; }
        .main-trackList-trackListRow      { scroll-snap-align: end; }
        .main-view-container__scroll-node-child::before {
          content: ""; display: block; height: 0; scroll-snap-align: start;
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
