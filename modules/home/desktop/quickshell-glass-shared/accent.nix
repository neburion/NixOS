{ pkgs, lib, ... }:

# Wallpaper -> accent extraction, and the per-monitor wallpaper applier.
#
# Why not use the extracted colour directly: the dominant colour of almost
# every wallpaper is a near-black, and even a vibrant one arrives at an
# arbitrary lightness that either disappears against the glass or shouts over
# it. So the extractor keeps only the HUE and pins saturation and lightness to
# fixed values. Every wallpaper lands in the same tonal band, which is what
# keeps the palette coherent while still tracking the image.
#
# State lives in ~/.local/state/quickshell/wallpapers.json, keyed by monitor:
#   { "DP-1": { "path": "/…/x.jpg", "accent": "#A2C6E2" } }
# Services/WallpaperState.qml watches that file; nothing polls.

let
  # Ranked by vibrance, not frequency. Entries outside 18–82% lightness or
  # under 12% saturation are dropped — that discards the near-black that
  # dominates most images. Survivors score saturation * sqrt(pixels), so a
  # small vivid region beats a large dull one without a stray pixel winning.
  extractor = pkgs.writeText "glass-accent.py" ''
    import colorsys, math, re, subprocess, sys

    FALLBACK = "#EDF0F5"
    SAT, LUM = 0.52, 0.76          # the pinned band
    MIN_SAT, LO, HI = 0.12, 0.18, 0.82

    def histogram(path):
        out = subprocess.run(
            ["magick", path, "-resize", "240x240", "-colors", "24",
             "-depth", "8", "-format", "%c", "histogram:info:-"],
            capture_output=True, text=True).stdout
        for m in re.finditer(r"^\s*(\d+):.*#([0-9A-Fa-f]{6})", out, re.M):
            n = int(m.group(1)); h = m.group(2)
            yield n, tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))

    def accent(path):
        best = None
        try:
            entries = list(histogram(path))
        except Exception:
            return FALLBACK
        for n, (r, g, b) in entries:
            hue, lum, sat = colorsys.rgb_to_hls(r, g, b)
            if not (LO <= lum <= HI) or sat < MIN_SAT:
                continue
            score = sat * math.sqrt(n)
            if best is None or score > best[0]:
                best = (score, hue)
        if best is None:
            return FALLBACK
        r, g, b = colorsys.hls_to_rgb(best[1], LUM, SAT)
        return "#%02X%02X%02X" % (round(r * 255), round(g * 255), round(b * 255))

    print(accent(sys.argv[1]) if len(sys.argv) > 1 else FALLBACK)
  '';

  glass-accent = pkgs.writeShellApplication {
    name = "glass-accent";
    runtimeInputs = with pkgs; [ imagemagick python3 coreutils ];
    text = ''
      path="''${1:-}"
      if [ -z "$path" ] || [ ! -f "$path" ]; then
        echo "#EDF0F5"; exit 0
      fi

      ext="''${path##*.}"
      case "''${ext,,}" in
        # ImageMagick cannot read these at all — no hue to borrow.
        mp4|mkv|webm|avi|mov) echo "#EDF0F5"; exit 0 ;;
        # Multi-frame: read frame zero, else the histogram spans every frame.
        gif)                  target="''${path}[0]" ;;
        *)                    target="$path" ;;
      esac

      python3 ${extractor} "$target"
    '';
  };
in
{
  # WallpaperState watches this file from startup, so it has to exist before
  # the first wallpaper is ever chosen — otherwise quickshell logs a failed
  # read on every launch. Never overwritten; glass-wallpaper owns the content.
  home.activation.initGlassWallpaperState = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    STATE="$HOME/.local/state/quickshell/wallpapers.json"
    if [ ! -f "$STATE" ]; then
      mkdir -p "$(dirname "$STATE")"
      echo '{}' > "$STATE"
    fi
  '';

  home.packages = [
    glass-accent

    # Applies a wallpaper to ONE monitor, then records the path and its derived
    # accent under that monitor's key. Both the image and the hue are per-output.
    (pkgs.writeShellApplication {
      name = "glass-wallpaper";
      runtimeInputs = with pkgs; [ awww mpvpaper jq coreutils procps glass-accent ];
      text = ''
        mon="''${1:-}"
        path="''${2:-}"
        if [ -z "$mon" ] || [ -z "$path" ]; then
          echo "usage: glass-wallpaper <monitor> <path>" >&2
          exit 2
        fi

        state="$HOME/.local/state/quickshell/wallpapers.json"
        mkdir -p "$(dirname "$state")"
        [ -f "$state" ] || echo '{}' > "$state"

        # Whatever was playing on THIS output stops; other outputs are untouched.
        pkill -f "mpvpaper .*''${mon}" 2>/dev/null || true

        ext="''${path##*.}"
        case "''${ext,,}" in
          mp4|mkv|webm|avi|mov|gif)
            mpvpaper "$mon" "$path" --mpv-options 'loop-file=inf' >/dev/null 2>&1 &
            ;;
          *)
            awww img "$path" --outputs "$mon" --transition-type fade >/dev/null 2>&1 || true
            ;;
        esac

        accent="$(glass-accent "$path")"

        tmp="$(mktemp)"
        jq --arg m "$mon" --arg p "$path" --arg a "$accent" \
           '.[$m] = { path: $p, accent: $a }' "$state" > "$tmp"
        mv "$tmp" "$state"
      '';
    })

    # Replays the recorded state on login. Replaces the single-wallpaper
    # exec-once one-liner the other presets use, which knows nothing about
    # per-monitor assignment.
    (pkgs.writeShellApplication {
      name = "glass-wallpaper-restore";
      runtimeInputs = with pkgs; [ awww mpvpaper jq coreutils ];
      text = ''
        state="$HOME/.local/state/quickshell/wallpapers.json"
        [ -f "$state" ] || exit 0

        jq -r 'to_entries[] | "\(.key)\t\(.value.path)"' "$state" \
        | while IFS=$'\t' read -r mon path; do
            [ -n "$path" ] && [ -f "$path" ] || continue
            ext="''${path##*.}"
            case "''${ext,,}" in
              mp4|mkv|webm|avi|mov|gif)
                mpvpaper "$mon" "$path" --mpv-options 'loop-file=inf' >/dev/null 2>&1 &
                ;;
              *)
                awww img "$path" --outputs "$mon" --transition-type none >/dev/null 2>&1 || true
                ;;
            esac
          done
      '';
    })
  ];
}
