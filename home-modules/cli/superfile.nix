{ ... }:

{
  programs.superfile = {
    enable = true;
    settings = {
      editor = "nvim";
      dir_editor = "nvim";
      ignore_missing_fields = true;
    };
  };
}
