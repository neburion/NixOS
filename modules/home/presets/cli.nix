{ ... }:

# The terminal set a workstation gets. A server takes the individual files it
# wants instead — that is why this is a preset and cli/ is a folder.

{
  imports = [
    ../cli/shell/fish
    ../cli/shell/bash
    ../cli/btop.nix
    ../cli/compression.nix
    ../cli/fastfetch.nix
    ../cli/superfile.nix
    ../cli/tree.nix
    ../cli/xxd.nix
  ];
}
