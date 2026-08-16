{ pkgs, ... }:

# Phone-as-extended-display via wayvnc + Hyprland headless output.
# Toggle script: first press creates a virtual monitor and starts wayvnc on
# 0.0.0.0:5900 bound to it; second press kills wayvnc and removes the monitor.
# No auth (LAN-only, user-triggered — never left running), and view-only
# (--disable-input) so an unauthenticated LAN client can't drive the desktop.

let
  phoneDisplayToggle = pkgs.writeShellApplication {
    name = "phone-display-toggle";
    runtimeInputs = with pkgs; [ wayvnc hyprland jq iproute2 libnotify coreutils avahi nettools ];
    text = ''
      state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/phone-display"
      mkdir -p "$state_dir"
      pidfile="$state_dir/wayvnc.pid"
      avahi_pidfile="$state_dir/avahi.pid"
      outfile="$state_dir/output.name"

      is_running() {
        [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile" 2>/dev/null)" 2>/dev/null
      }

      stop() {
        if is_running; then
          kill "$(cat "$pidfile")" 2>/dev/null || true
        fi
        rm -f "$pidfile"
        if [ -f "$avahi_pidfile" ]; then
          kill "$(cat "$avahi_pidfile")" 2>/dev/null || true
          rm -f "$avahi_pidfile"
        fi
        if [ -f "$outfile" ]; then
          hyprctl output remove "$(cat "$outfile")" >/dev/null 2>&1 || true
          rm -f "$outfile"
        fi
        notify-send "Phone display" "Disconnected"
      }

      start() {
        before=$(hyprctl -j monitors | jq -r '.[].name' | sort)
        hyprctl output create headless >/dev/null
        sleep 0.3
        after=$(hyprctl -j monitors | jq -r '.[].name' | sort)
        new_output=$(comm -13 <(echo "$before") <(echo "$after") | head -1)

        if [ -z "$new_output" ]; then
          notify-send -u critical "Phone display" "Failed to create headless output"
          exit 1
        fi
        echo "$new_output" > "$outfile"

        # Portrait 1080x1920 @ 60Hz, placed automatically next to existing monitors.
        hyprctl keyword monitor "$new_output,1080x1920@60,auto,1" >/dev/null

        ip=$(ip -4 -o addr show scope global | awk '{print $4}' | cut -d/ -f1 | head -1)

        # --disable-input: view-only. The phone is an extra display, never a
        # control surface — and the listener is unauthenticated on the LAN, so
        # refusing all remote keyboard/mouse means a stray connection can look
        # but never touch.
        wayvnc --disable-input --output="$new_output" 0.0.0.0 5900 >/dev/null 2>&1 &
        echo $! > "$pidfile"

        # Advertise as a discoverable VNC server so phone clients find it via scan.
        avahi-publish-service "$(hostname) phone display" _rfb._tcp 5900 >/dev/null 2>&1 &
        echo $! > "$avahi_pidfile"

        notify-send "Phone display" "VNC on ''${ip:-<no-ip>}:5900"
      }

      if is_running; then
        stop
      else
        start
      fi
    '';
  };
in
{
  home.packages = [ phoneDisplayToggle ];

  wayland.windowManager.hyprland.settings."$phoneDisplay" =
    "${phoneDisplayToggle}/bin/phone-display-toggle";
}
