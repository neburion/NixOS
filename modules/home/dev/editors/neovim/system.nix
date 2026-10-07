{ ... }:

# The NixOS half of the neovim module. One thing lives here because it cannot
# be set from the home modules beside it.
#
# nixpkgs sets `environment.variables.EDITOR = mkDefault "nano"` in
# programs/environment.nix, which lands in /etc/set-environment and is exported
# by every login shell. home-manager's `home.sessionVariables` cannot win that:
# it is a user-level file sourced by shell init, and the system export is what
# every shell inherits first. So the override has to be a NixOS option.
#
# This used to be `programs.bash.sessionVariables` in the bash module, which
# only ever reached bash. fish is the login shell, so in practice $EDITOR was
# nano and anything shelling out to an editor — yazi, git, sudoedit — got nano.
#
# It lives beside the neovim config rather than in modules/system/ for the
# usual reason: drop neovim from a host and this points at a missing binary,
# so only hosts that import the editor should import this.
#
# SUDO_EDITOR is set here too rather than beside sudo.nix — `sudo -e` reads it
# from the invoking user's environment, so it is a property of which editor is
# installed, not of the sudo policy.

{
  environment.variables = {
    EDITOR      = "nvim";
    SUDO_EDITOR = "nvim";
  };
}
