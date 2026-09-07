{ pkgs, config, ... }:

{
  programs.git = {
    enable = true;
    settings = {
      user.name = "neburion";
      user.email = "neburion@proton.me";
      init.defaultBranch = "master";
      pull.rebase = false;

      # Readability. histogram produces tighter hunks than the default myers;
      # colorMoved paints relocated code differently from newly written code, so
      # a refactor stops reading as a rewrite.
      diff.algorithm = "histogram";
      diff.colorMoved = "zebra";
      diff.colorMovedWS = "allow-indentation-change";
      log.date = "short";
    };
  };

  programs.gh = {
    enable = true;
    settings = {
      git_protocol = "ssh";
      editor = "nvim";
    };
  };

  # tig is a curses browser over `git log`. Delete git and it is junk, so it
  # lives here beside gh rather than in a file of its own.
  home.packages = [ pkgs.tig ];

  # diff-highlight ships inside git's own contrib/, so the path is derived from
  # the git package above and cannot drift out of sync with it.
  xdg.configFile."tig/config".text = ''
    set main-view = line-number:no,interval=5 id:yes,width=8 date:default,format="%Y-%m-%d" author:abbreviated commit-title:yes,graph,refs,overflow=no
    set blame-view = date:default,format="%Y-%m-%d" author:abbreviated file-name:auto id:yes,color line-number:yes,interval=1 text

    set diff-highlight = ${config.programs.git.package}/share/git/contrib/diff-highlight/diff-highlight
    set diff-indicator = yes

    set line-graphics = utf-8
    set tab-size = 4
    set wrap-lines = yes
    set ignore-case = smart-case
    set mouse = yes
    set refresh-mode = auto
    set start-on-head = yes
    set split-view-height = 70%
    set vertical-split = auto
    set editor-line-number = yes
  '';
}
