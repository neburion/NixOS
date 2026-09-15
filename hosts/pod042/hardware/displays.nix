{ lib, ... }:

{
  options.displays = {
    primary = lib.mkOption { type = lib.types.attrs; };
    monitors = lib.mkOption { type = lib.types.attrs; };
  };

  config.displays = {
    primary = {
      width  = 1920;
      height = 1080;
    };

    # The mode on each output is its CEILING, not its resting value. It is
    # what an output with no persisted choice runs at, and the highest mode the
    # bar's resolution menu will offer — nothing may sit above it. The running
    # mode lives in ~/.local/state/monitor-modes/<name>, written by
    # set-monitor-mode, and reflow-monitors replays it over these declarations.
    #
    # Positions are packed left to right by EFFECTIVE width — mode width
    # divided by scale, and the rotated axis for a monitor declared with
    # transform 3. Not the mode width. They are computed for the ceiling;
    # the planner repacks live when a runtime mode makes an output narrower,
    # so these numbers describe the layout at full size and nothing else.
    # Declaring the transform matters beyond correctness: every Hyprland
    # config reload re-applies these lines, and a reload used to reset both
    # panels to landscape at landscape-spaced positions, leaving the layout
    # visibly wrong until the socket2 watcher ran restore-monitor-transforms
    # and reflow-monitors behind it. That reshuffle is the "stretching" seen
    # on every rebuild. Declared this way a reload lands on the final layout
    # directly and the watcher has nothing to correct.
    #
    # Rotating at runtime ($mod + backslash, or the bar's toggle) still works
    # and still wins: rotate-monitor persists to
    # ~/.local/state/monitor-transforms/<name> and reflows, and
    # restore-monitor-transforms replays that over these declarations on the
    # next reload. This is the resting orientation, not a lock.
    #
    # Since a runtime mode is now EXPECTED to differ from the declaration
    # rather than being a transient, the disagreement is no longer settled by
    # correcting it after the fact. reflow-monitors writes the layout it
    # computed to ~/.config/hypr/monitors.conf, which hyprland.conf sources
    # after these lines, so a reload lands on the running layout inside the
    # same pass. See wm/monitor-layout.nix.
    #
    # Keeping these in step with the state dir is not optional. On 2026-09-02
    # HDMI-A-1 was rotated to landscape at runtime, which persisted to the
    # state dir but not here, and every rebuild then played the disagreement
    # out in full: the reload rotated it back to portrait and pulled eDP-1
    # left to 2520, the watcher rotated it to landscape again and pushed
    # eDP-1 back to 3640. Two modesets on two outputs, and anything fullscreen
    # got resized underneath it twice. If you rotate an output and mean it,
    # update the transform AND repack every position to its right.
    #
    #   DP-1      transform 3, scale 1   -> 1080 wide ->    0 ..1080
    #   HDMI-A-1  transform 0, scale 1   -> 3840 wide -> 1080 ..4920
    #   eDP-1     transform 0, scale 1   -> 1920 wide -> 4920 ..6840
    #
    # HDMI-A-1 is an MSI G321CU: a 32" panel whose native mode is 3840x2160,
    # which is why the ceiling is what it is. It was driven at 2560x1440 for a
    # long time, which the monitor's own scaler then stretched 1.5x back to
    # native — non-integer interpolation of already-antialiased glyphs, which
    # is what made text look soft everywhere. Driving it natively fixed that.
    #
    # 2560x1440 is therefore not on the bar menu at all: 3840/2560 is 1.5, and
    # there is no arrangement of a 1.5:1 mapping onto a fixed pixel grid that is
    # not interpolated. A smaller desktop is a whole-number SCALE at this mode
    # instead — 1920x1080 at scale 2 is the same apparent size as a 1080p signal
    # with none of the stretching, because the compositor renders into all
    # 3840x2160 real pixels. See wm/resolution.nix.
    #
    # Do NOT lower this line to make a smaller mode the default. It is the
    # ceiling AND the mode every scale divides; lowering it takes the sharp
    # sizes away with it.
    #
    # It then ran at scale 1.5 for a while — native pixels, 2560 logical
    # width — which is where the fuzz came back by another route. Fractional
    # scale is the one thing XWayland cannot follow: Hyprland hands an X11
    # surface a buffer a pixel or two short of the window it is meant to
    # fill, and the remainder shows as a dark seam down the edges. Steam wore
    # it permanently. Every output on this host is scale 1 now, so there is
    # no fractional geometry left for XWayland to round off, and
    # `xwayland:force_zero_scaling` in desktop/glass/wm/looks.nix has nothing
    # to correct.
    #
    # The cost is honest and was accepted: 3840 logical pixels across 32"
    # is ~138 DPI, so everything on this panel is a third smaller than it
    # was. Raising the scale again brings the seam back with it.
    monitors = {
      builtin = {
        name     = "eDP-1";
        mode     = "1920x1080@144";
        position = "4920x0";
        scale    = "1";
      };
      external = {
        name      = "HDMI-A-1";
        mode      = "3840x2160@144";
        position  = "1080x0";
        scale     = "1";
        transform = 0;
      };
      secondary = {
        name      = "DP-1";
        mode      = "1920x1080@60";
        position  = "0x0";
        scale     = "1";
        transform = 3;
      };
    };
  };
}
