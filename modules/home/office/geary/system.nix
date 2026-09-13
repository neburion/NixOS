{ ... }:

# Geary's system half: a Secret Service for it to put the Posteo password in.
#
# Geary stores credentials through libsecret and does not offer a way not to —
# with no org.freedesktop.secrets on the bus it cannot save the password at
# all, and asks again on every launch. Thunderbird never needed this because it
# carries its own password store, which is why this host ran without a keyring
# until now.
#
# gnome-keyring rather than KeePassXC's Secret Service integration: KeePassXC
# can serve that API, but only while it is running with the database unlocked,
# which makes "can Geary start" depend on an unrelated window being open. The
# login keyring is unlocked by PAM with the password already typed at SDDM, so
# it is simply there.
#
# The PAM half needs no line here, which is worth stating because the obvious
# line is a no-op: this module already sets
# `security.pam.services.login.enableGnomeKeyring`, and /etc/pam.d/sddm is
# nothing but `auth substack login` and friends, so SDDM inherits the unlock.
# Adding `security.pam.services.sddm.enableGnomeKeyring` renders nothing and
# claims credit for what login was already doing.
#
# The trap, hit the first time Geary ran (2026-09-13): an empty `login.keyring`
# dated March was already sitting in ~/.local/share/keyrings, left by something
# that asked for a secret store back when nothing served one. PAM unlocks that
# file with the login password, the file did not have the login password, and
# Geary got "the login keyring did not get unlocked when you logged into your
# computer" — which reads like this module is broken and is not. The fix is to
# delete the stale pair and let one be created with the login password:
#
#   rm ~/.local/share/keyrings/login.keyring ~/.local/share/keyrings/user.keystore
#   printf '%s' "$LOGIN_PASSWORD" | gnome-keyring-daemon --daemonize --unlock --components=secrets
#
# Not automated: a keyring is user data, and a rebuild that silently deletes
# credentials is a worse failure than a dialog.
#
# Lives here and not in system/session/ by the Orphan Rule: delete Geary and
# nothing on this machine wants a Secret Service.

{
  services.gnome.gnome-keyring.enable = true;
}
