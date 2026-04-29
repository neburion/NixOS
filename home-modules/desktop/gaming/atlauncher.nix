# home-modules/desktop/gaming/atlauncher.nix
{ stdenv, fetchurl, makeWrapper, jdk, nix-update-script }:

stdenv.mkDerivation rec {
  pname = "atlauncher";
  version = "3.4.40.4";

  src = fetchurl {
    url = "https://github.com/ATLauncher/ATLauncher/releases/download/v${version}/ATLauncher-${version}.jar";
    hash = "";
  };

  dontUnpack = true;
  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    mkdir -p $out/bin $out/share/atlauncher $out/share/applications
    cp $src $out/share/atlauncher/ATLauncher.jar

    makeWrapper ${jdk}/bin/java $out/bin/atlauncher \
      --add-flags "-jar $out/share/atlauncher/ATLauncher.jar" \
      --add-flags "--working-dir \$HOME/.local/share/ATLauncher"

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
