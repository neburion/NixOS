{ stdenv, fetchurl, makeWrapper, jdk, libGL, glfw, nix-update-script }:
stdenv.mkDerivation rec {
  pname = "atlauncher";
  version = "3.4.40.4";
  src = fetchurl {
    url = "https://github.com/ATLauncher/ATLauncher/releases/download/v${version}/ATLauncher-${version}.jar";
    hash = "sha256-G5CaXie+UreNJ+KRTsHfNcevj40cEjkNC/SK8ut6dkk=";
  };
  dontUnpack = true;
  nativeBuildInputs = [ makeWrapper ];
  installPhase = ''
    mkdir -p $out/bin $out/share/atlauncher $out/share/applications
    cp $src $out/share/atlauncher/ATLauncher.jar
    makeWrapper ${jdk}/bin/java $out/bin/atlauncher \
      --add-flags "-jar $out/share/atlauncher/ATLauncher.jar" \
      --add-flags "--working-dir \$HOME/.local/share/ATLauncher" \
      --prefix LD_LIBRARY_PATH : "${libGL}/lib:${glfw}/lib"
    cat > $out/share/applications/atlauncher.desktop <<EOF
    [Desktop Entry]
    Name=ATLauncher
    Exec=$out/bin/atlauncher
    Icon=atlauncher
    Type=Application
    Categories=Game;
    EOF
  '';
  passthru.updateScript = nix-update-script { };
}
