{ pkgs, lib, ... }:

let
  runtimeLibs = lib.makeLibraryPath (with pkgs; [ stdenv.cc.cc zlib openssl ]);

  wrapBin = pkg: bin: pkgs.symlinkJoin {
    name = bin;
    paths = [ pkg ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/${bin} \
        --prefix LD_LIBRARY_PATH : ${runtimeLibs}
    '';
  };
in
{
  home.packages = [
    (wrapBin pkgs.claude-code "claude")
    (wrapBin pkgs.opencode   "opencode")
  ];
}
