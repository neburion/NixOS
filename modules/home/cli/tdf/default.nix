{ pkgs, lib, themes, ... }:

let
  t = themes.glass;

  # Two things upstream does that this preset needs undone.
  #
  # It renders every page opaque — `to_pixmap(.., alpha = false, ..)` fills the
  # sheet before drawing, and the pixmap travels to the terminal as PNM, a
  # format with no alpha channel — so the page lands as a solid rectangle on
  # top of the terminal's own translucent ground. The css colour parser does
  # accept `rgba(.., 0)`, but the value is kept as an i32 RGB triple and the
  # alpha is dropped without a word.
  #
  # And its recolour is a flat tint: every pixel interpolated between two
  # endpoints, images included, which is what turns photos negative.
  #
  # The patch renders with an alpha channel, carries the pixmap as PAM (same
  # PNM family, but with alpha), and replaces the tint with the same rule
  # zathura's reverse-video uses: pixels carrying real chroma are left as the
  # document authored them, grey pixels are redrawn as ink with an alpha taken
  # from how dark they were. Paper goes fully transparent, photos come through
  # untouched, and the ink itself is drawn opaque — its antialiasing blended
  # here, in sRGB, against the colour the terminal is about to draw. Handing
  # that antialiasing over as partial alpha instead is what made the first
  # attempt read thin and grey: the terminal composites it in its own colour
  # space, and small text is mostly antialiasing.
  #
  # So the page is not painted to resemble the terminal — there is no page
  # ground at all, and what you read on is ghostty's own background, blur and
  # wallpaper included. kittage already maps RGBA8 onto the Kitty protocol's
  # f=32, so nothing below the renderer needed touching, and Cargo.lock is
  # untouched, so cargoHash stays valid.
  tdf = pkgs.tdf.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./transparent-pages.patch ];
  });

  # -b is the ink; -w is the ground the ink's antialiasing is blended against,
  # so it must be ghostty's own background colour or every glyph would carry a
  # halo of the wrong shade. Passing either flag is also what selects the
  # reverse-video path over upstream's tint. `i` still toggles the plain
  # inversion at runtime, for a document that renders wrong.
  hex = lib.removePrefix "#";
in

# tdf — a PDF viewer that draws inside the terminal it was run from, using the
# Kitty graphics protocol, which ghostty implements.
#
# It does not replace zathura, it sits beside it: zathura when a document wants
# a window of its own — links, marks, bookmarks, a table of contents — and tdf
# when you want the page in the pane you are already in. Both now recolour by
# the same rule, so a document looks the same in either.
{
  home.packages = [
    (pkgs.writeShellScriptBin "tdf" ''
      exec ${lib.getExe tdf} -w "${hex t.bg}" -b "${hex t.fg}" "$@"
    '')
  ];
}
