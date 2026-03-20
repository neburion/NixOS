{ ... }:
{
  programs.bash = {
    enable = true;

    shellAliases = {
      # NixOS
      cd-conf = "cd ~/NixOS";
      conf = "sudo -e ~/NixOS/configuration.nix";
      h-conf = "sudo -e ~/NixOS/home.nix";
      f-conf = "sudo -e ~/NixOS/flake.nix";
      m-conf = "sudo nvim ~/NixOS/modules";
      hm-conf = "sudo nvim ~/NixOS/home-modules";
      rebuild = "sudo nixos-rebuild switch --flake ~/NixOS#pod042";
      f-rebuild = "sudo nix flake update --flake ~/NixOS && sudo nixos-rebuild switch --flake ~/NixOS#pod042";

      # Superfile
      spf = "superfile";
      sspf = "sudo superfile";

      # Dev
      cd-dev = "cd ~/Projects/Dev";
      mkrepo = "gh repo create \$(basename \"$PWD\") --public --source=. --remote=origin --push";
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
