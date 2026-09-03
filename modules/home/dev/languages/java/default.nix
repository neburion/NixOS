{ ... }:

# The Java toolchain. IntelliJ was installed for months with no JDK behind it —
# `dev/editors/intellij.nix` is four lines adding idea-oss, and nothing in the
# repo provided a compiler, a build tool or a language server.

{
  imports = [
    ./jdk.nix
    ./gradle.nix
    ./lsp.nix
    ./newjava.nix
  ];
}
