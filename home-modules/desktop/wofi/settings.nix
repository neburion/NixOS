{ lib }:

let
  sharedSettings = {
    prompt        = ">";
    normal_window = true;
    layer         = "overlay";
    columns       = 1;
    width         = "35%";
    height        = "30%";
    location      = "center";
    orientation   = "vertical";
    halign        = "fill";
    hide_scroll   = true;
    no_actions    = true;
    gtk_dark      = true;
    insensitive   = false;
    hide_search   = false;
  };

  toArg = k: v:
    if v == true then "--${k}"
    else if v == false then ""
    else "--${k}=${toString v}";

  wofiArgs = lib.concatStringsSep " "
    (lib.filter (s: s != "")
      (lib.mapAttrsToList toArg sharedSettings));
in
{
  inherit sharedSettings wofiArgs;
}
