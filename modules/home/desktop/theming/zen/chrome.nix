{ pkgs, lib, themes }:
let
  makeUserChrome = name: t: pkgs.writeText "userChrome-${name}.css" ''
    :root {
      --toolbar-bgcolor: ${t.bg} !important;
      --toolbar-color: ${t.fg} !important;
      --tab-selected-bgcolor: ${t.surface} !important;
      --toolbarbutton-hover-background: ${t.selection} !important;
      --toolbarbutton-active-background: ${t.selection} !important;
      --urlbar-background: ${t.surface} !important;
      --urlbar-color: ${t.fg} !important;
      --sidebar-background-color: ${t.bg} !important;
      --sidebar-color: ${t.fg} !important;
      --zen-main-browser-background: ${t.bg} !important;
      --zen-colors-primary: ${t.fishPrimary or t.fg} !important;
      --zen-colors-border: ${t.surface} !important;
    }
  '';
in
{
  cssFiles = lib.mapAttrs makeUserChrome themes;
}
