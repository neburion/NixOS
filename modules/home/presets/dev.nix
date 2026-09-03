{ ... }:

# The whole development set.
#
# A preset rather than a default.nix because dev/ is divisible: you might want
# only IntelliJ and Java, or only nvim and C. Take the folders you want instead
# of this file when that is the case.

{
  imports = [
    ../dev/languages/c-cpp
    ../dev/languages/java
    ../dev/languages/nix
    ../dev/languages/python
    ../dev/editors/neovim
    ../dev/editors/intellij.nix
    ../dev/engines/godot.nix
    ../dev/tools/claude-code.nix
    ../dev/tools/direnv.nix
    ../dev/tools/git.nix
    ../dev/tools/tokei.nix
  ];
}
