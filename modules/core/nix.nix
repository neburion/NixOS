{ ... }:

{
  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [ "flakes" "nix-command" ];
  nix.settings.auto-optimise-store = true;
  nix.settings.max-jobs = "auto";
  nix.settings.cores   = 0;
  nix.gc = {
    automatic = true;
    dates     = "weekly";
    options   = "--delete-older-than 14d";
  };

  # Initial nixos version on install — do not change.
  system.stateVersion = "25.11";
}
