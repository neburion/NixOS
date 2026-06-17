{ pkgs, lib, ... }:

let
  runtimeLibs = lib.makeLibraryPath (with pkgs; [ stdenv.cc.cc zlib openssl ]);

  claude = pkgs.symlinkJoin {
    name = "claude";
    paths = [ pkgs.claude-code ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/claude \
        --prefix LD_LIBRARY_PATH : ${runtimeLibs}
    '';
  };
in
{
  home.packages = [ claude ];
}
