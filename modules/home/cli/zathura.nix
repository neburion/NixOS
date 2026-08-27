{ themes, ... }:

let
  t = themes.glass;

  # themes/glass.nix carries the grounds as hex; zathura needs alpha on the
  # ones that should let the compositor through, so those are restated as
  # rgba() literals of the same values:
  #   bg #101113 -> 16,17,19   surface #191B1E -> 25,27,30
  ground  = a: "rgba(16,17,19,${a})";
  raised  = a: "rgba(25,27,30,${a})";

  # ghostty-glass ANSI accents, restated here for the same reason superfile.nix
  # restates them: the shared attrset only carries ground/text colours.
  red    = "#E8837A";
  yellow = "#D8BE96";
  blue   = "#9FB0C2";
in

# Zathura for the glass preset.
#
# Two separate things are going on here, and they fail independently:
#
#  1. Chrome transparency. zathura parses CSS-style rgba(), and its GTK window
#     takes an RGBA visual, so every ground below is translucent and Hyprland's
#     window blur (hyprland-glass/looks.nix, 2 passes) does the rest. No
#     windowrule is needed — that blur is global and applies to any window that
#     ships alpha. Hex without alpha is fully opaque and is the thing to check
#     first if this ever comes out looking flat.
#
#  2. The page itself. A PDF page is white paper; nothing about a translucent
#     window changes that. `recolor` remaps the rendered pixels, and only with
#     it on does `recolor-lightcolor` become the page ground — which is why
#     that one is translucent too, so the sheet reads as smoked glass rather
#     than as a solid rectangle punched through the window.
#
# recolor-reverse-video is what keeps figures, photos and coloured diagrams
# alone: with it true the remap only touches the greyscale/near-greyscale
# pixels (text and rules), and anything with real chroma renders as authored.
# Without it every image in the document comes out negative. recolor-keephue
# is the weaker version of the same idea — it preserves hue while forcing
# lightness — and is off because reverse-video already covers the case it
# exists for, and the two together wash out coloured text.
#
# Ctrl-R toggles recolor at runtime (zathura's own default bind), which is the
# escape hatch for a document that renders wrong: it drops back to plain white
# paper without touching this file.
{
  programs.zathura = {
    enable = true;

    options = {
      font = "Geist Mono 10";

      # ── Window ────────────────────────────────────────────────────────────
      # 'c' the command line, 's' the statusbar, and no scrollbars: a GTK
      # scrollbar is opaque chrome and reads as a seam down the side of a
      # translucent window. 'c' is not optional — drop it and `/` and `:`
      # still work, but they type into an invisible bar.
      guioptions            = "cs";
      window-title-basename = true;
      statusbar-basename    = true;
      statusbar-home-tilde  = true;
      adjust-open           = "best-fit";
      page-padding          = 6;
      scroll-page-aware     = true;
      scroll-step           = 80;
      smooth-scroll         = true;
      selection-clipboard   = "clipboard";
      database              = "sqlite";   # remembers page + zoom per file
      render-loading        = false;      # no opaque "Loading..." card

      # ── Grounds ───────────────────────────────────────────────────────────
      default-bg   = ground "0.80";   # the desk around the page
      default-fg   = t.fg;
      statusbar-bg = raised "0.72";
      statusbar-fg = t.fishPrimary;
      inputbar-bg  = raised "0.92";   # sits over the page, needs more body
      inputbar-fg  = t.fg;

      completion-bg           = raised "0.94";
      completion-fg           = t.fishPrimary;
      completion-group-bg     = raised "0.94";
      completion-group-fg     = blue;
      completion-highlight-bg = t.selection;
      completion-highlight-fg = t.fg;

      # The index (Tab) is a full-window overlay, so it takes the ground
      # rather than the raised surface — a raised fill there would read as a
      # second window stacked on the first.
      index-bg        = ground "0.86";
      index-fg        = t.fishPrimary;
      index-active-bg = t.selection;
      index-active-fg = t.fg;

      notification-bg         = raised "0.94";
      notification-fg         = t.fg;
      notification-warning-bg = raised "0.94";
      notification-warning-fg = yellow;
      notification-error-bg   = raised "0.94";
      notification-error-fg   = red;

      # ── Page ──────────────────────────────────────────────────────────────
      recolor               = true;
      recolor-keephue       = false;
      recolor-reverse-video = true;   # images render as authored
      recolor-darkcolor     = t.fg;   # ink
      recolor-lightcolor    = ground "0.68";   # paper

      # Search hits and links. Alpha matters here — these are painted over the
      # page, so an opaque fill would hide the text it is marking.
      highlight-color        = "rgba(216,190,150,0.35)";   # yellow
      highlight-active-color = "rgba(232,131,122,0.45)";   # red
      render-links           = true;
      link-hadjust           = true;
    };

    mappings = {
      D          = "toggle_page_mode";
      "<C-b>"    = "toggle_statusbar";
      "[fullscreen] <C-r>" = "recolor";
    };
  };
}
