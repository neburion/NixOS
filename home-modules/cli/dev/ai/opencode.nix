{ pkgs, lib, ... }:

let
  runtimeLibs = lib.makeLibraryPath (with pkgs; [ stdenv.cc.cc zlib openssl ]);

  opencode = pkgs.symlinkJoin {
    name = "opencode";
    paths = [ pkgs.opencode ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/opencode \
        --prefix LD_LIBRARY_PATH : ${runtimeLibs}
    '';
  };
in
{
  home.packages = [ opencode ];
}
