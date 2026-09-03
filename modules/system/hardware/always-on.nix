{ ... }:

# Keeps the host powered on: ignores laptop lid closure, disables every
# sleep/suspend target. For machines that must stay reachable 24/7
# (print servers, headless boxes, kiosks).

{
  services.logind.settings.Login = {
    HandleLidSwitch              = "ignore";
    HandleLidSwitchDocked        = "ignore";
    HandleLidSwitchExternalPower = "ignore";
  };

  systemd.targets.sleep.enable        = false;
  systemd.targets.suspend.enable      = false;
  systemd.targets.hibernate.enable    = false;
  systemd.targets.hybrid-sleep.enable = false;
}
