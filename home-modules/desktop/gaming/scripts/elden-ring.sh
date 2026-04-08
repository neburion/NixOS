#!/bin/bash

HOME="/home/neburion"
GAME_DIR="$HOME/.local/share/Steam/steamapps/common/ELDEN RING/Game/"
TOGGLE_ANTI_CHEAT="$HOME/Gaming/Modding/EldenRing/ToggleAntiCheat/"
MOD_ENGINE="$HOME/Gaming/Modding/EldenRing/ModEngine/"

setup-tac() {
    cp start_game_in_offline_mode.exe \
       _steam_appid.txt \
       _winhttp.ddl \
       GMAE_DIR
}

setup-me2() {
}

"$@"
