{ ... }:

{
  programs.fish = {
    enable = true;

    shellAliases = {
      # NixOS
      cdnixos  = "cd $HOME/NixOS";
      rebuild  = "sudo nixos-rebuild switch --flake $HOME/NixOS#pod042";
      trebuild = "sudo nixos-rebuild test --flake $HOME/NixOS#pod042";
      update   = "sudo nix flake update --flake $HOME/NixOS && sudo nixos-rebuild switch --flake $HOME/NixOS";

      # Superfile
      spf  = "superfile";
      sspf = "sudo superfile";

      # Dev
      cd-dev = "cd ~/Projects/Dev";
      mkrepo = "gh repo create (basename $PWD) --public --source=. --remote=origin --push";
      rmrepo = "git remote remove origin && gh repo delete neburion/(basename $PWD)";
    };

    functions = {
      fish_prompt = {
        body = ''
          set_color 'cba6f7'
          printf '%s@%s' (whoami) (hostname -s)
          set_color normal
          printf ':'
          set_color 'cba6f7'
          printf '%s' (basename $PWD)
          set_color normal
          printf '$ '
        '';
      };
    };
  };
}
