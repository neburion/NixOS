{ ... }:

# Every program neburion has, named. The genre bundles this list used to
# delegate to — modules/home/dev, /gaming, /art — are gone: they decided what
# was installed from three directories away, and dropping one line silently
# dropped whatever it happened to contain.

{
  home-manager.users.neburion.imports = [
    ../../modules/home/base.nix

    # ── terminal ────────────────────────────────────────────────────────────
    ../../modules/home/cli/btop.nix
    ../../modules/home/cli/claude-code.nix
    ../../modules/home/cli/compression.nix
    ../../modules/home/cli/fastfetch.nix
    ../../modules/home/cli/fish.nix
    ../../modules/home/cli/flatpak.nix
    ../../modules/home/cli/fonts.nix
    ../../modules/home/cli/neovim
    ../../modules/home/cli/superfile.nix
    ../../modules/home/cli/tree.nix
    ../../modules/home/cli/xxd.nix
    ../../modules/home/cli/zathura.nix

    ../../modules/tools/presets/fleet.nix

    ../../modules/home/dev

    # ── desktop ─────────────────────────────────────────────────────────────
    ../../modules/home/desktop/glass

    # ── graphical programs ──────────────────────────────────────────────────
    ../../modules/home/apps/aerc.nix
    ../../modules/home/apps/aseprite.nix
    ../../modules/home/apps/bb-launcher
    ../../modules/home/apps/blender.nix
    ../../modules/home/apps/celluloid.nix
    ../../modules/home/apps/heroic.nix
    ../../modules/home/apps/keepassxc.nix
    ../../modules/home/apps/libnotify.nix
    ../../modules/home/apps/libre-office.nix
    ../../modules/home/apps/loupe.nix
    ../../modules/home/apps/nautilus.nix
    ../../modules/home/apps/obsidian.nix
    ../../modules/home/apps/osu.nix
    ../../modules/home/apps/pavucontrol.nix
    ../../modules/home/apps/prism-launcher.nix
    ../../modules/home/apps/razer-genie.nix
    ../../modules/home/apps/shadps4.nix
    ../../modules/home/apps/signal.nix
    ../../modules/home/apps/sober.nix
    ../../modules/home/apps/solaar.nix
    ../../modules/home/apps/spotify.nix
    ../../modules/home/apps/thunderbird.nix
    ../../modules/home/apps/vesktop.nix
    ../../modules/home/apps/wl-clipboard.nix
    ../../modules/home/apps/zen-browser.nix
  ];
}
