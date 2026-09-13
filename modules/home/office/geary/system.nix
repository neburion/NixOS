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
# Lives here and not in system/session/ by the Orphan Rule: delete Geary and
# nothing on this machine wants a Secret Service.

{
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.sddm.enableGnomeKeyring = true;
}
