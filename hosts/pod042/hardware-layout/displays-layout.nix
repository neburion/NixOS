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
    #   DP-1      transform 3 -> 1080 wide ->    0 ..1080
    #   HDMI-A-1  transform 3 -> 1440 wide -> 1080 ..2520
    #   eDP-1     transform 0 -> 1920 wide -> 2520 ..4440
    monitors = {
      builtin = {
        name     = "eDP-1";
        mode     = "1920x1080@144";
        position = "2520x0";
        scale    = "1";
      };
      external = {
        name      = "HDMI-A-1";
        mode      = "2560x1440@144";
        position  = "1080x0";
        scale     = "1";
        transform = 3;
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
