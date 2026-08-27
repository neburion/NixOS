{ pkgs, lib, themes, ... }:

let
  t = themes.glass;

  # "#101113" -> "16, 17, 19", which is the form tdf's css colour parser wants.
  rgbOf = c: lib.concatMapStringsSep ", " (i:
    toString (lib.fromHexString (builtins.substring i 2 c))
  ) [ 1 3 5 ];

  # tdf recolours the whole page pixmap by interpolating between one "white"
  # and one "black" colour, so the paper can be made transparent outright:
  # alpha 0 means the page contributes no ground of its own and ghostty's
  # translucent one (background-opacity 0.92, plus Hyprland's window blur) is
  # what you read on. That is what makes this follow the terminal rather than
  # merely match it — change the terminal's opacity and the page follows.
  #
  # The trade-off, and it is not fixable in a terminal viewer: the same
  # interpolation runs over images, so photos and colour figures come out
  # washed or negative. tdf has no equivalent of zathura's reverse-video,
  # which is the one real thing separating the two viewers. `i` toggles the
  # recolour off at runtime and restores true colour for an image-heavy page;
  # for a document that is mostly figures, reach for zathura instead
  # (modules/home/cli/zathura.nix) — it keeps the dark page *and* the images.
  #
  # A wrapper script rather than makeWrapper --add-flags: the flag value
  # contains parentheses and spaces, and the generated wrapper would splice it
  # in unquoted.
  tdf-glass = pkgs.writeShellScriptBin "tdf" ''
    exec ${lib.getExe pkgs.tdf} \
      -w "rgba(${rgbOf t.bg}, 0)" \
      -b "${lib.removePrefix "#" t.fg}" \
      "$@"
  '';
in

# tdf — a PDF viewer that draws inside the terminal it was run from, using the
# Kitty graphics protocol, which ghostty implements.
#
# It does not replace zathura, it sits beside it: zathura for a document full
# of figures, tdf when you want the page in the pane you are already in.
{
  home.packages = [ tdf-glass ];
}
