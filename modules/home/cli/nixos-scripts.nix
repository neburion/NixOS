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
  # `sudo -Sv` reads the password once (from stdin if piped, from the
  # terminal otherwise), primes the timestamp cache, then the actual
  # nixos-rebuild sudo call reuses it without re-prompting. Makes the
  # script usable both interactively (fish prompts you once) and from
  # non-tty contexts (Claude Code Bash tool: `echo <pw> | rebuild`).
  rebuild = pkgs.writeShellApplication {
    name = "rebuild";
    runtimeInputs = with pkgs; [ nixos-rebuild nettools ];
    text = ''
      sudo -Sv
      sudo nixos-rebuild switch --flake "path:$HOME/NixOS#$(hostname -s)" "$@"
    '';
  };

  trebuild = pkgs.writeShellApplication {
    name = "trebuild";
    runtimeInputs = with pkgs; [ nixos-rebuild nettools ];
    text = ''
      sudo -Sv
      sudo nixos-rebuild test --flake "path:$HOME/NixOS#$(hostname -s)" "$@"
    '';
  };

  update = pkgs.writeShellApplication {
    name = "update";
    runtimeInputs = with pkgs; [ nix nixos-rebuild nettools ];
    text = ''
      sudo -Sv
      sudo nix flake update --flake "$HOME/NixOS"
      sudo nixos-rebuild switch --flake "path:$HOME/NixOS#$(hostname -s)" "$@"
    '';
  };
in
{
  home.packages = [ rebuild trebuild update ];
}
