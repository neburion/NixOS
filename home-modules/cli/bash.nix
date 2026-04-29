{ ... }:

{
  programs.bash = {
    enable = true;

    shellAliases = {
      # NixOS
      cd-conf   = "cd /home/neburion/NixOS || cd /home/9s/NixOS";
      rebuild   = "sudo nixos-rebuild switch --flake /home/neburion/NixOS#pod042
                 ||sudo nixos-rebuild switch --flake /home/9s/NixOS#pod153";
      t-rebuild = "sudo nixos-rebuild test --flake /home/neburion/NixOS#pod042
                 ||sudo nixos-rebuild test --flake /home/9s/NixOS#pod153";
      update    = "sudo nix flake update --flake /home/neburion/NixOS && sudo nixos-rebuild switch --flake /home/neburion/NixOS
                 ||sudo nix flake update --flake /home/9s/NixOS && sudo nixos-rebuild switch --flake /home/9s/NixOS";

      # Superfile
      spf  = "superfile";
      sspf = "sudo superfile";

      # Dev
      cd-dev = "cd ~/Projects/Dev";
      mkrepo = "gh repo create $(basename \"$PWD\") --public --source=. --remote=origin --push";
      rmrepo = "git remote remove origin && gh repo delete neburion/$(basename \"$PWD\")";
    };

    sessionVariables = {
      EDITOR = "nvim";
      SUDO_EDITOR = "nvim";
    };

    initExtra = ''
      PS1='\[\e[38;2;203;166;247m\]\u@\h\[\e[0m\]:\[\e[38;2;203;166;247m\]\W\[\e[0m\]\$ ';
    '';
  };
}
