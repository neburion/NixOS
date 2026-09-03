{ modulesPath, ... }:

# installer — the live USB. A host like the other three, and it lives here for
# that reason; it used to sit at the repo root as iso/ purely because it looks
# different, which is not a filing principle.
#
# Two things do make it different, and both are worth knowing before editing:
#
#   - You build a different attribute. `.config.system.build.isoImage`, not
#     `.toplevel`. `nixflash` wraps that build plus the dd.
#   - It deliberately bypasses mkSystem, so it has no specialArgs, no
#     home-manager and no overlays — which means it cannot import most of
#     modules/system/, all of which assume `inputs`.
#
# Everything else it needs is therefore self-contained in
# modules/tools/installer/.
#
# The wifi module is the exception, and it is safe: it takes no arguments and
# only sets networking.networkmanager.ensureProfiles, and the upstream
# installation-device profile already enables NetworkManager — so there is no
# wpa_supplicant to fight with. The point is that a fresh boot of this stick is
# already on the network, instead of starting with nmtui.

{
  imports = [
    (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix")
    ../../modules/tools/installer
    ../../modules/system/network/wifi/bell096.nix
  ];
}
