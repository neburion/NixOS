{ inputs, ... }:

{
  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [ "flakes" "nix-command" ];
  nix.settings.auto-optimise-store = true;
  nix.settings.max-jobs = "auto";
  nix.settings.cores   = 0;
  # Wheel users can nix-copy-closure to this host without signature verification,
  # which is required for `rebuild <host>` remote deploys (nixos-rebuild --target-host
  # ships store paths signed only by the deploying host's key).
  nix.settings.trusted-users = [ "root" "@wheel" ];
  # Pin the system `nixpkgs` channel to the flake's locked input so
  # imperative `nix-shell -p ...` matches what the flake builds against.
  nix.nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
  nix.gc = {
    automatic = true;
    dates     = "weekly";
    options   = "--delete-older-than 14d";
  };

  programs.nix-ld.enable = true;

  # Initial nixos version on install — do not change.
  system.stateVersion = "25.11";
}
