{ ... }:

# The power dial: every battery within reach on one gauge, with the machine's
# power profile as the outer ring's colour and the switch for it in the menu.
#
# Indivisible on purpose. The dial without a source draws nothing and a source
# without the dial has nowhere to report, so there is no half of this to take.
#
# Adding a battery is one file under sources/ and one line below. Nothing in
# dial.nix, fire.nix or widget.nix knows how many there are — see
# registry.nix for what a source has to produce.

{
  imports = [
    ./registry.nix
    ./profile.nix
    ./dial.nix
    ./fire.nix
    ./widget.nix

    ./sources/laptop.nix
    ./sources/mouse.nix
    ./sources/headset.nix
  ];
}
