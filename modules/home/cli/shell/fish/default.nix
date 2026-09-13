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
      # mkrepo / rmrepo are functions, not aliases: they take a forge argument.
      # See the functions block below.
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

      # Create the current directory as a repo on a forge, then push it. The
      # forge is required. A bare `mkrepo` meaning GitHub was a leftover from
      # when this was a gh-only alias; with two forges, which one you are
      # publishing to is not something to get by not thinking about it.
      #
      #   mkrepo gh     GitHub
      #   mkrepo cb     Codeberg
      #
      # gh does GitHub only. Codeberg is Forgejo, whose CLI (tea) can read a
      # token from nothing but a plaintext ~/.config/tea/config.yml -- it has
      # no --token or --url flag. So Codeberg goes over its REST API directly,
      # reading the token from sops at call time, the same way aerc.nix reads
      # its Posteo password. Nothing unencrypted is written to disk.
      #
      # The secret is declared in modules/home/dev/tools/system.nix.
      mkrepo = {
        argumentNames = [ "host" ];
        body = ''
          set -l name (basename $PWD)
          switch "$host"
            case cb codeberg
              set -l tok (cat /run/secrets/codeberg-token)
              or begin
                echo "mkrepo: cannot read /run/secrets/codeberg-token" >&2
                return 1
              end
              set -l resp (curl -fsS -X POST https://codeberg.org/api/v1/user/repos \
                -H "Authorization: token $tok" \
                -H "Content-Type: application/json" \
                -d '{"name":"'$name'","private":false}')
              or return 1
              # Take the remote from the response rather than assembling it
              # from a hardcoded owner: the Codeberg account is carian_fish,
              # not neburion, and a literal here would rot again on a rename.
              git remote add origin (echo $resp | jq -r .ssh_url)
              git push -u origin (git branch --show-current)
            case gh github
              gh repo create $name --public --source=. --remote=origin --push
            case ""
              echo "mkrepo: name a forge (gh or cb)" >&2
              return 1
            case "*"
              echo "mkrepo: unknown host '$host' (use gh or cb)" >&2
              return 1
          end
        '';
      };

      # Inverse of mkrepo. Same forge argument, but this one keeps the old
      # default: a bare `rmrepo` is GitHub.
      rmrepo = {
        argumentNames = [ "host" ];
        body = ''
          set -l name (basename $PWD)
          switch "$host"
            case cb codeberg
              set -l tok (cat /run/secrets/codeberg-token)
              or begin
                echo "rmrepo: cannot read /run/secrets/codeberg-token" >&2
                return 1
              end
              # Owner comes from the token, not a literal. See mkrepo.
              set -l owner (curl -fsS https://codeberg.org/api/v1/user \
                -H "Authorization: token $tok" | jq -r .login)
              or return 1
              git remote remove origin
              and curl -fsS -X DELETE https://codeberg.org/api/v1/repos/$owner/$name \
                -H "Authorization: token $tok"
            case "" gh github
              # Owner comes from whoever gh is authenticated as, not a literal.
              # See the Codeberg branch above: `neburion` was hardcoded here, so
              # this deleted the wrong account's repo under any other login, and
              # would rot on a rename.
              set -l owner (gh api user --jq .login)
              if test -z "$owner"
                echo "rmrepo: cannot determine the GitHub owner (try gh auth status)" >&2
                return 1
              end
              git remote remove origin
              and gh repo delete $owner/$name
            case "*"
              echo "rmrepo: unknown host '$host' (use gh or cb)" >&2
              return 1
          end
        '';
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
