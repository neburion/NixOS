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


def cache_read(name, ttl):
    """A previous answer, if it is younger than ttl seconds. Else None."""
    p = OUT.parent / f"{name}.json"
    try:
        blob = json.loads(p.read_text())
    except Exception:                                    # noqa: BLE001
        return None
    if time.time() - blob.get("at", 0) > ttl:
        return None
    return blob.get("value")


def cache_write(name, value):
    p = OUT.parent / f"{name}.json"
    tmp = p.with_suffix(".tmp")
    tmp.write_text(json.dumps({"at": int(time.time()), "value": value},
                              separators=(",", ":")))
    os.replace(tmp, p)
    return value


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
    """The mesh as this host sees it, from the local daemon.

    No API token anywhere. Tailscale's control plane has one, but every fact
    the page draws — who is up, which addresses they answer on, when each node
    key expires — is already in `tailscale status` on each box, and asking the
    boxes keeps the tailnet's own credentials out of a published dashboard.

    What a token would add and this cannot: ACLs, DNS settings, and devices
    that are in the tailnet but not talking to this host.
    """
    raw = run("tailscale", "status", "--json", timeout=8)
    if not raw.strip():
        return {"error": "tailscale status returned nothing"}
    s = json.loads(raw)

    def node(p, me=False):
        return {
            "name": p.get("HostName", ""),
            # The trailing dot is how MagicDNS spells it and not how anyone
            # reads it.
            "dns": (p.get("DNSName") or "").rstrip("."),
            "ips": p.get("TailscaleIPs") or [],
            "os": p.get("OS", ""),
            "online": p.get("Online", False),
            # Online says the node is reachable; active says traffic is moving
            # right now. A phone is usually the first and rarely the second.
            "active": p.get("Active", False),
            "last_seen": p.get("LastSeen", ""),
            # The one number on this page with a deadline attached: an expired
            # node key drops a host off the mesh with no other warning.
            "key_expiry": p.get("KeyExpiry", ""),
            "exit_node": p.get("ExitNode", False),
            "offers_exit": p.get("ExitNodeOption", False),
            "relay": p.get("Relay", ""),
            "rx": p.get("RxBytes", 0),
            "tx": p.get("TxBytes", 0),
            "self": me,
        }

    peers = [node(p) for p in (s.get("Peer") or {}).values()]
    return {
        "state": s.get("BackendState", "unknown"),
        "self": (s.get("Self") or {}).get("HostName", ""),
        "tailnet": (s.get("CurrentTailnet") or {}).get("Name", ""),
        "magic_dns": s.get("MagicDNSSuffix", ""),
        "version": (s.get("Version") or "").split("-")[0],
        "latest": (s.get("ClientVersion") or {}).get("RunningLatest"),
        "node": node(s.get("Self") or {}, me=True),
        "peers": sorted(peers, key=lambda p: p["name"]),
    }

def secrets():
    """Which credentials this machine holds, by name only.

    The dashboard's credential inventory is "what is deployed where", not a
    copy of the repo's secrets file — a host that never got a key should not
    appear to have one. Names are not secrets; the values sit 0400 root beside
    them and are never read here, which is why this can be reported at all.
    """
    d = Path("/run/secrets")
    if not d.is_dir():
        return []
    out = []
    for p in sorted(d.iterdir()):
        # sops-nix keeps its templated output under rendered/; those are files
        # built *from* secrets rather than secrets, and listing them would
        # double-count every key that feeds one.
        if p.name == "rendered" or p.is_dir():
            continue
        st = p.stat()
        out.append({
            "name": p.name,
            "mode": oct(st.st_mode & 0o777)[2:],
            "bytes": st.st_size,
            "modified": int(st.st_mtime),
        })
    return out


def b2():
    """The Backblaze bucket, read with the key this host already has.

    The dashboard never gets these credentials. It runs in public and the key
    on this box can delete files, so the call is made here — where the key
    already lives for restic's sake — and only the counts travel. Same split as
    the rest of the agent: root reads, nobody serves.

    Account-level numbers (storage caps, the bill) are deliberately absent:
    B2 publishes no billing API, and this key is scoped to the one bucket
    anyway. What the console shows about spend cannot be fetched by anyone.
    """
    key_id = Path("/run/secrets/backup-b2-aws-access-key-id")
    key = Path("/run/secrets/backup-b2-aws-secret-access-key")
    if not key_id.exists() or not key.exists():
        return None

    cached = cache_read("b2", 3600)
    if cached is not None:
        return cached

    import base64
    auth = base64.b64encode(
        f"{key_id.read_text().strip()}:{key.read_text().strip()}".encode()
    ).decode()

    def call(url, token, payload=None):
        req = urllib.request.Request(
            url,
            data=json.dumps(payload).encode() if payload is not None else None,
            headers={"Authorization": token,
                     "Content-Type": "application/json"},
        )
        with urllib.request.urlopen(req, timeout=20) as r:
            return json.loads(r.read())

    # v4, not v2 or v3: b2_authorize_account answers "not currently supported
    # on API version number N" for every earlier version now. The error looks
    # like a bad credential and is not one.
    a = call("https://api.backblazeb2.com/b2api/v4/b2_authorize_account",
             f"Basic {auth}")
    api = a["apiInfo"]["storageApi"]
    allowed = api["allowed"]
    token = a["authorizationToken"]
    buckets = allowed.get("buckets") or []
    if not buckets:
        return {"error": "key is not scoped to a bucket"}
    bucket = buckets[0]

    total, count, newest, oldest = 0, 0, 0, 0
    start = None
    # Paged rather than one big call: a restic repository is thousands of pack
    # files, and the page size is what keeps a single reply from being tens of
    # megabytes of filenames nobody draws.
    while True:
        page = call(f"{api['apiUrl']}/b2api/v4/b2_list_file_names", token,
                    {"bucketId": bucket["id"], "maxFileCount": 10000,
                     **({"startFileName": start} if start else {})})
        for f in page.get("files", []):
            total += f.get("contentLength", 0)
            count += 1
            ts = int(f.get("uploadTimestamp", 0) / 1000)
            newest = max(newest, ts)
            oldest = min(oldest or ts, ts)
        start = page.get("nextFileName")
        if not start:
            break

    lifecycle = call(f"{api['apiUrl']}/b2api/v4/b2_list_buckets", token,
                     {"accountId": a["accountId"], "bucketId": bucket["id"]})
    info = (lifecycle.get("buckets") or [{}])[0]

    return cache_write("b2", {
        "bucket": bucket["name"],
        "bytes": total,
        "objects": count,
        "newest": newest or None,
        "oldest": oldest or None,
        "type": info.get("bucketType"),
        "encryption": (info.get("defaultServerSideEncryption") or {}).get("mode"),
        "lifecycle": info.get("lifecycleRules") or [],
        "capabilities": allowed.get("capabilities") or [],
    })


# ----------------------------------------------------------------- the model

CLAUDE_HOME = os.environ.get("FS_CLAUDE_HOME", "")


def claude():
    """Claude Code usage, summed out of the transcripts it writes locally.

    There is no API for this. A subscription has no usage endpoint and no cost
    report — the Admin API covers organisations paying per token, which this is
    not — so the only account of what was spent is the JSONL Claude Code leaves
    under ~/.claude/projects. That is the same source its own stats view reads.

    Treat the totals as an estimate. The token counts come out of streaming
    metadata, and there are builds where they are known to be wrong; the page
    says so rather than printing them as a bill.

    Incremental on purpose: the transcripts are ~200MB and grow all day, so
    each file is remembered by size and only its new bytes are parsed. The
    fleet total is re-summed from the per-file records every run, which means a
    file that shrank or was rewritten corrects itself on the next pass instead
    of leaving a number nobody can explain.
    """
    if not CLAUDE_HOME:
        return None
    root = Path(CLAUDE_HOME) / "projects"
    if not root.is_dir():
        return None

    state_file = OUT.parent / "claude-files.json"
    try:
        known = json.loads(state_file.read_text())
    except Exception:                                    # noqa: BLE001
        known = {}

    def blank():
        return {"size": 0, "days": {}, "prompts": 0, "tools": 0,
                "sessions": 0, "first": None, "last": None}

    fresh = {}
    for path in sorted(root.rglob("*.jsonl")):
        key = str(path)
        size = path.stat().st_size
        prev = known.get(key)
        # Same size means the same file: these are append-only, so a byte count
        # that has not moved is a session nobody has spoken to since.
        if prev and prev.get("size") == size:
            fresh[key] = prev
            continue
        if prev and size > prev.get("size", 0):
            rec, offset = prev, prev["size"]   # grew: only the new bytes
        else:
            rec, offset = blank(), 0           # new, or rewritten shorter
        rec["sessions"] = 1
        seen = set()
        with path.open("r", errors="replace") as f:
            f.seek(offset)
            for line in f:
                try:
                    d = json.loads(line)
                except Exception:                        # noqa: BLE001
                    continue                             # a half-written tail
                t = d.get("type")
                if t == "user":
                    # A tool result is also a user-role message. Counting
                    # those as prompts would make a single question with
                    # forty greps look like forty questions.
                    body = (d.get("message") or {}).get("content")
                    if isinstance(body, str) or not any(
                        isinstance(b, dict) and b.get("type") == "tool_result"
                        for b in (body or [])
                    ):
                        rec["prompts"] += 1
                if t != "assistant":
                    continue
                m = d.get("message") or {}
                u = m.get("usage") or {}
                if not u:
                    continue
                # Claude Code fabricates an assistant turn for its own errors
                # and marks the model <synthetic>. It costs nothing and did
                # not happen; a row for it on the page is noise.
                if m.get("model") == "<synthetic>":
                    continue
                # One request can appear twice in a transcript when a turn is
                # retried; the request id is what the API counted once.
                rid = d.get("requestId") or m.get("id")
                if rid in seen:
                    continue
                seen.add(rid)
                day = (d.get("timestamp") or "")[:10]
                model = m.get("model") or "unknown"
                if not day:
                    continue
                rec["first"] = min(rec["first"] or day, day)
                rec["last"] = max(rec["last"] or "", day)
                bucket = rec["days"].setdefault(day, {}).setdefault(model, {
                    "input": 0, "output": 0, "cache_read": 0,
                    "cache_write": 0, "thinking": 0, "requests": 0,
                    "web_search": 0,
                })
                bucket["input"] += u.get("input_tokens", 0)
                bucket["output"] += u.get("output_tokens", 0)
                bucket["cache_read"] += u.get("cache_read_input_tokens", 0)
                bucket["cache_write"] += u.get("cache_creation_input_tokens", 0)
                bucket["thinking"] += (u.get("output_tokens_details") or {}).get(
                    "thinking_tokens", 0)
                bucket["web_search"] += (u.get("server_tool_use") or {}).get(
                    "web_search_requests", 0)
                bucket["requests"] += 1
                for blk in m.get("content") or []:
                    if isinstance(blk, dict) and blk.get("type") == "tool_use":
                        rec["tools"] += 1
        rec["size"] = size
        fresh[key] = rec

    tmp = state_file.with_suffix(".tmp")
    tmp.write_text(json.dumps(fresh, separators=(",", ":")))
    os.replace(tmp, state_file)

    days, models = {}, {}
    sessions = prompts = tools = 0
    first = last = None
    for rec in fresh.values():
        sessions += rec.get("sessions", 0)
        prompts += rec.get("prompts", 0)
        tools += rec.get("tools", 0)
        if rec.get("first"):
            first = min(first or rec["first"], rec["first"])
        if rec.get("last"):
            last = max(last or "", rec["last"])
        for day, per_model in rec["days"].items():
            for model, v in per_model.items():
                dst = days.setdefault(day, {}).setdefault(model, dict.fromkeys(v, 0))
                tot = models.setdefault(model, dict.fromkeys(v, 0))
                for k, n in v.items():
                    dst[k] += n
                    tot[k] += n

    return {
        # Trimmed to the window the page actually draws. The per-file records
        # keep everything; sending three months of days to a phone does not.
        "days": {d: days[d] for d in sorted(days)[-60:]},
        "models": models,
        "sessions": sessions,
        "prompts": prompts,
        "tools": tools,
        "first": first,
        "last": last,
        "source": "local transcripts",
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
        "secrets": guard(secrets),
        "b2": guard(b2),
        "claude": guard(claude),
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
