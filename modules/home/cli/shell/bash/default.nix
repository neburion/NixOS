{ ... }:

# Bash. Not the login shell — fish is — but it is what every `#!/usr/bin/env
# bash` script and every `sudo -i` lands in, so it should not be a bare prompt.
#
# Restored from an older revision, minus what had gone stale: it used to define
# rebuild/trebuild/update as raw nixos-rebuild aliases with hardcoded paths,
# which would now shadow the real scripts in modules/tools/fleet/, and a
# build-iso alias pointing at a flake attribute that no longer exists.
#
# Aliases that still mean something are kept and match fish's.
#
# EDITOR/SUDO_EDITOR moved to dev/editors/neovim/enable.nix — setting them
# here only ever reached bash, and fish is the login shell.

{
  programs.bash = {
    enable = true;

    shellAliases = {
      cdnixos = "cd $HOME/NixOS";
      spf     = "superfile";
      sspf    = "sudo superfile";
      cddev   = "cd ~/Projects/Dev";
    };

    # Matches the fish prompt: user@host:dir$, primary colour on the name and
    # the path, everything else default.
    initExtra = ''
      PS1='\[\e[38;2;200;203;207m\]\u@\h\[\e[0m\]:\[\e[38;2;200;203;207m\]\W\[\e[0m\]\$ '
    '';
  };
}
