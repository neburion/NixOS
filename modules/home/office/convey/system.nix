{ ... }:

# Convey's system half: a Secret Service, because libsecret is a hard
# requirement of Geary's codebase and the fork did not drop it.
#
# The sandbox does not get you out of it. Convey's Flathub manifest grants no
# `--talk-name=org.freedesktop.secrets`, so libsecret inside the sandbox falls
# back to `org.freedesktop.portal.Secret`: the portal issues Convey a per-app
# key and Convey encrypts its own credential file with that. The key still has
# to live on the host, and gnome-keyring is what ships
# `org.freedesktop.impl.portal.Secret` — visible as `gnome-keyring.portal` in
# /run/current-system/sw/share/xdg-desktop-portal/portals, routed by the
# `default=*` in portals.conf. So the keyring stays; what the sandbox buys is
# isolation, since Convey can no longer read Chromium's secrets or the reverse.
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
# Lives here and not in system/session/ by the Orphan Rule: delete Convey and
# nothing on this machine wants a Secret Service.

{
  services.gnome.gnome-keyring.enable = true;
}
