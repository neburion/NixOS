#!/bin/bash

HOME="/home/neburion"
WINE_BIN="$HOME/.config/heroic/tools/proton/GE-Proton-latest/files/bin/wine"
GAME_PREFIX="$HOME/Gaming/heroic/default/prefixes/Rocket League/pfx"
BAKKESS_SETUP="$HOME/Gaming/Mods/Rocket League/BakkesModSetup.exe"
BAKKESS_EXE="$GAME_PREFIX/drive_c/Program Files/BakkesMod/BakkesMod.exe"

setup-bakkess() {
    WINEPREFIX="$GAME_PREFIX" "$WINE_BIN" "$BAKKESS_SETUP"
}

launch-bakkess() {
    WINEESYNC=1 WINEFSYNC=1 WINEPREFIX="$GAME_PREFIX" "$WINE_BIN" "$BAKKESS_EXE"
}

"$@"
