#!/usr/bin/env python3
"""Reading tracker — web server over the Reading-Ob Obsidian vault.

Stdlib only: no Flask, no pip, no database. `vault.py` is the storage layer and
the vault's markdown notes are the storage; this file is the HTTP surface over
it plus a cover-image cache.

    python3 app.py                    # http://127.0.0.1:8778, no auth
    python3 app.py --open
    python3 app.py --stats            # print the shelf and exit
    python3 app.py --warm-covers      # fetch every cover into the cache

Auth is HTTP Basic, enabled whenever a password is present (the systemd
credential 'password', or $RT_PASSWORD). Binding anything but loopback without
one is refused — see main().
"""
import argparse
import base64
import hmac
import json
import os
import re
import threading
import time
import unicodedata
import urllib.error
import urllib.request
import webbrowser
from collections import Counter, defaultdict, deque
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse, parse_qs

import vault as V

HERE = Path(__file__).resolve().parent
VAULT = Path(os.environ.get("RT_VAULT") or Path.home() / "Media/Books/Reading-Ob")
UI = Path(os.environ.get("RT_UI") or HERE / "ui.html")
FONTS = Path(os.environ["RT_FONTS"]) if os.environ.get("RT_FONTS") else None
CACHE = Path(os.environ.get("RT_CACHE") or HERE / ".cache")
DEFAULT_HOST = os.environ.get("RT_HOST", "127.0.0.1")
DEFAULT_PORT = int(os.environ.get("RT_PORT", "8778"))

# Presentation order, which is not alphabetical order: what you are reading now
# belongs at the top and what you gave up on belongs at the bottom.
STATUS_ORDER = ["Reading", "Later", "Hold", "Read", "Dropped"]
PUB_ORDER = ["Ongoing", "Hiatus", "Completed", "Cancelled", "Hold"]
TYPE_ORDER = ["Manhwa", "Manhua", "Manga", "Web Novel", "Indonesian Comic"]


# --------------------------------------------------------------------- auth
#
# Same shape as the Elden Ring tracker's gate, and for the same reason: this is
# reachable from other machines, every POST here edits files in a real vault,
# and one of them moves a note to the trash.

def _load_password():
    creds = os.environ.get("CREDENTIALS_DIRECTORY")
    if creds:
        p = Path(creds) / "password"
        if p.exists():
            return p.read_text().strip()
    return (os.environ.get("RT_PASSWORD") or "").strip()


PASSWORD = _load_password()
USERNAME = os.environ.get("RT_USERNAME", "reader")
AUTH_ON = bool(PASSWORD)

RATE_WINDOW = 3600
RATE_MAX = 20
_rate_lock = threading.Lock()
_failures = defaultdict(deque)


def _rate_ok(ip):
    now = time.time()
    with _rate_lock:
        q = _failures[ip]
        while q and now - q[0] > RATE_WINDOW:
            q.popleft()
        return len(q) < RATE_MAX


def check_auth(header, ip):
    """(ok, reason). Constant-time compare; never leaks which half was wrong."""
    if not AUTH_ON:
        return True, ""
    if not _rate_ok(ip):
        return False, "rate"
    if not header or not header.startswith("Basic "):
        return False, "missing"
    try:
        raw = base64.b64decode(header[6:]).decode("utf-8")
        user, _, pw = raw.partition(":")
    except Exception:
        with _rate_lock:
            _failures[ip].append(time.time())
        return False, "bad"
    if hmac.compare_digest(user, USERNAME) and hmac.compare_digest(pw, PASSWORD):
        return True, ""
    with _rate_lock:
        _failures[ip].append(time.time())
    return False, "bad"


# -------------------------------------------------------------------- index
#
# The vault is the database, so there is nothing to keep in sync — but re-reading
# 300 notes on every request is wasteful, and the fingerprint (one stat per
# note, well under a millisecond) tells us for free whether Obsidian, syncthing
# or our own last write touched anything. Cache until it does.

_index_lock = threading.Lock()
_index = {"fp": None, "series": [], "covers": {}}


def library():
    fp = V.vault_fingerprint(VAULT)
    with _index_lock:
        if fp != _index["fp"]:
            series = V.scan(VAULT)
            for s in series:
                s["coverId"] = V.cover_id(s["cover"]) if s["cover"] else ""
            _index.update(
                fp=fp,
                series=series,
                covers={s["coverId"]: s["cover"] for s in series if s["coverId"]},
            )
        return _index["series"]


def invalidate():
    with _index_lock:
        _index["fp"] = None


def cover_url(cid):
    with _index_lock:
        return _index["covers"].get(cid)


# --------------------------------------------------------------------- tags
#
# The vault has been written by hand over years, so the same tag exists in
# several spellings: HunterFantasy and Hunter Fantasy, SchoolLife and School
# Life, VideoGame and Video Game. They are the same tag and should filter as
# one, but silently merging them would edit notes nobody asked to edit — so the
# variants are surfaced as a suggestion the UI can act on, and the merge is a
# deliberate button press.

def tag_key(t):
    """Fold spelling differences that are not meaning differences."""
    t = unicodedata.normalize("NFKD", t or "")
    return re.sub(r"[^a-z0-9]+", "", t.lower())


def tag_report(series):
    counts = Counter()
    spellings = defaultdict(Counter)
    for s in series:
        for t in s["tags"]:
            counts[t] += 1
            spellings[tag_key(t)][t] += 1

    variants = []
    for key, spell in spellings.items():
        if len(spell) > 1:
            # Suggest the most-used spelling as the survivor; ties go to the
            # longest, which is the spaced form and the more readable one.
            best = max(spell.items(), key=lambda kv: (kv[1], len(kv[0])))[0]
            variants.append({
                "canon": best,
                "spellings": [{"tag": t, "count": n}
                              for t, n in spell.most_common()],
            })
    variants.sort(key=lambda v: -sum(s["count"] for s in v["spellings"]))
    return {
        "counts": [{"tag": t, "count": n} for t, n in counts.most_common()],
        "variants": variants,
    }


# -------------------------------------------------------------------- stats

def _bucket(values, order):
    c = Counter(v or "—" for v in values)
    known = [{"name": k, "count": c.pop(k)} for k in order if k in c]
    return known + [{"name": k, "count": n} for k, n in c.most_common()]


def stats(series):
    rated = [s["rating"] for s in series if s["rating"] is not None]
    chapters = [s["chapter"] for s in series if s["chapter"] is not None]
    active = [s for s in series if s["status"] == "Reading"]
    # "Waiting on the author": something you are current with that is still
    # being published. The single most useful thing a shelf this size can tell
    # you, and Obsidian's card view cannot.
    stalled = [s["name"] for s in series
               if s["status"] == "Hold" and s["pub"] == "Ongoing"]
    finishable = [s["name"] for s in series
                  if s["status"] in ("Hold", "Later") and s["pub"] == "Completed"]
    return {
        "total": len(series),
        "chapters": int(sum(chapters)),
        "rated": len(rated),
        "avg": round(sum(rated) / len(rated), 2) if rated else None,
        "reading": len(active),
        "byStatus": _bucket((s["status"] for s in series), STATUS_ORDER),
        "byType": _bucket((s["type"] for s in series), TYPE_ORDER),
        "byPub": _bucket((s["pub"] for s in series), PUB_ORDER),
        "ratings": [{"score": k, "count": v} for k, v in
                    sorted(Counter(round(r) for r in rated).items())],
        "stalled": sorted(stalled),
        "finishable": sorted(finishable),
    }


def meta(series):
    """Every value already in use, so the UI's dropdowns describe this vault
    rather than a list I guessed at."""
    def seen(field, order):
        vals = {s[field] for s in series if s[field]}
        return [v for v in order if v in vals] + sorted(vals - set(order))
    return {
        "statuses": seen("status", STATUS_ORDER),
        "types": seen("type", TYPE_ORDER),
        "pubs": seen("pub", PUB_ORDER),
        "statusOrder": STATUS_ORDER,
    }


def payload():
    series = library()
    return {"series": series, "stats": stats(series),
            "meta": meta(series), "tags": tag_report(series)}


# ------------------------------------------------------------------- covers
#
# The vault's Cover values are DuckDuckGo proxy URLs pointing at a dozen
# different hosts. Hotlinking 300 of them on every page load is slow, leaks the
# shelf to whoever is on the other end, and breaks the day a host disappears.
# So the server caches each one on first request, keyed by a hash of the URL —
# which means changing a note's Cover changes the key and the new image is
# fetched with no cache to bust.

MAGIC = [(b"\x89PNG", "image/png"), (b"\xff\xd8\xff", "image/jpeg"),
         (b"GIF8", "image/gif"), (b"RIFF", "image/webp"),
         (b"<svg", "image/svg+xml"), (b"<?xml", "image/svg+xml")]
MAX_COVER = 8 << 20
FAIL_RETRY = 6 * 3600
UA = ("Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) "
      "Chrome/124.0 Safari/537.36")

_fetch_lock = threading.Lock()
_fetching = {}


def sniff(b):
    for magic, ctype in MAGIC:
        if b.startswith(magic):
            return ctype
    return "application/octet-stream"


def cover_path(cid):
    return CACHE / "covers" / cid


def unproxy(url):
    """The original image URL hiding inside a DuckDuckGo proxy link.

    Most Cover values were saved from DDG image search and look like
    `external-content.duckduckgo.com/iu/?u=<real url>&ipt=<signature>`. That
    signature expires, and an expired one is a 400 — so when the proxy refuses,
    the picture it was standing in front of is right there in the query string.
    """
    p = urlparse(url)
    if "duckduckgo.com" not in p.netloc:
        return None
    original = (parse_qs(p.query).get("u") or [None])[0]
    return original if original and original.startswith(("http://", "https://")) else None


def _get(url, referer=None):
    headers = {"User-Agent": UA, "Accept": "image/*,*/*;q=0.8"}
    if referer:
        headers["Referer"] = referer
    with urllib.request.urlopen(
            urllib.request.Request(url, headers=headers), timeout=15) as r:
        data = r.read(MAX_COVER + 1)
    if len(data) > MAX_COVER or sniff(data) == "application/octet-stream":
        raise ValueError("not a usable image")
    return data


def _fetch_cover(cid, url):
    """Download one cover into the cache. Returns bytes, or None.

    Roughly one Cover in six is simply dead — a host that no longer exists, or
    one that has started refusing hotlinks. Those are not worth engineering
    around: the UI draws a tinted plate with the title on it, which is the
    honest answer, and the failure is remembered so a dead host is not retried
    on every page load.
    """
    path = cover_path(cid)
    fail = path.with_suffix(".fail")
    if fail.exists() and time.time() - fail.stat().st_mtime < FAIL_RETRY:
        return None
    path.parent.mkdir(parents=True, exist_ok=True)

    data = None
    for candidate, referer in ((url, "https://duckduckgo.com/"),
                               (unproxy(url), None)):
        if not candidate:
            continue
        try:
            data = _get(candidate, referer)
            break
        except Exception:
            continue

    if data is None:
        fail.write_text(str(time.time()))
        return None
    tmp = path.with_suffix(".part")
    tmp.write_bytes(data)
    os.replace(tmp, path)
    fail.unlink(missing_ok=True)
    return data


def cover_bytes(cid):
    path = cover_path(cid)
    if path.exists():
        return path.read_bytes()
    url = cover_url(cid)
    if not url:
        return None
    # One fetch per cover even if the grid asks for it from six connections.
    with _fetch_lock:
        ev = _fetching.get(cid)
        if ev is None:
            ev = _fetching[cid] = threading.Event()
            mine = True
        else:
            mine = False
    if not mine:
        ev.wait(30)
        return path.read_bytes() if path.exists() else None
    try:
        return _fetch_cover(cid, url)
    finally:
        with _fetch_lock:
            _fetching.pop(cid, None)
        ev.set()


def warm_covers():
    series = library()
    todo = [(s["coverId"], s["cover"], s["name"]) for s in series if s["coverId"]]
    ok = skip = bad = 0
    for cid, url, name in todo:
        if cover_path(cid).exists():
            skip += 1
            continue
        if _fetch_cover(cid, url):
            ok += 1
        else:
            bad += 1
            print(f"  no cover: {name}")
    print(f"covers: {ok} fetched, {skip} already cached, {bad} failed "
          f"({len(series) - len(todo)} notes have no Cover)")


# ------------------------------------------------------------------ actions

def do_update(name, fields):
    """Re-read, apply, write. The re-read is the merge: a field someone changed
    in Obsidian since this page loaded survives unless this request set it."""
    path = V.series_path(VAULT, name)
    if not path.exists():
        raise FileNotFoundError(name)
    note = V.read_note(path)
    changed = V.apply_fields(note, fields)
    if changed:
        V.write_note(note)
        invalidate()
    return V.series_from_note(V.read_note(path)), changed


def do_create(name, fields):
    path = V.series_path(VAULT, name)
    if path.exists():
        raise FileExistsError(name)
    path.parent.mkdir(parents=True, exist_ok=True)
    note = V.Note(path, "---\n---\n")
    # Written in a fixed order so a new note looks like the 300 already there.
    base = {"chapter": None, "rating": None, "status": "Later",
            "pub": "", "type": "", "tags": [], "cover": ""}
    base.update({k: v for k, v in (fields or {}).items() if k in base})
    for field in ("chapter", "rating", "status", "pub", "type", "tags", "cover"):
        key = V.FIELD_KEYS[field]
        if field == "tags":
            note.set_list(key.lower(), base[field] or [], spelling=key)
        elif field in V.NUM_FIELDS:
            note.set_scalar(key.lower(), V.fmt_num(V.parse_num(base[field])),
                            spelling=key)
        else:
            note.set_scalar(key.lower(), str(base[field] or "").strip(),
                            spelling=key)
    V.write_note(note)
    invalidate()
    return V.series_from_note(V.read_note(path))


def do_rename(name, new):
    src = V.series_path(VAULT, name)
    dst = V.series_path(VAULT, new)
    if not src.exists():
        raise FileNotFoundError(name)
    if dst.exists() and dst != src:
        raise FileExistsError(new)
    os.replace(src, dst)
    invalidate()
    return V.series_from_note(V.read_note(dst))


def do_merge_tags(sources, target):
    """Rewrite one spelling of a tag into another across the whole vault."""
    target = (target or "").strip()
    sources = {s.strip() for s in sources if s and s.strip()} - {target}
    if not target or not sources:
        return 0
    n = 0
    for s in library():
        if not (set(s["tags"]) & sources):
            continue
        seen, merged = set(), []
        for t in s["tags"]:
            t = target if t in sources else t
            if t not in seen:
                seen.add(t)
                merged.append(t)
        path = V.series_path(VAULT, s["name"])
        note = V.read_note(path)
        if V.apply_fields(note, {"tags": merged}):
            V.write_note(note)
            n += 1
    invalidate()
    return n


# ------------------------------------------------------------------- server

class Handler(BaseHTTPRequestHandler):
    server_version = "ReadingTracker/1.0"
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):
        pass

    def client_ip(self):
        return (self.headers.get("CF-Connecting-IP")
                or self.client_address[0] or "unknown")

    def authed(self):
        ok, why = check_auth(self.headers.get("Authorization"), self.client_ip())
        if ok:
            return True
        if why == "rate":
            self.send_response(429)
            self.send_header("Retry-After", str(RATE_WINDOW))
        else:
            self.send_response(401)
            self.send_header("WWW-Authenticate", 'Basic realm="Reading Room"')
        self.send_header("Content-Length", "0")
        self.end_headers()
        return False

    def _send(self, obj, code=200):
        body = json.dumps(obj, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def _bytes(self, body, ctype, cache=False):
        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control",
                         "public, max-age=31536000, immutable" if cache
                         else "no-store")
        self.end_headers()
        self.wfile.write(body)

    def _file(self, path, ctype, cache=False):
        try:
            return self._bytes(Path(path).read_bytes(), ctype, cache)
        except (FileNotFoundError, IsADirectoryError):
            self.send_error(404, "missing file")

    def _body(self):
        n = int(self.headers.get("Content-Length") or 0)
        return json.loads(self.rfile.read(n).decode("utf-8")) if n else {}

    # -- GET -------------------------------------------------------------

    def do_GET(self):
        u = urlparse(self.path)

        # Typefaces are served ahead of the auth gate deliberately: they are
        # public fonts rather than data, and a 401 here would not look like an
        # error — the page would just quietly fall back to a system stack.
        if u.path.startswith("/fonts/"):
            name = u.path[len("/fonts/"):]
            if FONTS and re.fullmatch(r"[a-z-]+\.woff2", name):
                return self._file(FONTS / name, "font/woff2", cache=True)
            return self.send_error(404, "no such font")

        if not self.authed():
            return

        if u.path in ("/", "/index.html"):
            return self._file(UI, "text/html; charset=utf-8")

        if u.path.startswith("/cover/"):
            cid = u.path[len("/cover/"):]
            if not re.fullmatch(r"[0-9a-f]{20}", cid):
                return self.send_error(404, "no such cover")
            data = cover_bytes(cid)
            if not data:
                # 404 rather than a placeholder image: the UI draws its own,
                # and a fake 200 would poison the browser cache for a year.
                return self.send_error(404, "cover unavailable")
            return self._bytes(data, sniff(data), cache=True)

        if not u.path.startswith("/api/"):
            return self.send_error(404, "not found")

        try:
            if u.path == "/api/library":
                return self._send(payload())
            if u.path == "/api/export":
                return self._send({"series": library()})
            if u.path == "/api/note":
                name = (parse_qs(u.query).get("name") or [""])[0]
                return self._bytes(
                    V.series_path(VAULT, name).read_bytes(),
                    "text/plain; charset=utf-8")
            return self.send_error(404, "no such endpoint")
        except (ValueError, FileNotFoundError) as e:
            return self._send({"error": str(e)}, 404)
        except Exception as e:
            return self._send({"error": str(e)}, 500)

    # -- POST ------------------------------------------------------------

    def do_POST(self):
        if not self.authed():
            return
        u = urlparse(self.path)
        try:
            b = self._body()

            if u.path == "/api/update":
                s, changed = do_update(b["name"], b.get("fields") or {})
                return self._send({"ok": True, "series": s, "changed": changed,
                                   "stats": stats(library())})

            if u.path == "/api/bump":
                name = b["name"]
                cur = V.series_from_note(V.read_note(V.series_path(VAULT, name)))
                by = int(b.get("by", 1))
                nxt = max(0, int(cur["chapter"] or 0) + by)
                fields = {"chapter": nxt}
                # Bumping a chapter on something you had shelved means you are
                # reading it again. Nobody wants to change two fields for that.
                if b.get("resume") and cur["status"] in ("Hold", "Later", ""):
                    fields["status"] = "Reading"
                s, changed = do_update(name, fields)
                return self._send({"ok": True, "series": s, "changed": changed,
                                   "stats": stats(library())})

            if u.path == "/api/create":
                s = do_create((b.get("name") or "").strip(), b.get("fields") or {})
                return self._send({"ok": True, "series": s})

            if u.path == "/api/rename":
                return self._send({"ok": True,
                                   "series": do_rename(b["name"], b["to"])})

            if u.path == "/api/delete":
                dest = V.trash(VAULT, b["name"])
                invalidate()
                return self._send({"ok": True, "trashed": dest.name})

            if u.path == "/api/tags/merge":
                n = do_merge_tags(b.get("from") or [], b.get("to") or "")
                return self._send({"ok": True, "notes": n, **payload()})

            return self.send_error(404, "no such endpoint")
        except FileExistsError as e:
            return self._send({"error": f"“{e}” already exists"}, 409)
        except FileNotFoundError as e:
            return self._send({"error": f"no note named “{e}”"}, 404)
        except (ValueError, KeyError) as e:
            return self._send({"error": str(e)}, 400)
        except Exception as e:
            return self._send({"error": str(e)}, 500)


# -------------------------------------------------------------------- entry

def print_stats():
    series = library()
    st = stats(series)
    print(f"\n{VAULT}\n{st['total']} series · {st['chapters']:,} chapters read · "
          f"average rating {st['avg']}\n")
    for row in st["byStatus"]:
        bar = "█" * round(40 * row["count"] / max(1, st["total"]))
        print(f"  {row['name']:<10} {row['count']:>4}  {bar}")
    print()
    for row in st["byType"]:
        print(f"  {row['name']:<18} {row['count']:>4}")
    if st["stalled"]:
        print(f"\nOn hold but still publishing ({len(st['stalled'])}):")
        for n in st["stalled"][:12]:
            print(f"  · {n}")
    if st["finishable"]:
        print(f"\nShelved and now complete — finishable ({len(st['finishable'])}):")
        for n in st["finishable"][:12]:
            print(f"  · {n}")
    var = tag_report(series)["variants"]
    if var:
        print(f"\n{len(var)} tags spelled more than one way:")
        for v in var:
            print("  " + " / ".join(f"{s['tag']}({s['count']})"
                                    for s in v["spellings"]))
    print()


def main():
    ap = argparse.ArgumentParser(description="Reading tracker over an Obsidian vault")
    ap.add_argument("--port", type=int, default=DEFAULT_PORT)
    ap.add_argument("--host", default=DEFAULT_HOST)
    ap.add_argument("--vault", help="override $RT_VAULT")
    ap.add_argument("--stats", action="store_true", help="print the shelf and exit")
    ap.add_argument("--warm-covers", action="store_true",
                    help="fetch every cover into the cache and exit")
    ap.add_argument("--open", action="store_true", help="open a browser on start")
    a = ap.parse_args()

    global VAULT
    if a.vault:
        VAULT = Path(a.vault).expanduser()
    if not V.series_dir(VAULT).is_dir():
        raise SystemExit(f"no Series/ directory under {VAULT}")

    if a.stats:
        return print_stats()
    if a.warm_covers:
        return warm_covers()

    # Fail closed. Every POST here writes to a real vault and one of them
    # trashes a note; binding a reachable interface with no password would put
    # that on the network. A restart loop is the better failure.
    loopback = a.host in ("127.0.0.1", "localhost", "::1")
    if not AUTH_ON and not loopback and not os.environ.get("RT_ALLOW_NO_AUTH"):
        raise SystemExit(
            f"refusing to bind {a.host} with no password set.\n"
            "Set RT_PASSWORD, provide a systemd credential named 'password', "
            "or bind 127.0.0.1. Override with RT_ALLOW_NO_AUTH=1 if you mean it.")

    n = len(library())
    srv = ThreadingHTTPServer((a.host, a.port), Handler)
    url = f"http://{a.host}:{a.port}"
    auth = "password required" if AUTH_ON else "NO AUTH (loopback only)"
    print(f"Reading tracker → {url}   [{auth}]   {n} series from {VAULT}")
    if a.open:
        webbrowser.open(url)
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        print("\nstopped")


if __name__ == "__main__":
    main()
