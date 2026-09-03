{ ... }:

# Documents and mail. Two editors, a suite, and both mail clients — aerc is the
# TUI, thunderbird the GUI, and they read the same accounts.

{
  imports = [
    ../office/aerc.nix
    ../office/libre-office.nix
    ../office/obsidian.nix
    ../office/thunderbird.nix
  ];
}
