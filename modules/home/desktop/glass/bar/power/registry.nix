{ lib, ... }:

# The source registry. Adding a battery to the dial is one file under
# sources/ and one import line in default.nix — nothing in the dial, the
# menu or the widget is touched, and no source knows another exists.
#
# `reading` is a QML expression, not a value, because every source reads its
# own hardware on its own clock and the widget only ever wants the answer.
# It is evaluated inside Modules/BarPower.qml, so it can name any singleton in
# Services/ and `root.accent` for the wallpaper hue.
#
# It must produce an object:
#
#   ({
#       label:   "Laptop",                  what the menu calls it
#       present: LaptopBattery.present,     false hides its ring entirely
#       value:   LaptopBattery.capacity,    0-100
#       caption: "Charging",                optional, the line under the label
#       color:   PowerProfile.tint,         optional, defaults to the accent
#       burning: PowerProfile.burning       optional, sets the dial alight
#   })
#
# Not typed beyond `lines`, because the alternative is a Nix schema that
# describes QML expressions it cannot check. A malformed source shows up as a
# missing ring, and the reading sits in one file with its own service.

{
  options.quickshell.powerSources = lib.mkOption {
    default = {};
    description = ''
      Battery sources contributed to the power dial, keyed by name.
      Written to Modules/BarPower.qml in `order`, outermost ring first.
    '';
    type = lib.types.attrsOf (lib.types.submodule {
      options = {
        order = lib.mkOption {
          type    = lib.types.int;
          default = 50;
          description = ''
            Ring position, low numbers outermost. The machine's own cell
            should outrank anything plugged into it.
          '';
        };

        reading = lib.mkOption {
          type = lib.types.lines;
          description = ''
            A QML expression producing this source's reading. See the header
            of registry.nix for the shape it must have.
          '';
        };

        refresh = lib.mkOption {
          type    = lib.types.lines;
          default = "";
          description = ''
            Optional QML statement run when the menu opens. Sources with a
            cheap poll can leave this empty and let their own timer carry it.
          '';
        };
      };
    });
  };
}
