{ pkgs, lib, ... }:

let
  # Its own colours, literal. This module used to read the repo-wide `themes`
  # attrset injected by flake.nix and pick `themes.glass` out of it — a
  # terminal program reaching into a desktop's palette from four trees away,
  # which is what DESIGN.md L8 is about. It also meant a headless server
  # imported a desktop's colour scheme to render a PDF.
  #
  # These match desktop/glass/palette.nix. They are a copy, and if that palette
  # moves this does not follow — which is the honest trade for not having a
  # repo-wide theme, and is exactly the coupling that let nvim sit on gruvbox
  # for months while the desktop had changed.
  t = {
    bg            = "#101113";
    surface       = "#191B1E";
    selection     = "#26282C";
    fg            = "#E8EAEC";
    fishPrimary   = "#C8CBCF";
    fishSecondary = "#6E737A";
  };

  # The grounds above are hex; zathura needs alpha on the ones that should let
  # the compositor through, so those are restated as rgba() literals of the
  # same values:
  #   bg #101113 -> 16,17,19   surface #191B1E -> 25,27,30
  ground  = a: "rgba(16,17,19,${a})";
  raised  = a: "rgba(25,27,30,${a})";

  # ghostty-glass ANSI accents, restated here for the same reason superfile.nix
  # restates them: the shared attrset only carries ground/text colours.
  desktop = "org.pwmt.zathura-pdf-mupdf.desktop";

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

  # The handler for anything that opens a PDF by mimetype — Nautilus, a
  # browser download, an attachment in Thunderbird.
  #
  # The desktop file is the *plugin's* rather than `org.pwmt.zathura.desktop`,
  # because that is the one declaring `application/pdf` in its MimeType; the
  # plain entry declares no types at all. Its `NoDisplay=true` keeps it out of
  # application menus but does not stop it resolving as a default.
  #
  # Written by activation rather than `xdg.mimeApps.defaultApplications`,
  # which would need `xdg.mimeApps.enable` and so hand the whole of
  # ~/.config/mimeapps.list to home-manager as a read-only symlink. That file
  # is not ours alone: Thunderbird registers itself for mailto there, vesktop
  # for x-scheme-handler/discord, claude-code for claude-cli, all at runtime.
  # Taking it over means every one of those has to be declared here or be
  # lost, and any future one silently fails to stick.
  #
  # (Which also means the `xdg.mimeApps.defaultApplications` blocks in
  # ../desktop/utils/loupe.nix and ../desktop/utils/nautilus.nix currently do
  # nothing at all — the option is set, the module that writes it is not
  # enabled.)
  #
  # Guarded on the current value so it does not rewrite the file on every
  # activation, and so a deliberate change to another viewer stays changed
  # until this module is rebuilt.
  home.activation.zathuraPdfDefault = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ "$(${pkgs.xdg-utils}/bin/xdg-mime query default application/pdf)" != "${desktop}" ]; then
      ${pkgs.xdg-utils}/bin/xdg-mime default "${desktop}" application/pdf
    fi
  '';
}
