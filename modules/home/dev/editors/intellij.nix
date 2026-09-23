{ pkgs, ... }:

# `jetbrains.idea`, not `jetbrains.idea-oss`. JetBrains discontinued the
# separate Community edition in 2025 and folded it into one unified build,
# so the source-built OSS package stopped receiving updates in nixpkgs and
# is now flagged insecure (NIXPKGS-2026-2269) — it stalls at 2025.3.4 and
# fails evaluation outright. The unified build is unfree (allowUnfree is
# already on, see `system/core/nix.nix`); its free tier covers what the
# Community edition did.

{
  home.packages = [
    pkgs.jetbrains.idea
  ];
}
