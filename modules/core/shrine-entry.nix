{ ... }:

{
  # Shrine autologins on TTY1 — it is the only way in
  services.getty.autologinUser = "shrine";

  # Shrine is the hub — it can hand off to any user without a password.
  # machinectl shell creates a proper systemd/PAM login session (sets XDG_RUNTIME_DIR,
  # registers the seat, etc.) which su/sudo alone do not provide.
  security.sudo.extraConfig = ''
    shrine ALL=(root) NOPASSWD: /run/current-system/sw/bin/machinectl
  '';
}
