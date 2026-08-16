{ pkgs, ... }:

# shadPS4 — PS4 emulator. Early in development and moving fast (26.05
# pins 0.13.0 while unstable is already on 0.17.0), so it's pulled from
# the `unstable` overlay rather than the release channel. Vulkan-only;
# needs your own dumped firmware and game dumps, nothing is bundled.
#
# The nixpkgs package installs only `bin/shadps4` — no `share/` at all —
# so nothing reaches the app launcher on its own. Upstream *does* ship a
# desktop entry and a scalable icon under `src/dist/`; both are restored
# below rather than invented, so the launcher shows what upstream intends.

let
  # Just the icon, lifted out of the pinned source. Taking it from
  # `shadps4.src` rather than a separate fetchurl means it tracks whatever
  # version the flake lock resolves to — no second hash to keep in sync,
  # and no chance of shipping last release's artwork. runCommand keeps the
  # full source checkout a build-time dep instead of a runtime one.
  shadps4-icon = pkgs.runCommand "shadps4-icon" { } ''
    install -Dm444 ${pkgs.unstable.shadps4.src}/src/dist/net.shadps4.shadPS4.svg \
      "$out/share/icons/hicolor/scalable/apps/net.shadps4.shadPS4.svg"
  '';
in
{
  home.packages = with pkgs; [
    unstable.shadps4
    shadps4-icon
  ];

  # Mirrors upstream src/dist/net.shadps4.shadPS4.desktop, keeping its
  # reverse-DNS ID so the icon and StartupWMClass resolve the same way
  # they would on any other distro.
  xdg.desktopEntries."net.shadps4.shadPS4" = {
    name       = "shadPS4";
    comment    = "PlayStation 4 emulator";
    exec       = "${pkgs.unstable.shadps4}/bin/shadps4";
    icon       = "net.shadps4.shadPS4";
    terminal   = false;
    type       = "Application";
    categories = [ "Game" "Emulator" ];
    settings.StartupWMClass = "shadps4";
  };
}
