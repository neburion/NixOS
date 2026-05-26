{ pkgs, ... }:

{
  home.packages = [
    (pkgs.writeShellScriptBin "newc" ''
      set -e
      DIR="$1"
      [[ -z "$DIR" ]] && { echo "Usage: newc <project-name>"; exit 1; }
      [[ -d "$DIR" ]]  && { echo "Error: '$DIR' already exists"; exit 1; }

      mkdir -p "$DIR"/{src,include,tests,build}

      cat > "$DIR/shell.nix" << 'NIXEOF'
{ pkgs ? import <nixpkgs> {} }:
pkgs.mkShell {
  buildInputs = with pkgs; [ gcc gnumake cmake gdb ];
}
NIXEOF

      cat > "$DIR/Makefile" << 'MKEOF'
CC      = gcc
CFLAGS  = -Wall -Wextra -std=c17 -g
SRC     = $(wildcard src/*.c)
OBJ     = $(SRC:src/%.c=build/%.o)
TARGET  = build/app

all: $(TARGET)

$(TARGET): $(OBJ) | build
	$(CC) $(CFLAGS) -o $@ $^

build/%.o: src/%.c | build
	$(CC) $(CFLAGS) -c -o $@ $<

build:
	mkdir -p build

clean:
	rm -rf build

.PHONY: all clean
MKEOF

      PROJECT_NAME="$(basename "$DIR")"
      cat > "$DIR/CMakeLists.txt" << CMEOF
cmake_minimum_required(VERSION 3.20)
project($PROJECT_NAME C)
set(CMAKE_C_STANDARD 17)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
file(GLOB_RECURSE SOURCES src/*.c)
add_executable($PROJECT_NAME \''${SOURCES})
target_include_directories($PROJECT_NAME PRIVATE include)
CMEOF

      touch "$DIR/src/main.c"
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
