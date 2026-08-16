{ pkgs, ... }:

# shadPS4 — PS4 emulator. Early in development and moving fast (26.05
# pins 0.13.0 while unstable is already on 0.17.0), so both halves come
# from the `unstable` overlay rather than the release channel.
#
# Two packages, because upstream split them. As of 0.12.5 the emulator
# dropped Qt entirely ("Remove Qt from emulator - Using launchers from
# now on"); `shadps4` is now a pure CLI binary that, run with no
# arguments, pops a message box telling you to go get the launcher. The
# GUI lives in its own repo, packaged as `shadps4-qtlauncher`, and it is
# what ships the .desktop entry and icon — which is why the emulator
# alone never reached the app launcher. The launcher finds the emulator
# on PATH, so both belong in the same profile.
#
# Vulkan-only; needs your own dumped firmware and game dumps, nothing is
# bundled. Firmware modules are optional — most PS4 system libraries are
# reimplemented in HLE, with sys_modules/ only improving compatibility.

{
  home.packages = with pkgs; [
    unstable.shadps4
    unstable.shadps4-qtlauncher
  ];
}
