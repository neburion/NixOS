{ pkgs, ... }:

# The NixOS half: hand the Nari dongle's hidraw node to whoever is logged in.
#
# hidraw nodes are created root-only. hardware.logitech.wireless installs an
# equivalent rule for its own receivers, which is why solaar works without a
# group anywhere in this tree, and nari-battery needs the same courtesy — it
# opens the node O_RDWR, because reading the battery means writing the query
# into a feature report first.
#
# TAG+="uaccess" rather than a group: logind puts an ACL on the node for the
# active seat and takes it away again at logout, so the permission follows the
# session instead of outliving it.
#
# Shipped as a udev package and NOT through services.udev.extraRules, which is
# the whole reason this file is longer than one line. extraRules lands in
# 99-local.rules, and the builtin that turns the tag into an ACL is invoked by
# 73-seat-late.rules — so a tag set at 99 is set after the only thing that
# reads it, and the node stays root-only with no error anywhere to say why.
# Solaar ships its own rule at 42 for the same reason.

{
  services.udev.packages = [
    (pkgs.writeTextFile {
      name = "razer-nari-udev-rules";
      destination = "/lib/udev/rules.d/60-razer-nari.rules";
      text = ''
        # 051E is the dongle, which stays plugged in. 051F is the headset
        # itself, which only appears while it is on the charging cable.
        SUBSYSTEM=="hidraw", ATTRS{idVendor}=="1532", ATTRS{idProduct}=="051e", TAG+="uaccess"
        SUBSYSTEM=="hidraw", ATTRS{idVendor}=="1532", ATTRS{idProduct}=="051f", TAG+="uaccess"
      '';
    })
  ];
}
