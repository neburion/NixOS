{ ... }:

# Theme switching, which only this preset has. glass is one fixed palette and
# imports none of this — not importing a slot is exactly how a preset opts out.
#
# `themes` used to be a module argument injected by flake.nix into every
# home-manager module in the repo. It is scoped here now: clean's own modules
# (wm/themes.nix, theming/gtk/, terminal.nix, wallpaper/sync.nix, shell/
# themes.nix) still take it, but nothing outside this preset can, because
# nothing outside this preset imports the file that provides it.

{
  imports = [
    ./switch.nix
    ./registry.nix
  ];

  _module.args.themes = import ./palettes.nix;
}
