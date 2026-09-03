{ ... }:

{
  programs.fish = {
    enable = true;

    loginShellInit = ''
      # Auto-start Hyprland on TTY login, but only if it's actually installed
      # on this host. Fleet users share this fish module; headless hosts (e.g.
      # home-server, personal-server) import fish but not Hyprland, and the
      # unguarded exec would spam an error on every console-autologin.
      if string match -q '/dev/tty*' (tty); and command -q Hyprland
        exec Hyprland
      end
    '';

    shellAliases = {
      # NixOS
      cdnixos = "cd $HOME/NixOS";
      # rebuild / trebuild / update: shell-agnostic scripts, see
      # modules/tools/

      # Superfile
      spf  = "superfile";
      sspf = "sudo superfile";

      # Quickshell. Points at the generated shell, not at the repo: the .nix
      # files are what *writes* the QML, they are not QML themselves, so the
      # old path here could never have loaded. Each preset now materialises its
      # own shell into the same place, so this stays correct across a swap.
      qs = "quickshell --path $HOME/.config/quickshell";

      # Dev
      cddev = "cd ~/Projects/Dev";
      mkrepo = "gh repo create (basename $PWD) --public --source=. --remote=origin --push";
      rmrepo = "git remote remove origin && gh repo delete neburion/(basename $PWD)";
    };

    # Its own colours, literal, matching desktop/glass/palette.nix. This module
    # used to take the repo-wide `themes` attrset and register a theme-set hook
    # that rewrote these on every switch — a shell that works over ssh with no
    # display, following a desktop's palette. A headless server got it too.
    #
    # `set -U` is a universal variable, so these apply once and then persist in
    # fish's own state; changing them here does not move an existing shell.
    interactiveShellInit = ''
      set -q fish_theme_primary;   or set -U fish_theme_primary   C8CBCF
      set -q fish_theme_secondary; or set -U fish_theme_secondary 6E737A
    '';

    functions = {
      fish_greeting = {
        body = "";
      };

      fish_prompt = {
        body = ''
          set_color $fish_theme_primary
          printf '%s@%s' (whoami) (hostname -s)
          set_color normal
          printf ':'
          set_color $fish_theme_primary
          printf '%s' (string replace $HOME '~' $PWD)
          set_color normal
          printf '$ '
        '';
      };

      fish_right_prompt = {
        body = ''
          set branch (git branch --show-current 2>/dev/null)
          if test -n "$branch"
            set_color $fish_theme_secondary
            printf ' %s' $branch
            set_color normal
          end
        '';
      };
    };
  };

}
