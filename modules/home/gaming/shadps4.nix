{ pkgs, ... }:

# shadPS4 — PS4 emulator. Early in development and moving fast (26.05
# pins 0.13.0 while unstable is already on 0.17.0), so it's pulled from
# the `unstable` overlay rather than the release channel. Vulkan-only;
# needs your own dumped firmware and game dumps, nothing is bundled.

{
  home.packages = with pkgs; [
    unstable.shadps4
  ];
}
