# Plans a monitor layout and applies it without ever passing through an
# overlapping arrangement.
#
# Hyprland validates the whole layout after every `keyword monitor`, so moving
# outputs one at a time makes it complain once per intermediate step even when
# the final layout is fine. Rotating one screen used to emit six of those
# notifications. Everything below exists to emit zero.
#
# Two state directories feed it, one file per output, and neither holds any
# geometry of its own:
#
#   ~/.local/state/monitor-transforms/<name>   a Hyprland transform, 0 or 3
#   ~/.local/state/monitor-modes/<name>        a mode and an optional scale,
#                                              e.g. "3840x2160@144.00 2"
#
# Apparent size is a SCALE, not a smaller mode. A fixed-pixel panel interpolates
# anything that is not a whole-number mapping onto its own grid, so sending it
# 2560x1440 makes its scaler stretch by 1.5 and every second pixel lands split
# across two physical ones. Driving it natively at scale 2 instead asks the
# compositor for a 1920x1080 logical desktop rendered into 3840x2160 real
# pixels: same apparent size, full glyph detail, no scaler in the path at all.
#
# Hence the rule enforced in target_scale: the scale must be a whole number that
# divides the mode into whole logical pixels. Fractional scales are refused even
# when the arithmetic comes out even (1920/1.5 = 1280), because XWayland cannot
# follow a fractional scale — that is the dark seam Steam wore for a fortnight,
# documented in hosts/<h>/hardware/displays.nix.
#
# An absent transform file means "whatever is live". An absent MODE file means
# the mode declared in hosts/<h>/hardware/displays.nix, handed in as a JSON map
# via $MONITOR_CEILINGS: that declaration is a ceiling, not a resting value, and
# resetting an output means deleting its state file, so falling back to the live
# mode instead would pin whatever happened to be on screen and make the reset
# path a no-op. An output nobody declared falls back to live.
#
# The computed layout is also written to ~/.config/hypr/monitors.conf, which
# hyprland.conf sources after its own `monitor=` lines. Without that file a
# rebuild would assert the declared ceiling, and the socket2 watcher would then
# have to drag every output back to the runtime mode — two modesets and a
# visible reshuffle on every rebuild, forever, now that the two are expected to
# differ. With it, a config reload lands on the runtime layout inside the same
# pass and there is nothing left to correct.

import json, os, subprocess, sys, time

CONFIG_HOME = os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config")
STATE_HOME = os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state")

TRANSFORMS = os.path.join(STATE_HOME, "monitor-transforms")
MODES = os.path.join(STATE_HOME, "monitor-modes")
OVERRIDE = os.path.join(CONFIG_HOME, "hypr", "monitors.conf")


def ceilings():
    """{ "<name>": { "mode": "3840x2160@144", "scale": "1" } }, from displays.nix.

    The mode is that output's maximum and the scale its resting one; together
    they are what an output with no state file is driven at."""
    path = os.environ.get("MONITOR_CEILINGS")
    if not path:
        return {}
    try:
        with open(path) as fh:
            return json.load(fh)
    except (OSError, ValueError):
        return {}


CEILINGS = ceilings()


def declared(name, field):
    entry = CEILINGS.get(name)
    return entry.get(field) if isinstance(entry, dict) else None

# Gap between modesets. Long enough for the DRM page-flip to retire,
# short enough that a rotation still feels immediate.
SETTLE = 0.15
ROTATED = (1, 3, 5, 7)


def monitors():
    out = subprocess.run(["hyprctl", "-j", "monitors"],
                         capture_output=True, text=True, check=True).stdout
    return sorted(json.loads(out), key=lambda m: m["x"])


def target_transform(m):
    """Persisted transform wins; otherwise leave the monitor as it is."""
    path = os.path.join(TRANSFORMS, m["name"])
    try:
        with open(path) as fh:
            return int(fh.read().strip())
    except (OSError, ValueError):
        return m["transform"]


def live_mode(m):
    return (m["width"], m["height"], "%d" % round(float(m["refreshRate"])))


def mode_key(mode):
    """Comparable form. The live refresh rate is 143.99899 where the mode list
    calls the same mode 144.00 and displays.nix calls it 144, so modes are only
    ever compared — and matched — rounded."""
    w, h, refresh = mode
    return (w, h, round(float(refresh)))


def parse_mode(s):
    try:
        res, refresh = s.split("@", 1)
        w, h = res.split("x", 1)
        return (int(w), int(h), refresh)
    except ValueError:
        return None


def resolve(m, want):
    """The canonical availableModes entry matching `want`, or None.

    Everything that names a mode is run through here, because a mode the output
    cannot do would be refused and leave the rest of the layout applied around a
    monitor that never changed size. That covers a hand-edited state file and a
    declaration that no longer matches the panel alike."""
    if not want:
        return None
    key = parse_mode(want)
    if not key:
        return None
    key = mode_key(key)

    for s in m.get("availableModes", []):
        cand = parse_mode(s[:-2] if s.endswith("Hz") else s)
        if cand and mode_key(cand) == key:
            return cand
    return None


def persisted(m):
    """The state file split into (mode, scale); either may be absent.

    One file, two whitespace-separated fields, because they are one decision:
    "show this output at this apparent size" is a mode AND a scale, and applying
    half of it would drive the panel at a size nobody asked for."""
    try:
        with open(os.path.join(MODES, m["name"])) as fh:
            fields = fh.read().split()
    except OSError:
        return (None, None)
    return (fields[0] if fields else None,
            fields[1] if len(fields) > 1 else None)


def target_mode(m):
    """Runtime choice, else the declared ceiling, else whatever is live."""
    for want in (persisted(m)[0], declared(m["name"], "mode")):
        got = resolve(m, want)
        if got:
            return got
    return live_mode(m)


def target_scale(m, mode):
    """Whole-number scales only, and only ones that divide this mode evenly.

    Everything else is refused in favour of 1. A fractional scale is refused
    because XWayland cannot follow one; a scale that leaves a fractional logical
    size is refused because Hyprland then rounds the logical geometry and hands
    surfaces buffers a pixel short, which is the same defect by another name.
    Refusing to 1 is always safe: it is the panel's own grid."""
    w, h, _ = mode
    for want in (persisted(m)[1], declared(m["name"], "scale")):
        if want is None:
            continue
        try:
            value = float(want)
        except ValueError:
            continue
        if value < 1 or value != int(value):
            continue
        n = int(value)
        if w % n or h % n:
            continue
        return n
    return 1


def eff_width(mode, transform, scale):
    w, h, _ = mode
    px = h if transform in ROTATED else w
    return round(px / scale)


def plan(mons):
    """Final layout: packed left to right by effective width, y untouched."""
    x = 0
    final = {}
    for m in mons:
        t = target_transform(m)
        mode = target_mode(m)
        scale = target_scale(m, mode)
        w = eff_width(mode, t, scale)
        final[m["name"]] = {"x": x, "w": w, "transform": t,
                            "mode": mode, "scale": scale}
        x += w
    return final


def overlaps(a0, aw, b0, bw):
    return a0 < b0 + bw and b0 < a0 + aw


def order(mons, final):
    """Emit placements such that each one lands clear of every monitor that
    has not moved yet. Monitors already placed sit at final positions, which
    are mutually exclusive by construction, so only the unplaced matter.

    Monitors that are already where they belong are dropped entirely rather
    than re-issued. Every `keyword monitor` is a DRM modeset, and firing three
    of them back to back makes aquamarine log "Cannot commit when a page-flip
    is awaiting" and occasionally drop one — so a single rotation should touch
    one output, not all of them."""
    cur = {m["name"]: {"x": m["x"],
                       "w": eff_width(live_mode(m), m["transform"], m["scale"])}
           for m in mons}

    remaining = [m["name"] for m in mons
                 if m["x"] != final[m["name"]]["x"]
                 or m["transform"] != final[m["name"]]["transform"]
                 or mode_key(live_mode(m)) != mode_key(final[m["name"]]["mode"])
                 or float(m["scale"]) != float(final[m["name"]]["scale"])]
    steps = []

    while remaining:
        for name in remaining:
            f = final[name]
            if not any(overlaps(f["x"], f["w"], cur[o]["x"], cur[o]["w"])
                       for o in remaining if o != name):
                steps.append((name, f["x"]))
                cur[name] = {"x": f["x"], "w": f["w"]}
                remaining.remove(name)
                break
        else:
            # Every candidate is blocked by another that has not moved — a
            # cycle. Park one far to the right, which is always clear, and
            # let the loop place the rest around it.
            park = max(c["x"] + c["w"] for c in cur.values()) + 2000
            name = remaining[0]
            steps.append((name, park))
            cur[name] = {"x": park, "w": final[name]["w"]}
    return steps


def spec(m, x, f):
    w, h, refresh = f["mode"]
    return (f"{m['name']},{w}x{h}@{refresh},"
            f"{x}x{m['y']},{f['scale']},transform,{f['transform']}")


def write_override(mons, final):
    """The whole resting layout, not the delta applied above.

    Hyprland reads this on every reload, so a partial file would leave the
    outputs it omits sitting at their declared ceiling. Only connected outputs
    appear at all, which is what keeps a shut lid working: eDP-1 is absent
    here, so nothing countermands the `monitor=eDP-1,disable` that lid.conf
    sources after this file."""
    by_name = {m["name"]: m for m in mons}
    lines = [
        "# Written by reflow-monitors. Sourced from hyprland.conf AFTER the",
        "# declared monitor lines, so a runtime mode or rotation survives a",
        "# config reload without a second modeset correcting it. Do not edit:",
        "# ~/.local/state/monitor-{modes,transforms}/ is the source of truth.",
        "",
    ]
    for name in sorted(final, key=lambda n: final[n]["x"]):
        f = final[name]
        lines.append("monitor=" + spec(by_name[name], f["x"], f))

    os.makedirs(os.path.dirname(OVERRIDE), exist_ok=True)
    tmp = OVERRIDE + ".tmp"
    with open(tmp, "w") as fh:
        fh.write("\n".join(lines) + "\n")
    os.replace(tmp, OVERRIDE)


def main():
    mons = monitors()
    if not mons:
        return
    by_name = {m["name"]: m for m in mons}
    final = plan(mons)

    specs = [spec(by_name[name], x, final[name])
             for name, x in order(mons, final)]

    if "--print" in sys.argv:
        print("\n".join(specs) if specs else "(layout already correct, nothing to do)")
        return

    # Unconditional, and before the modesets. The file describes the resting
    # layout, which is worth recording even on the run where nothing moved —
    # that is exactly the run after a rebuild reset it.
    write_override(mons, final)

    # One at a time, not `hyprctl --batch`.
    #
    # Batching is not what keeps Hyprland quiet — the ordering above is, and it
    # holds whether the commands arrive together or apart. What batching did do
    # was fire every modeset within the same frame, which aquamarine answers
    # with "Cannot commit when a page-flip is awaiting"; the output that lost
    # the race kept displaying its old contents at its new geometry, so half of
    # it went black until something forced a repaint. Taking a screenshot was
    # enough to force one, which is what made the bug look like it fixed itself.
    for i, sp in enumerate(specs):
        if i:
            time.sleep(SETTLE)
        subprocess.run(["hyprctl", "keyword", "monitor", sp],
                       stdout=subprocess.DEVNULL, check=False)

    if specs:
        # Belt and braces for the same failure: repaint every output once the
        # geometry has settled, rather than relying on the next damage event.
        time.sleep(SETTLE)
        subprocess.run(["hyprctl", "dispatch", "forcerendererreload"],
                       stdout=subprocess.DEVNULL, check=False)


main()
