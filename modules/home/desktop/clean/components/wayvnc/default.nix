{ pkgs, ... }:

# Phone-as-extended-display via wayvnc + Hyprland headless output.
# Toggle ($mod+V, or the bar widget): first press creates a virtual monitor
# and starts wayvnc on 0.0.0.0:5900 bound to it; second press kills wayvnc
# and removes the monitor.
#
# No auth, and view-only (--disable-input) — the phone is a second screen,
# never a control surface, so a stray connection can look but never touch.
#
# Reaching it from the phone, in order of preference:
#   1. The tailnet IP. This is the path that works on *any* network. Wi-Fi
#      with AP/client isolation (hotel, café, guest SSIDs, and this house's
#      own Plume pods) silently drops phone->laptop unicast, so the LAN IP
#      is a coin flip. Tailscale doesn't care: "any device that can open an
#      HTTPS connection to an arbitrary host can build a tunnel using DERP
#      relays". Needs the Tailscale app on the phone.
#   2. The LAN IP, when the network happens to allow client-to-client.
# Both are printed in the notification, tailnet first.
#
# Resolution is NOT the phone's problem to match here. wayvnc's automatic
# resizing is on by default and Hyprland exposes zwlr_output_manager_v1, so
# a client advertising the ExtendedDesktopSize pseudo-encoding resizes the
# headless output to its own screen on connect (verified: a 720x1600 request
# moved HEADLESS-3 to exactly 720x1600). The values below are only the size
# the output holds before the first client arrives.
#
# Landscape: the phone is held sideways as a second screen, so a portrait
# default meant every connection started rotated a quarter turn.

let
  phoneDisplayToggle = pkgs.writeShellApplication {
    name = "phone-display-toggle";
    runtimeInputs = with pkgs; [
      wayvnc hyprland jq iproute2 libnotify coreutils tailscale gnugrep
    ];
    text = ''
      # Pre-connection size only; the client resizes this on connect.
      width=1920
      height=1080
      scale=2

      state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/phone-display"
      mkdir -p "$state_dir"
      pidfile="$state_dir/wayvnc.pid"
      outfile="$state_dir/output.name"
      logfile="$state_dir/wayvnc.log"

      is_running() {
        [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile" 2>/dev/null)" 2>/dev/null
      }

      mon_size() {
        hyprctl -j monitors | jq -r --arg n "$1" \
          '.[] | select(.name == $n) | "\(.width)x\(.height)"'
      }

      outputs() { hyprctl -j monitors | jq -r '.[].name' | sort; }

      # Tear down the monitor even if wayvnc already died on its own,
      # otherwise a failed start leaves an orphan headless output behind.
      stop() {
        if is_running; then
          kill "$(cat "$pidfile")" 2>/dev/null || true
        fi
        rm -f "$pidfile"
        if [ -f "$outfile" ]; then
          hyprctl output remove "$(cat "$outfile")" >/dev/null 2>&1 || true
          rm -f "$outfile"
        fi
        notify-send "Phone display" "Disconnected"
      }

      start() {
        before=$(outputs)
        hyprctl output create headless >/dev/null

        # Poll for the new output rather than sleeping a guessed interval.
        new_output=""
        for _ in $(seq 1 20); do
          new_output=$(comm -13 <(echo "$before") <(outputs) | head -1)
          [ -n "$new_output" ] && break
          sleep 0.1
        done

        if [ -z "$new_output" ]; then
          notify-send -u critical "Phone display" "Failed to create headless output"
          exit 1
        fi
        echo "$new_output" > "$outfile"

        # `hyprctl keyword monitor` returns ok but intermittently does not
        # apply when it lands too soon after the output is created — the
        # monitor stays at its default landscape size. Re-assert until the
        # size we asked for is the size Hyprland reports.
        want="''${width}x''${height}"
        for _ in $(seq 1 10); do
          hyprctl keyword monitor "$new_output,''${want}@60,auto,$scale" >/dev/null
          sleep 0.3
          [ "$(mon_size "$new_output")" = "$want" ] && break
        done

        if [ "$(mon_size "$new_output")" != "$want" ]; then
          notify-send -u critical "Phone display" \
            "Output stuck at $(mon_size "$new_output"), wanted $want"
          stop
          exit 1
        fi

        # Give the headless output its own named workspace rather than letting
        # it eat a numbered one. Named workspaces live in a separate id space
        # (this lands on -1337) and render with no number, so the phone screen
        # never consumes a slot out of 1-10. Creating a workspace on a monitor
        # requires focusing that monitor, so focus is handed straight back in
        # the same batch -- one atomic hyprctl call, no visible detour.
        prev_mon=$(hyprctl -j monitors | jq -r '.[] | select(.focused) | .name')
        hyprctl --batch "dispatch focusmonitor $new_output ; \
                         dispatch workspace name:phone ; \
                         dispatch focusmonitor ''${prev_mon:-$new_output}" >/dev/null

        # Keep the log. The previous version sent wayvnc to /dev/null, which
        # is why a failed start produced no evidence at all.
        wayvnc -L info --disable-input --output="$new_output" 0.0.0.0 5900 \
          > "$logfile" 2>&1 &
        echo $! > "$pidfile"

        listening=false
        for _ in $(seq 1 25); do
          if ss -ltn 2>/dev/null | grep -q ':5900 '; then listening=true; break; fi
          is_running || break
          sleep 0.2
        done

        if [ "$listening" != true ]; then
          notify-send -u critical "Phone display" \
            "wayvnc failed to listen — see $logfile"
          stop
          exit 1
        fi

        ts=$(tailscale ip -4 2>/dev/null | head -1 || true)
        lan=$(ip -4 -o addr show scope global up \
              | awk '$2 != "tailscale0" { print $4 }' \
              | cut -d/ -f1 | head -1 || true)

        notify-send "Phone display" \
          "tailnet ''${ts:-unavailable}:5900''\n''${lan:+lan $lan:5900}"
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
