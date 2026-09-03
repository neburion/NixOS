{ ... }:

# What neburion has. Presets where a whole set is wanted, single modules where
# it is one thing.
#
# Nothing here reaches into a desktop: the file manager, image viewer, video
# player, PDF reader, clipboard and notification daemon all live inside
# desktop/glass/components/, because they exist to fill gaps Hyprland leaves.
# Swap the desktop and they go with it.

{
  home-manager.users.neburion.imports = [
    ../../modules/home/base.nix

    # ── terminal ────────────────────────────────────────────────────────────
    ../../modules/home/cli/shell/fish
    ../../modules/home/cli/btop.nix
    ../../modules/home/cli/compression.nix
    ../../modules/home/cli/fastfetch.nix
    ../../modules/home/cli/flatpak
    ../../modules/home/cli/superfile.nix
    ../../modules/home/cli/tree.nix
    ../../modules/home/cli/xxd.nix

    ../../modules/tools/presets/fleet.nix

    # ── everything else, by preset ──────────────────────────────────────────
    ../../modules/home/presets/dev.nix
    ../../modules/home/presets/office.nix
    ../../modules/home/presets/comms.nix
    ../../modules/home/presets/art.nix
    ../../modules/home/presets/gaming.nix
    ../../modules/home/presets/peripherals.nix

    # ── one of a kind ───────────────────────────────────────────────────────
    ../../modules/home/browser/zen-browser.nix
    ../../modules/home/music/spotify.nix
    ../../modules/home/security/keepassxc.nix

    # ── desktop ─────────────────────────────────────────────────────────────
    ../../modules/home/presets/glass.nix
  ];
}
