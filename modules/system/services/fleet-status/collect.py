#!/usr/bin/env python3
"""fleet-status collector — one machine's state, as JSON, once every 30s.

Runs as root on a timer and writes $FS_OUT. Nothing in here ever reads a
network request: the file is handed out by a separate unprivileged unit
(serve.py), so the privilege needed to list another user's systemd units and
read syncthing's API key never sits behind a socket. Root collects; nobody
serves.

Every section is wrapped. A probe that raises records {"error": "..."} rather
than taking the whole report down with it, because a dashboard has to tell
"nothing is wrong" apart from "nobody asked" — and a section that simply
vanished would read as the first one.

Times are unix seconds, sizes are bytes. No formatting happens here; the page
that draws this knows what a human wants better than the box does.
"""
import json
import os
import re
import socket
import subprocess
import time
import urllib.error
import urllib.request
from pathlib import Path

OUT = Path(os.environ.get("FS_OUT", "/var/lib/fleet-status/status.json"))
# Which app units to knock on over HTTP, as {name: port}. The app platform
# fills this in; a host without apps gets an empty dict and reports none.
PROBES = json.loads(os.environ.get("FS_PROBES", "{}"))
# Whose syncthing to ask about. Empty on a server, which has none.
SYNC_USER = os.environ.get("FS_SYNC_USER", "")

# Real filesystems only. tmpfs, devtmpfs, overlay and the rest are either RAM
# or a view of something already counted, and a dashboard that reported /dev/shm
# at 0% would be padding itself with numbers nobody can act on.
REAL_FS = {"ext2", "ext3", "ext4", "btrfs", "xfs", "zfs", "f2fs", "vfat", "ntfs"}


def guard(fn, *a, **kw):
    """Run a probe; return its value or {"error": ...}. Never raises."""
    try:
        return fn(*a, **kw)
    except Exception as e:                               # noqa: BLE001
        return {"error": f"{type(e).__name__}: {e}"}


def run(*argv, timeout=10):
    return subprocess.run(argv, capture_output=True, text=True,
                          timeout=timeout, check=False).stdout


# ------------------------------------------------------------------ the box

def boot():
    with open("/proc/uptime") as f:
        up = float(f.read().split()[0])
    with open("/proc/loadavg") as f:
        load = [float(x) for x in f.read().split()[:3]]
    return {
        "uptime": int(up),
        "kernel": os.uname().release,
        "load": load,
        "cpus": os.cpu_count(),
    }


def memory():
    vals = {}
    with open("/proc/meminfo") as f:
        for line in f:
            k, _, v = line.partition(":")
            vals[k] = int(v.split()[0]) * 1024          # kB in the file
    total = vals["MemTotal"]
    avail = vals["MemAvailable"]
    swap_total = vals.get("SwapTotal", 0)
    return {
        "total": total,
        "used": total - avail,
        "swap_total": swap_total,
        "swap_used": swap_total - vals.get("SwapFree", 0),
    }


def disks():
    out, seen = [], set()
    with open("/proc/mounts") as f:
        for line in f:
            dev, mount, fstype = line.split()[:3]
            if fstype not in REAL_FS or dev in seen:
                continue
            # /nix/store is a bind of / on this fleet: same device, already
            # counted, and listing it twice would read as twice the disk.
            seen.add(dev)
            try:
                s = os.statvfs(mount)
            except OSError:
                continue
            total = s.f_blocks * s.f_frsize
            if total == 0:
                continue
            out.append({
                "mount": mount,
                "fstype": fstype,
                "total": total,
                # f_bavail, not f_bfree: the reserved blocks are not yours.
                "used": total - s.f_bavail * s.f_frsize,
            })
    return sorted(out, key=lambda d: d["mount"])


# Comparing /run/booted-system to /run/current-system outright would flag a
# reboot after *every* rebuild, including the ones that only moved a config
# file — a warning that is always on is a warning nobody reads. These four are
# the parts a running kernel cannot be swapped out from under, and comparing
# only them is what `nixos-needsreboot` and the NixOS wiki both do.
REBOOT_PARTS = ["kernel", "kernel-modules", "initrd", "systemd"]


def generation():
    """Which system is running, and whether a reboot is genuinely owed."""
    link = Path("/nix/var/nix/profiles/system")
    target = os.readlink(link)                            # system-478-link
    n = re.search(r"system-(\d+)-link", target)

    def parts(root):
        return [os.path.realpath(f"{root}/{p}") for p in REBOOT_PARTS]

    current = os.path.realpath("/run/current-system")
    return {
        "number": int(n.group(1)) if n else None,
        "built": int(link.lstat().st_mtime),
        "reboot_pending": parts("/run/booted-system") != parts(current),
        # A trebuild is a `test` activation: it switches current-system without
        # touching the profile, so the running system belongs to no generation.
        "untracked": os.path.realpath(link) != current,
    }


# --------------------------------------------------------------------- units

def units_json(*patterns):
    raw = run("systemctl", "list-units", "--all", "--output=json", *patterns)
    return json.loads(raw) if raw.strip() else []


def show(unit, *props):
    """systemctl show as a dict. Timestamps come back as @<unix seconds>."""
    raw = run("systemctl", "show", unit, "--timestamp=unix",
              *[f"--property={p}" for p in props])
    out = {}
    for line in raw.splitlines():
        k, _, v = line.partition("=")
        out[k] = v
    return out


def stamp(v):
    """'@1789898772' -> 1789898772. Anything else (n/a, 0, empty) -> None."""
    if not v or not v.startswith("@"):
        return None
    return int(v[1:]) or None


def health():
    """The catch-all. Everything that is wrong on this box, whatever it is."""
    failed = [u["unit"] for u in units_json("--failed")]
    return {
        "state": run("systemctl", "is-system-running").strip() or "unknown",
        "failed": sorted(failed),
    }


def backups():
    """Every restic job on this host, and when it last worked.

    A host with no jobs returns an empty list, which the page draws as "not
    configured" — not as green. home-server has no backups at all, and a
    dashboard that painted that the same colour as a successful one would be
    lying in the most expensive direction.
    """
    out = []
    # Both shapes of job. A `restic-backups-*` unit reads this machine's own
    # files; a `restic-fanout-*` unit copies an already-made backup out to a
    # further destination. They fail differently and a page that showed only
    # the first would call a fleet healthy while a whole destination had gone
    # quiet.
    for u in units_json("restic-backups-*.service", "restic-fanout-*.service"):
        name = u["unit"]
        fanout = name.startswith("restic-fanout-")
        # InactiveExitTimestamp, not ActiveEnterTimestamp: a Type=oneshot
        # unit never records entering active, so that property comes back
        # empty and every duration reads as unknown. This one is the moment
        # the unit left idle, which includes the ExecStartPre.
        s = show(name, "Result", "ExecMainStatus", "ActiveState",
                 "InactiveEnterTimestamp", "InactiveExitTimestamp")
        t = show(name[:-len(".service")] + ".timer",
                 "NextElapseUSecRealtime", "LastTriggerUSec")
        started = stamp(s.get("InactiveExitTimestamp"))
        ended = stamp(s.get("InactiveEnterTimestamp"))
        prefix = "restic-fanout-" if fanout else "restic-backups-"
        out.append({
            "unit": name,
            "job": name[len(prefix):-len(".service")],
            "kind": "copy" if fanout else "backup",
            "running": s.get("ActiveState") == "active",
            "result": s.get("Result", "unknown"),
            "exit": s.get("ExecMainStatus"),
            "last": ended,
            # Only meaningful once the run has ended; a job still going has no
            # duration yet, and reporting one would be inventing it.
            "duration": (ended - started) if (ended and started
                                              and ended >= started) else None,
            "next": stamp(t.get("NextElapseUSecRealtime")),
        })
    return sorted(out, key=lambda b: (b["kind"], b["job"]))


def services():
    """The units worth a tile even when they are fine.

    Anything broken is already in health.failed; this is the short list whose
    *absence* would be the news — the tunnel that publishes the URLs, the mesh
    every hostname resolves through, the sync daemon.
    """
    out = []
    for u in units_json("cloudflared-*.service", "tailscaled.service",
                        "syncthing.service", "sshd.service", "cups.service"):
        if u["load"] == "not-found":
            continue
        out.append({
            "unit": u["unit"],
            "active": u["active"],
            "sub": u["sub"],
            "description": u["description"],
        })
    return sorted(out, key=lambda s: s["unit"])


# ---------------------------------------------------------------- the extras

def probe(port):
    """Knock on a local app. Any HTTP answer means it is alive.

    These all sit behind a login, so 401 and 303 are healthy replies — the
    question is whether something is listening and speaking HTTP, not whether
    it will let an unauthenticated collector in. Only a refused connection or
    a timeout is a failure.
    """
    url = f"http://127.0.0.1:{port}/"
    started = time.monotonic()
    try:
        with urllib.request.urlopen(url, timeout=4) as r:
            code = r.status
    except urllib.error.HTTPError as e:
        code = e.code
    except Exception as e:                               # noqa: BLE001
        return {"up": False, "error": f"{type(e).__name__}: {e}"}
    return {"up": True, "code": code,
            "ms": int((time.monotonic() - started) * 1000)}


def apps():
    return [dict(name=n, port=p, **probe(p)) for n, p in sorted(PROBES.items())]


def syncthing():
    """Folder completion per device, and who is actually connected.

    The API key is read out of the user's config rather than configured
    anywhere: syncthing generates it on first run, so the config file is the
    only place it exists, and a copy in the Nix store would be both a secret in
    a world-readable path and wrong the moment syncthing rotated it.
    """
    if not SYNC_USER:
        return None
    cfg = Path(f"/home/{SYNC_USER}/.config/syncthing/config.xml")
    if not cfg.exists():
        return None
    text = cfg.read_text()
    key = re.search(r"<apikey>([^<]+)</apikey>", text)
    gui = re.search(r"<gui[^>]*>.*?<address>([^<]+)</address>", text, re.S)
    if not key or not gui:
        return {"error": "no apikey or gui address in config.xml"}

    def api(path):
        req = urllib.request.Request(f"http://{gui.group(1)}{path}",
                                     headers={"X-API-Key": key.group(1)})
        with urllib.request.urlopen(req, timeout=5) as r:
            return json.load(r)

    names = {d.group(1): d.group(2) for d in
             re.finditer(r'<device id="([^"]+)" name="([^"]+)"', text)}
    conns = api("/rest/system/connections")["connections"]
    devices = [{
        "id": did,
        "name": names.get(did, did[:7]),
        "connected": c.get("connected", False),
        "paused": c.get("paused", False),
        "at": c.get("at", ""),
        "address": c.get("address", ""),
    } for did, c in conns.items() if did in names]

    folders = []
    for f in re.finditer(r'<folder id="([^"]+)"[^>]*label="([^"]*)"', text):
        fid, label = f.group(1), f.group(2)
        # Asking without a device is the aggregate across all of them, which
        # is the number the page leads with.
        c = api(f"/rest/db/completion?folder={fid}")
        folders.append({
            "id": fid,
            "label": label or fid,
            "completion": round(c.get("completion", 0), 1),
            "need_bytes": c.get("needBytes", 0),
            "need_items": c.get("needItems", 0),
            "global_bytes": c.get("globalBytes", 0),
            "peers": [{
                "device": names.get(d["id"], d["id"][:7]),
                # A phone sitting at 0 is almost always a folder the phone has
                # not accepted yet, not a stalled sync. The page says so.
                "completion": round(api(
                    f"/rest/db/completion?folder={fid}&device={d['id']}"
                ).get("completion", 0), 1),
            } for d in devices],
        })
    return {"devices": sorted(devices, key=lambda d: d["name"]),
            "folders": sorted(folders, key=lambda f: f["label"])}


def tailnet():
    raw = run("tailscale", "status", "--json", timeout=8)
    if not raw.strip():
        return {"error": "tailscale status returned nothing"}
    s = json.loads(raw)
    peers = [{
        "name": p["HostName"],
        "online": p.get("Online", False),
        "os": p.get("OS", ""),
        "last_seen": p.get("LastSeen", ""),
        "rx": p.get("RxBytes", 0),
        "tx": p.get("TxBytes", 0),
    } for p in (s.get("Peer") or {}).values()]
    return {
        "state": s.get("BackendState", "unknown"),
        "self": (s.get("Self") or {}).get("HostName", ""),
        "peers": sorted(peers, key=lambda p: p["name"]),
    }


def main():
    report = {
        "host": socket.gethostname(),
        "collected": int(time.time()),
        "boot": guard(boot),
        "memory": guard(memory),
        "disks": guard(disks),
        "generation": guard(generation),
        "health": guard(health),
        "backups": guard(backups),
        "services": guard(services),
        "apps": guard(apps),
        "syncthing": guard(syncthing),
        "tailnet": guard(tailnet),
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    tmp = OUT.with_suffix(".tmp")
    # Written whole and moved into place: the server reads this file on a
    # request, and a half-written one would be a parse error on the page rather
    # than a stale number.
    tmp.write_text(json.dumps(report, separators=(",", ":")))
    os.chmod(tmp, 0o644)
    os.replace(tmp, OUT)


if __name__ == "__main__":
    main()
