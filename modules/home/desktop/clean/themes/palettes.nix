# The palettes clean can switch between. Pure data — no config, no options.
#
# This was modules/home/themes/, a top-level tree injected into *every*
# home-manager module by flake.nix as `_module.args.themes`. Thirteen modules
# took it, four of them under cli/, which meant a headless server was wired to
# a desktop's colour scheme in order to render a PDF or draw a shell prompt.
#
# A desktop owns its palettes. glass has one, literal, in
# desktop/glass/palette.nix; clean has these five and a switcher. Nothing
# outside a desktop has a palette at all (DESIGN.md L8), and the CLI programs
# carry their own colours because they have to work where there is no desktop
# to ask.
#
# The `glass` entry that used to live here is gone with the injection. It was
# a palette for the one preset documented as having no themes, and existed
# solely so the CLI tools had something to resolve to.

{
  catppuccin = import ./catppuccin.nix;
  dark       = import ./dark.nix;
  everforest = import ./everforest.nix;
  gruvbox    = import ./gruvbox.nix;
  nord       = import ./nord.nix;
}
