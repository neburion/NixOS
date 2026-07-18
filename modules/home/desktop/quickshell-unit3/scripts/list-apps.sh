#!/usr/bin/env bash
# NixOS-adjusted: scan system-wide (nix current-system), per-user profile,
# home-manager, flatpak, and legacy /usr/share/applications.

DIRS=(
  "/run/current-system/sw/share/applications"
  "$HOME/.nix-profile/share/applications"
  "$HOME/.local/share/applications"
  "/var/lib/flatpak/exports/share/applications"
  "$HOME/.local/share/flatpak/exports/share/applications"
  "/usr/share/applications"
)

for dir in "${DIRS[@]}"; do
  [ -d "$dir" ] || continue
  for f in "$dir"/*.desktop; do
    [ -f "$f" ] || continue
    name=$(grep -m1 '^Name='       "$f" | cut -d= -f2-)
    exec=$(grep -m1 '^Exec='       "$f" | cut -d= -f2- | sed 's/ %[A-Za-z]//g')
    cats=$(grep -m1 '^Categories=' "$f" | cut -d= -f2-)
    nod=$(grep  -m1 '^NoDisplay='  "$f" | cut -d= -f2-)
    hid=$(grep  -m1 '^Hidden='     "$f" | cut -d= -f2-)
    [ "$nod" = "true" ] && continue
    [ "$hid" = "true" ] && continue
    [ -z "$name" ]       && continue
    [ -z "$exec" ]       && continue
    desktop=$(basename "$f" .desktop)
    echo "$name|$desktop|$cats|$exec"
  done
done | sort -u
