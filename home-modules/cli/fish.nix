{ ... }:

{
  programs.fish = {
    enable = true;

    shellAliases = {
      # NixOS
      cd-conf = "cd /home/neburion/NixOS 2>/dev/null || cd /home/9s/NixOS";
      rebuild = "sudo nixos-rebuild switch --flake $([ -d /home/neburion/NixOS ] && echo /home/neburion/NixOS || echo /home/9s/NixOS)#$(hostname)";
      f-rebuild = "sudo nix flake update --flake $([ -d /home/neburion/NixOS ] && echo /home/neburion/NixOS || echo /home/9s/NixOS) && sudo nixos-rebuild switch --flake $([ -d /home/neburion/NixOS ] && echo /home/neburion/NixOS || echo /home/9s/NixOS)#$(hostname)";

      # Superfile
      spf = "superfile";
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
  };
}
