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

    # Positions are packed left to right by EFFECTIVE width — the rotated
    # width for a monitor declared with transform 3, not its mode width.
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
    # Keeping these in step with the state dir is not optional. On 2026-09-02
    # HDMI-A-1 was rotated to landscape at runtime, which persisted to the
    # state dir but not here, and every rebuild then played the disagreement
    # out in full: the reload rotated it back to portrait and pulled eDP-1
    # left to 2520, the watcher rotated it to landscape again and pushed
    # eDP-1 back to 3640. Two modesets on two outputs, and anything fullscreen
    # got resized underneath it twice. If you rotate an output and mean it,
    # update the transform AND repack every position to its right.
    #
    #   DP-1      transform 3 -> 1080 wide ->    0 ..1080
    #   HDMI-A-1  transform 0 -> 2560 wide -> 1080 ..3640
    #   eDP-1     transform 0 -> 1920 wide -> 3640 ..5560
    monitors = {
      builtin = {
        name     = "eDP-1";
        mode     = "1920x1080@144";
        position = "3640x0";
        scale    = "1";
      };
      external = {
        name      = "HDMI-A-1";
        mode      = "2560x1440@144";
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
