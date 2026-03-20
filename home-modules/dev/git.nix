{ ... }:
{
  programs.git = {
    enable = true;
    settings = {
      user.name = "neburion";
      user.email = "neburion@proton.me";
      init.defaultBranch = "master";
      pull.rebase = false;
    };
  };

  programs.gh = {
    enable = true;
    settings = {
      git_protocol = "ssh";
      editor = "nvim";
    };
  };
}
