{ ... }:

# Auto-login on tty1 as home-admin. For headless boxes where the only
# reason someone opens the lid is to diagnose an incident — skip the
# password prompt so `journalctl`/`ip a`/etc. are one keystroke away.
# Sudo still needs a password, so blast radius on physical access
# equals a non-root shell.

{
  services.getty.autologinUser = "home-admin";
}
