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

{
  programs.bash = {
    enable = true;

    shellAliases = {
      cdnixos = "cd $HOME/NixOS";
      spf     = "superfile";
      sspf    = "sudo superfile";
      cddev   = "cd ~/Projects/Dev";
    };

    sessionVariables = {
      EDITOR      = "nvim";
      SUDO_EDITOR = "nvim";
    };

    # Matches the fish prompt: user@host:dir$, primary colour on the name and
    # the path, everything else default.
    initExtra = ''
      PS1='\[\e[38;2;200;203;207m\]\u@\h\[\e[0m\]:\[\e[38;2;200;203;207m\]\W\[\e[0m\]\$ '
    '';
  };
}
