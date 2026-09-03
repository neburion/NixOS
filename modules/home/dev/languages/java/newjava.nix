{ pkgs, ... }:

let
  templates = ./templates;

  # Written as store files rather than heredocs inside the script. A heredoc
  # nested in a Nix string inside a shell script has to be de-indented on the
  # way out, and a fixed `sed 's/^ *//'` mangles anything indented deeper than
  # the marker — the first version of this emitted Java with the println
  # dedented out of its own method.
  mainJava = pkgs.writeText "Main.java" ''
    public class Main {
        public static void main(String[] args) {
            System.out.println("hello");
        }
    }
  '';

  buildGradle = pkgs.writeText "build.gradle" ''
    plugins {
        id 'application'
    }

    application {
        mainClass = 'Main'
    }
  '';
in
{
  home.packages = [
    (pkgs.writeShellScriptBin "newjava" ''
      set -e
      DIR="$1"
      [[ -z "$DIR" ]] && { echo "Usage: newjava <project-name>"; exit 1; }
      [[ -d "$DIR" ]]  && { echo "Error: '$DIR' already exists"; exit 1; }

      # Gradle's own layout, so this and `gradle init` agree.
      mkdir -p "$DIR"/src/main/java "$DIR"/src/test/java

      install -m 644 ${templates}/shell.nix "$DIR/shell.nix"
      install -m 644 ${mainJava}    "$DIR/src/main/java/Main.java"
      install -m 644 ${buildGradle} "$DIR/build.gradle"

      echo "use nix" > "$DIR/.envrc"
      echo "Created $DIR"
    '')
  ];
}
