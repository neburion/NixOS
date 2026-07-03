{ pkgs, ... }:

{
  programs.zed-editor = {
    enable = true;
    extensions = [
      "nix"
      "toml"
      "zig"
      "odin"
      "nord"
      "everforest"
      "catppuccin"
    ];
    extraPackages = with pkgs; [
      clang-tools  # clangd for C/C++
      rust-analyzer
      zls
      ols
      nil          # nix LSP
      pyright
    ];
    userSettings = {
      ui_font_size = 16;
      buffer_font_size = 14;
      theme = {
        mode = "system";
        light = "One Light";
        dark = "One Dark";
      };
      vim_mode = true;
      autosave = "on_focus_change";
      format_on_save = "on";
      terminal = {
        shell = {
          program = "fish";
        };
      };
    };
  };
}
