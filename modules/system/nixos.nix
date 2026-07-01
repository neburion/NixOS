{ inputs, ... }:

{
  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [ "flakes" "nix-command" ];
  nix.settings.auto-optimise-store = true;
  nix.settings.max-jobs = "auto";
  nix.settings.cores   = 0;
  # Pin the system `nixpkgs` channel to the flake's locked input so
  # imperative `nix-shell -p ...` matches what the flake builds against.
  nix.nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
  nix.gc = {
    automatic = true;
    dates     = "weekly";
    options   = "--delete-older-than 14d";
  };

  # Initial nixos version on install — do not change.
  system.stateVersion = "25.11";
}
