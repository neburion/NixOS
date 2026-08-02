{ ... }:

# Ignore lid closure when an external monitor is connected (docked mode).
# The compositor handles disabling the internal panel via a lid-switch bind.
# When no externals are present, default behavior (suspend) applies.

{
  services.logind.settings.Login = {
    HandleLidSwitchDocked = "ignore";
  };
}
