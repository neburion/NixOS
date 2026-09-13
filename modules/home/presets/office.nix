{ ... }:

# Documents and mail. Two editors, a suite, and both mail clients — Geary is
# the one mail gets read in, Thunderbird the one with every knob, and they read
# the same accounts.

{
  imports = [
    ../office/geary
    ../office/libre-office.nix
    ../office/obsidian.nix
    ../office/thunderbird.nix
  ];
}
