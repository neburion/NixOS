{ pkgs, ... }:

{
  # Shrine autologins on TTY1 — it is the only way in
  services.getty.autologinUser = "shrine";

  # Each graphical user gets their own VT so Hyprland has a real logind seat.
  # machinectl shell creates pts sessions which have no seat assignment, causing
  # Hyprland's DRM backend to fail. A VT session gets seat0 when active.
  # fish loginShellInit fires `exec Hyprland` on any /dev/tty*.
  systemd.services."getty@tty2" = {
    overrideStrategy = "asDropin";
    serviceConfig.ExecStart = [
      ""
      "${pkgs.util-linux}/bin/agetty --autologin neburion --noclear %I $TERM"
    ];
  };
  systemd.services."getty@tty3" = {
    overrideStrategy = "asDropin";
    serviceConfig.ExecStart = [
      ""
      "${pkgs.util-linux}/bin/agetty --autologin qellyree --noclear %I $TERM"
    ];
  };
  systemd.services."getty@tty4" = {
    overrideStrategy = "asDropin";
    serviceConfig.ExecStart = [
      ""
      "${pkgs.util-linux}/bin/agetty --autologin nululy --noclear %I $TERM"
    ];
  };

  # Shrine switches to a user's VT — chvt transfers seat0 to that VT,
  # so Hyprland's logind seat open succeeds.
  security.sudo.extraConfig = ''
    shrine ALL=(root) NOPASSWD: /run/current-system/sw/bin/machinectl
    shrine ALL=(root) NOPASSWD: /run/current-system/sw/bin/chvt
  '';
}
