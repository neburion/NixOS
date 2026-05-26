{ pkgs, ... }:

{
  home.packages = [
    (pkgs.writeShellScriptBin "migrate-gaming" ''
      set -euo pipefail

      if [ "$(id -u)" -ne 0 ]; then
        exec sudo "$0" "$@"
      fi

      NEBURION=/home/neburion
      QELLYREE=/home/qellyree

      if ! id qellyree &>/dev/null; then
        echo "qellyree user not found — run 'rebuild' first."
        exit 1
      fi

      echo "==> Creating qellyree directory structure..."
      mkdir -p "$QELLYREE"/{Gaming,.config,Docs/Passwords,Media,Downloads}

      echo "==> Moving Gaming directory..."
      if [ -d "$NEBURION/Gaming" ]; then
        mv "$NEBURION/Gaming"/* "$QELLYREE/Gaming/" 2>/dev/null || true
        rmdir "$NEBURION/Gaming" 2>/dev/null || true
      fi

      echo "==> Moving gaming configs..."
      for cfg in vesktop heroic; do
        if [ -d "$NEBURION/.config/$cfg" ]; then
          mv "$NEBURION/.config/$cfg" "$QELLYREE/.config/"
        fi
      done

      echo "==> Copying backup password for qellyree..."
      if [ -f "$NEBURION/Docs/Passwords/backup-password" ]; then
        cp "$NEBURION/Docs/Passwords/backup-password" "$QELLYREE/Docs/Passwords/backup-password"
      fi

      echo "==> Copying rclone config for qellyree..."
      if [ -d "$NEBURION/.config/rclone" ]; then
        mkdir -p "$QELLYREE/.config/rclone"
        cp -r "$NEBURION/.config/rclone/." "$QELLYREE/.config/rclone/"
      fi

      echo "==> Fixing ownership..."
      chown -R qellyree:users "$QELLYREE"

      echo "==> Setting qellyree password..."
      passwd qellyree

      echo ""
      echo "Done. Log in as qellyree and run 'rebuild' if needed."
    '')
  ];
}
