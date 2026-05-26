{ ... }:

{
  # Shrine autologins on TTY1 — it is the only way in
  services.getty.autologinUser = "shrine";

  # Shrine is the hub — it can hand off to any user without a password.
  # su skips the target user's password when called as root;
  # this rule lets shrine invoke sudo su with any args without being asked for its own.
  security.sudo.extraConfig = ''
    shrine ALL=(root) NOPASSWD: /run/wrappers/bin/su
  '';
}
