{ ... }:

# A Secret Service for the session: `~/.local/share/keyrings/login.keyring`,
# one small file, plus a daemon that answers `org.freedesktop.secrets` on the
# session bus. Apps ask the daemon instead of each inventing a password store.
#
# It arrived with Convey, whose libsecret dependency was the original reason,
# and outlived it. Convey was deleted 2026-10-06; the keyring stays, because
# Chromium asks for its `os_crypt` key at every start. `Chromium Safe Storage`
# is in the keyring file, so helium and every Electron app here have their
# saved passwords and cookies sealed with a key that lives in it. Delete this
# module and they silently re-key: logged out everywhere, saved passwords
# unreadable.
#
# The PAM half needs no line here, which is worth stating because the obvious
# line is a no-op: `services.gnome.gnome-keyring.enable` already sets
# `security.pam.services.login.enableGnomeKeyring`, and /etc/pam.d/sddm is
# nothing but `auth substack login` and friends, so SDDM inherits the unlock.
#
# **The login keyring has an empty password, on purpose.** See the Secrets
# section of NOTES.md for the whole argument; the short version is that it is
# the one encrypted file in a home directory on an unencrypted ext4 root, and
# buying that inch of at-rest protection cost a recurring lockout:
# the PAM-started daemon dies mid-session, systemd D-Bus-activates a
# passwordless replacement, and every app that wants a secret gets a dialog.
# An empty-password keyring cannot be locked, so the replacement daemon opens
# it fine and the failure mode does not exist. Do not "fix" this by setting a
# password — you would be re-adding the bug to protect a password sitting
# beside plaintext SSH keys.
#
# Sandboxed apps get nothing from this. gnome-keyring ships
# `org.freedesktop.impl.portal.Secret` as `gnome-keyring.portal`, but
# xdg-desktop-portal never loads it: the file is tagged `UseIn=gnome` while the
# desktop here is Hyprland, so the `default=*` in ./xdg-portal.nix skips it and
# `org.freedesktop.portal.Secret` never appears on the bus. That is what killed
# Convey. A flatpak that needs a Secret Service wants the key named outright —
# `xdg.portal.config.common."org.freedesktop.impl.portal.Secret" =
# "gnome-keyring"` — because the wildcard will not reach it.

{
  services.gnome.gnome-keyring.enable = true;
}
