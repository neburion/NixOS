{ pkgs, ... }:

{
  home.packages = with pkgs; [
    unstable.shadps4
    unstable.shadps4-qtlauncher
    # shadPS4 dropped its built-in PKG installer in 0.7; extraction is an
    # external job now. `pkgtool pkg_extract <file.pkg> <outdir>`.
    unstable.liborbispkg-pkgtool
  ];
}
