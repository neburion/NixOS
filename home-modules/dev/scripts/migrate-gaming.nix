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
      mkdir -p "$QELLYREE"/{Gaming,.config,Media,Downloads}

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

      echo "==> Fixing ownership..."
      chown -R qellyree:users "$QELLYREE"

      echo "==> Setting qellyree password..."
      passwd qellyree

      echo ""
      echo "Done. Log in as qellyree and run 'rebuild' if needed."
    '')
  ];
}
