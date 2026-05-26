{ pkgs, ... }:

{
  home.packages = [
    (pkgs.writeShellScriptBin "newcpp" ''
      set -e
      DIR="$1"
      [[ -z "$DIR" ]] && { echo "Usage: newcpp <project-name>"; exit 1; }
      [[ -d "$DIR" ]]  && { echo "Error: '$DIR' already exists"; exit 1; }

      mkdir -p "$DIR"/{src,include,tests,build}

      cat > "$DIR/shell.nix" << 'NIXEOF'
{ pkgs ? import <nixpkgs> {} }:
pkgs.mkShell {
  buildInputs = with pkgs; [ gcc gnumake cmake gdb ];
}
NIXEOF

      cat > "$DIR/Makefile" << 'MKEOF'
CXX      = g++
CXXFLAGS = -Wall -Wextra -std=c++23 -g
SRC      = $(wildcard src/*.cpp)
OBJ      = $(SRC:src/%.cpp=build/%.o)
TARGET   = build/app

all: $(TARGET)

$(TARGET): $(OBJ) | build
	$(CXX) $(CXXFLAGS) -o $@ $^

build/%.o: src/%.cpp | build
	$(CXX) $(CXXFLAGS) -c -o $@ $<

build:
	mkdir -p build

clean:
	rm -rf build

.PHONY: all clean
MKEOF

      PROJECT_NAME="$(basename "$DIR")"
      cat > "$DIR/CMakeLists.txt" << CMEOF
cmake_minimum_required(VERSION 3.20)
project($PROJECT_NAME CXX)
set(CMAKE_CXX_STANDARD 23)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
file(GLOB_RECURSE SOURCES src/*.cpp)
add_executable($PROJECT_NAME \''${SOURCES})
target_include_directories($PROJECT_NAME PRIVATE include)
CMEOF

      touch "$DIR/src/main.cpp"
      ln -sf build/compile_commands.json "$DIR/compile_commands.json"
      echo "use nix" > "$DIR/.envrc"

      git init -q "$DIR"
      git -C "$DIR" add -A
      git -C "$DIR" commit -qm "init: $PROJECT_NAME"

      direnv allow "$DIR/.envrc"
      printf '\n→ cd %s\n' "$DIR"
    '')
  ];
}
