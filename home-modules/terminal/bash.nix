{ ... }:
{
  programs.bash = {
    enable = true;

    shellAliases = {
      # NixOS
      cd-conf = "cd /etc/nixos";
      conf = "sudo -e /etc/nixos/configuration.nix";
      m-conf = "sudo nvim /etc/nixos/modules";
      h-conf = "sudo -e /etc/nixos/home.nix";
      hm-conf = "sudo nvim /etc/nixos/home-modules";
      f-conf = "sudo -e /etc/nixos/flake.nix";
      rebuild = "sudo nixos-rebuild switch --flake ~/NixOS#pod042";
      f-rebuild = "sudo nix flake update --flake ~/NixOS && sudo nixos-rebuild switch --flake ~/NixOS#pod042";

      # Superfile
      spf = "superfile";
      sspf = "sudo superfile";

      # Git
      mkrepo = "gh repo create \$(basename \"$PWD\") --public --source=. --remote=origin --push";
      rmrepo = "git remote remove origin && gh repo delete neburion/$(basename \"$PWD\")";
      
      # Dev
      cd-dev = "cd ~/Projects/Dev";
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
