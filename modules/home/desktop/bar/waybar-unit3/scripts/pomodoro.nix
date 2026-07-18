{ ... }:

{
  xdg.configFile = {
    "waybar/scripts/pomodoro.sh" = {
      source     = ./pomodoro.sh;
      executable = true;
    };
    "waybar/scripts/pomodoro_toggle.sh" = {
      source     = ./pomodoro_toggle.sh;
      executable = true;
    };
  };
}
