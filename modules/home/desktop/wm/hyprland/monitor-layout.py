# Plans a monitor layout and applies it without ever passing through an
# overlapping arrangement.
#
# Hyprland validates the whole layout after every `keyword monitor`, so moving
# outputs one at a time makes it complain once per intermediate step even when
# the final layout is fine. Rotating one screen used to emit six of those
# notifications. Everything below exists to emit zero.

import json, subprocess, sys, os

STATE = os.path.expanduser("~/.local/state/monitor-transforms")
ROTATED = (1, 3, 5, 7)


def monitors():
    out = subprocess.run(["hyprctl", "-j", "monitors"],
                         capture_output=True, text=True, check=True).stdout
    return sorted(json.loads(out), key=lambda m: m["x"])


def target_transform(m):
    """Persisted transform wins; otherwise leave the monitor as it is."""
    path = os.path.join(STATE, m["name"])
    try:
        with open(path) as fh:
            return int(fh.read().strip())
    except (OSError, ValueError):
        return m["transform"]


def eff_width(m, transform):
    px = m["height"] if transform in ROTATED else m["width"]
    return round(px / m["scale"])


def plan(mons):
    """Final layout: packed left to right by effective width, y untouched."""
    x = 0
    final = {}
    for m in mons:
        t = target_transform(m)
        w = eff_width(m, t)
        final[m["name"]] = {"x": x, "w": w, "transform": t}
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
    cur = {m["name"]: {"x": m["x"], "w": eff_width(m, m["transform"])} for m in mons}

    remaining = [m["name"] for m in mons
                 if m["x"] != final[m["name"]]["x"]
                 or m["transform"] != final[m["name"]]["transform"]]
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


def keyword(m, x, transform):
    rr = round(float(m["refreshRate"]))
    return (f"keyword monitor {m['name']},{m['width']}x{m['height']}@{rr},"
            f"{x}x{m['y']},{m['scale']},transform,{transform}")


def main():
    mons = monitors()
    if not mons:
        return
    by_name = {m["name"]: m for m in mons}
    final = plan(mons)

    cmds = [keyword(by_name[name], x, final[name]["transform"])
            for name, x in order(mons, final)]

    # One connection, one pass. Still validated per command by Hyprland, which
    # is exactly why the order above matters.
    subprocess.run(["hyprctl", "--batch", " ; ".join(cmds)],
                   stdout=subprocess.DEVNULL, check=False)

    if "--print" in sys.argv:
        print("\n".join(cmds) if cmds else "(layout already correct, nothing to do)")


main()
