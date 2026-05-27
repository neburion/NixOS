#!/usr/bin/env bash
set -euo pipefail

# PERSONA_DIR is substituted at build time by default.nix
PERSONA_DIR="@PERSONA_DIR@"
TARGET="$HOME/.claude/CLAUDE.md"
MARKER="<!-- claude-persona: -->"

list_personas() {
    for p in "$PERSONA_DIR"/personas/*.md; do
        basename "$p" .md
    done
}

current_persona() {
    if [ -f "$TARGET" ]; then
        head -1 "$TARGET" | grep -oP "(?<=$MARKER ).*" || echo "unmanaged"
    else
        echo "none"
    fi
}

usage() {
    echo "usage: claude-persona <persona>|status|list"
    echo
    echo "Available personas:"
    while IFS= read -r p; do
        echo "  - $p"
    done < <(list_personas)
    exit 1
}

[ $# -eq 1 ] || usage

case "$1" in
    list)
        list_personas
        ;;
    status)
        current_persona
        ;;
    *)
        persona_file="$PERSONA_DIR/personas/$1.md"
        base_file="$PERSONA_DIR/base.md"
        if [ ! -f "$persona_file" ]; then
            echo "unknown persona: $1" >&2
            usage
        fi
        mkdir -p "$(dirname "$TARGET")"
        {
            echo "$MARKER $1"
            echo
            cat "$persona_file"
            echo
            cat "$base_file"
        } > "$TARGET"
        echo "active persona: $1"
        ;;
esac
