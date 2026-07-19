{ pkgs, ... }:

# Portable bash entry points for the common NixOS rebuild workflow.
# Formerly fish aliases in cli/shell/fish.nix — moved out so they work
# from any shell (bash, zsh, sh -c, cron, systemd units, etc.).
#
# Each script:
#   - resolves the host with `hostname -s`
#   - flakes against $HOME/NixOS (never a github: URL — see .gitignore
#     and the hardware-configuration.nix policy)
#   - passes extra args through to nixos-rebuild / nix flake update

let
  rebuild = pkgs.writeShellApplication {
    name = "rebuild";
    runtimeInputs = with pkgs; [ nixos-rebuild nettools ];
    text = ''
      sudo nixos-rebuild switch --flake "path:$HOME/NixOS#$(hostname -s)" "$@"
    '';
  };

  trebuild = pkgs.writeShellApplication {
    name = "trebuild";
    runtimeInputs = with pkgs; [ nixos-rebuild nettools ];
    text = ''
      sudo nixos-rebuild test --flake "path:$HOME/NixOS#$(hostname -s)" "$@"
    '';
  };

  update = pkgs.writeShellApplication {
    name = "update";
    runtimeInputs = with pkgs; [ nix nixos-rebuild nettools ];
    text = ''
      sudo nix flake update --flake "$HOME/NixOS"
      sudo nixos-rebuild switch --flake "path:$HOME/NixOS#$(hostname -s)" "$@"
    '';
  };
in
{
  home.packages = [ rebuild trebuild update ];
}
