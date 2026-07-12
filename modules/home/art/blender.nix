{ pkgs, ... }:

{
  home.packages = with pkgs; [
    blender
  ];

  xdg.desktopEntries.blender = {
    name           = "Blender";
    genericName    = "3D modeler";
    comment        = "3D modeling, animation, rendering and post-production";
    exec           = "${pkgs.blender}/bin/blender %f";
    icon           = "blender";
    terminal       = false;
    type           = "Application";
    categories     = [ "Graphics" "3DGraphics" ];
    mimeType       = [ "application/x-blender" ];
    settings = {
      StartupWMClass = "Blender";
      Keywords           = "3d;cg;modeling;animation;painting;sculpting;texturing;video editing;video tracking;rendering;render engine;cycles;python;";
      PrefersNonDefaultGPU = "false";
    };
  };
}
