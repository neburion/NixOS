{ pkgs, ... }:

# `update` — bump flake.lock in the local checkout and test-rebuild against it.

{
  home.packages = [
    (pkgs.writeShellApplication {
      name = "update";
      runtimeInputs = with pkgs; [ nix nixos-rebuild nettools ];
      text = ''
        sudo -Sv
        # Local operation: bumps flake.lock in the checkout. You commit +
        # push the new lock, then `rebuild` on any host picks it up from
        # the cloud. This wrapper also does a local `test` rebuild so you
        # can verify the update doesn't break anything before pushing.
        sudo nix flake update --flake "$HOME/NixOS"
        echo "▸ flake.lock updated. Testing locally before you commit + push..."
        sudo nixos-rebuild test --flake "path:$HOME/NixOS#$(hostname -s)" "$@"
        echo ""
        echo "▸ If test looks good: git -C ~/NixOS add flake.lock && git commit + push"
      '';
    })
  ];
}
