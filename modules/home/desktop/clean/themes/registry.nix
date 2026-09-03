{ lib, ... }:

# Internal registry — consumers contribute their own reaction to a theme
# change via `themeHooks.<name>`. The theme-switcher module reads the
# attrset at build time and bakes each hook's store path into the
# generated `theme-set` script (no runtime directory scan).
#
# Not a user-facing knob — same latitude the environment layer gets.

{
  options.themeHooks = lib.mkOption {
    type    = lib.types.attrsOf lib.types.package;
    default = {};
    description = ''
      Per-consumer theme-change hooks. Each entry is a shell script package
      (produced by pkgs.writeShellScript "theme-hook-<name>" "..."). The
      switcher invokes each hook with `"$hook" "<theme-name>"` when
      `theme-set <name>` runs.
    '';
  };
}
