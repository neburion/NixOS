{ pkgs, lib, themes, ... }:

let
  gtkThemeMap = lib.mapAttrs (_: t: t.gtkTheme or "Adwaita-dark") themes;

  css = import ./css.nix { inherit pkgs lib themes; };

  gtk4CaseLines = lib.concatStringsSep "\n        " (lib.mapAttrsToList (n: f:
    ''${n}) gtk4_css="${f}" ;;''
  ) css.gtk4Files);

  gtk3CaseLines = lib.concatStringsSep "\n        " (lib.mapAttrsToList (n: f:
    ''${n}) gtk3_css="${f}" ;;''
  ) css.gtk3Files);

  gtkCaseLines = lib.concatStringsSep "\n        " (lib.mapAttrsToList (n: gtk:
    ''${n}) theme="${gtk}" ;;''
  ) gtkThemeMap);

  gtkHookCaseLines = lib.concatStringsSep "\n      " (lib.mapAttrsToList (n: gtk:
    ''${n}) gtk_theme="${gtk}" ;;''
  ) gtkThemeMap);
in
{
  # Depends on initHyprTheme so the hypr/theme.conf symlink exists on first run.
  home.activation.syncGtkTheme = lib.hm.dag.entryAfter [ "writeBoundary" "initHyprTheme" ] ''
    HYPR_THEME="$HOME/.config/hypr/theme.conf"
    if [ -L "$HYPR_THEME" ]; then
      name=$(basename "$(readlink "$HYPR_THEME")" .conf)
      gtk4_css=""
      gtk3_css=""
      theme="Adwaita-dark"
      case "$name" in
        ${gtk4CaseLines}
        *) ;;
      esac
      case "$name" in
        ${gtk3CaseLines}
        *) ;;
      esac
      case "$name" in
        ${gtkCaseLines}
        *) ;;
      esac
      export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
      export XDG_RUNTIME_DIR="/run/user/$(id -u)"
      ${pkgs.glib}/bin/gsettings set org.gnome.desktop.interface gtk-theme "$theme" 2>/dev/null || true
      # `install -m 644` overwrites read-only targets; plain `cp` fails because
      # the source lives in the nix store (read-only) and a previous activation
      # leaves the user's gtk.css with -r--r--r-- perms.
      if [ -n "$gtk4_css" ]; then
        install -D -m 644 "$gtk4_css" "$HOME/.config/gtk-4.0/gtk.css"
      fi
      if [ -n "$gtk3_css" ]; then
        install -D -m 644 "$gtk3_css" "$HOME/.config/gtk-3.0/gtk.css"
      fi
    fi
  '';

  themeHooks.gtk = pkgs.writeShellScript "theme-hook-gtk" ''
    theme="$1"
    gtk4_css=""
    gtk3_css=""
    gtk_theme="Adwaita-dark"
    case "$theme" in
      ${gtk4CaseLines}
      *) ;;
    esac
    case "$theme" in
      ${gtk3CaseLines}
      *) ;;
    esac
    case "$theme" in
      ${gtkHookCaseLines}
      *) ;;
    esac
    export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(${pkgs.coreutils}/bin/id -u)/bus"
    export XDG_RUNTIME_DIR="/run/user/$(${pkgs.coreutils}/bin/id -u)"
    ${pkgs.glib}/bin/gsettings set org.gnome.desktop.interface gtk-theme "$gtk_theme" 2>/dev/null || true
    ${pkgs.glib}/bin/gsettings set org.gnome.desktop.interface color-scheme "prefer-dark" 2>/dev/null || true
    if [ -n "$gtk4_css" ]; then
      ${pkgs.coreutils}/bin/install -D -m 644 "$gtk4_css" "$HOME/.config/gtk-4.0/gtk.css"
    fi
    if [ -n "$gtk3_css" ]; then
      ${pkgs.coreutils}/bin/install -D -m 644 "$gtk3_css" "$HOME/.config/gtk-3.0/gtk.css"
    fi
  '';
}
