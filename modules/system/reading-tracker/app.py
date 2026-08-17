#!/usr/bin/env python3
"""Reading tracker — web server.

Stdlib only: no Flask, no pip. Serves a JSON API over reading.db plus the UI in
ui.html, and caches cover artwork on disk.

    python3 app.py                 # http://127.0.0.1:8778, no auth
    python3 app.py --port 9000
    python3 app.py --stats         # print the shelf and exit, no server
    python3 app.py --warm-covers   # fetch every cover into the cache and exit

Auth is HTTP Basic, enabled whenever a password is present (systemd credential
'password', or $RT_PASSWORD). Binding anything other than loopback without one
is refused — see main().

The database is the store. It was imported once from an Obsidian vault by
import-vault.py, and that vault is not consulted again: seed.json is a snapshot
of it, seeding is additive, and edits made here never travel back. See README.
"""
import argparse
import base64
import hmac
import json
import os
import re
import sqlite3
import threading
import time
import unicodedata
import urllib.request
import webbrowser
from collections import Counter, defaultdict, deque
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse, parse_qs

import seed as S

HERE = Path(__file__).resolve().parent
DB = S.DB
UI = Path(os.environ.get("RT_UI") or HERE / "ui.html")
FONTS = Path(os.environ["RT_FONTS"]) if os.environ.get("RT_FONTS") else None
CACHE = Path(os.environ.get("RT_CACHE") or HERE / ".cache")
DEFAULT_HOST = os.environ.get("RT_HOST", "127.0.0.1")
DEFAULT_PORT = int(os.environ.get("RT_PORT", "8778"))

SEP = "\x1f"          # what v_series joins tags with


# --------------------------------------------------------------------- auth
#
# Same gate as the Elden Ring tracker, for the same reason: this is reachable
# from other machines and every POST here edits or deletes real rows.

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


def _rate_fail(ip):
    with _rate_lock:
        _failures[ip].append(time.time())


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
        _rate_fail(ip)
        return False, "bad"
    if hmac.compare_digest(user, USERNAME) and hmac.compare_digest(pw, PASSWORD):
        return True, ""
    _rate_fail(ip)
    return False, "bad"


# ----------------------------------------------------------------- database

def connect():
    return S.connect(DB)


def row_to_series(r):
    cover = r["cover"] or ""
    return {
        "id": r["id"],
        "title": r["title"],
        "chapter": r["chapter"],
        "rating": r["rating"],
        "status": r["status"],
        "pub": r["pub"],
        "type": r["type"],
        "tags": r["tags"].split(SEP) if r["tags"] else [],
        "cover": cover,
        "coverId": cover_id(cover) if cover else "",
        "notes": r["notes"] or "",
        "created": r["created_at"],
        "updated": r["updated_at"],
        "logCount": r["log_count"],
        "lastRead": r["last_read"],
    }


def all_series(db):
    return [row_to_series(r) for r in db.execute(
        "SELECT * FROM v_series ORDER BY title COLLATE NOCASE")]


def one_series(db, sid):
    r = db.execute("SELECT * FROM v_series WHERE id = ?", (sid,)).fetchone()
    if r is None:
        raise KeyError(sid)
    return row_to_series(r)


def vocab(db):
    """The three closed sets, in their stored presentation order."""
    return {name: [r["name"] for r in
                   db.execute(f"SELECT name FROM {name} ORDER BY pos")]
            for name in ("status", "pub", "type")}


# --------------------------------------------------------------------- tags
#
# The vault was hand-written over years, so the same tag exists in several
# spellings — HunterFantasy and Hunter Fantasy, SchoolLife and School Life.
# They mean one thing and filter as two. Merging them is now a single UPDATE on
# the join table rather than a rewrite of eleven files, but it is still a
# deliberate button press: folding them silently would be deciding for the user
# which spelling was the mistake.

def tag_key(t):
    t = unicodedata.normalize("NFKD", t or "")
    return re.sub(r"[^a-z0-9]+", "", t.lower())


def tag_report(db):
    rows = db.execute("""
        SELECT t.id, t.name, COUNT(st.series_id) AS n
        FROM tag t LEFT JOIN series_tag st ON st.tag_id = t.id
        GROUP BY t.id ORDER BY n DESC, t.name
    """).fetchall()

    spellings = defaultdict(list)
    for r in rows:
        spellings[tag_key(r["name"])].append(r)

    variants = []
    for group in spellings.values():
        if len(group) > 1:
            # The most-used spelling survives; ties go to the longest, which is
            # the spaced form and the more readable one.
            best = max(group, key=lambda r: (r["n"], len(r["name"])))
            variants.append({
                "canon": best["name"],
                "canonId": best["id"],
                "spellings": [{"id": r["id"], "tag": r["name"], "count": r["n"]}
                              for r in sorted(group, key=lambda r: -r["n"])],
            })
    variants.sort(key=lambda v: -sum(s["count"] for s in v["spellings"]))
    return {
        "counts": [{"id": r["id"], "tag": r["name"], "count": r["n"]}
                   for r in rows if r["n"]],
        "variants": variants,
    }


def merge_tags(db, source_ids, target_id):
    """Fold one or more tag spellings into another.

    INSERT OR IGNORE first, then delete: a series carrying both spellings must
    end up with one row, not a primary-key violation.
    """
    source_ids = [int(i) for i in source_ids if int(i) != int(target_id)]
    if not source_ids:
        return 0, []
    marks = ",".join("?" * len(source_ids))
    touched = [r[0] for r in db.execute(
        f"SELECT DISTINCT series_id FROM series_tag WHERE tag_id IN ({marks})",
        source_ids)]
    db.execute(
        f"INSERT OR IGNORE INTO series_tag(series_id, tag_id) "
        f"SELECT series_id, ? FROM series_tag WHERE tag_id IN ({marks})",
        [target_id] + source_ids)
    db.execute(f"DELETE FROM series_tag WHERE tag_id IN ({marks})", source_ids)
    db.execute(f"DELETE FROM tag WHERE id IN ({marks})", source_ids)
    for sid in touched:
        S.reindex(db, sid)
    db.commit()
    return len(touched), touched


# -------------------------------------------------------------------- stats

def _bucket(db, table, column):
    rows = db.execute(f"""
        SELECT v.name AS name, COUNT(s.id) AS n
        FROM {table} v LEFT JOIN series s ON s.{column} = v.id
        GROUP BY v.id ORDER BY v.pos
    """).fetchall()
    out = [{"name": r["name"], "count": r["n"]} for r in rows if r["n"]]
    orphan = db.execute(
        f"SELECT COUNT(*) FROM series WHERE {column} IS NULL").fetchone()[0]
    if orphan:
        out.append({"name": "—", "count": orphan})
    return out


def stats(db):
    total = db.execute("SELECT COUNT(*) FROM series").fetchone()[0]
    agg = db.execute("""
        SELECT CAST(COALESCE(SUM(chapter), 0) AS INTEGER) AS chapters,
               COUNT(rating) AS rated,
               ROUND(AVG(rating), 2) AS avg
        FROM series
    """).fetchone()

    # Two lists the pair of status fields makes possible and neither field
    # answers alone: things you shelved that have since finished, and things
    # you shelved that never stopped publishing.
    def titles(sql):
        return [r["title"] for r in db.execute(sql)]

    finishable = titles("""
        SELECT s.title FROM series s
        JOIN status st ON st.id = s.status_id
        JOIN pub p ON p.id = s.pub_id
        WHERE st.name IN ('Hold','Later') AND p.name = 'Completed'
        ORDER BY s.title COLLATE NOCASE""")
    stalled = titles("""
        SELECT s.title FROM series s
        JOIN status st ON st.id = s.status_id
        JOIN pub p ON p.id = s.pub_id
        WHERE st.name = 'Hold' AND p.name = 'Ongoing'
        ORDER BY s.title COLLATE NOCASE""")

    ratings = [{"score": int(r["b"]), "count": r["n"]} for r in db.execute("""
        SELECT CAST(ROUND(rating) AS INTEGER) AS b, COUNT(*) AS n
        FROM series WHERE rating IS NOT NULL GROUP BY b ORDER BY b""")]

    # History. The whole point of owning a database rather than 300 files that
    # can only ever describe the present.
    recent = db.execute("""
        SELECT CAST(COALESCE(SUM(MAX(to_ch - COALESCE(from_ch, to_ch), 0)), 0)
                    AS INTEGER) AS n
        FROM reading_log WHERE at >= datetime('now', '-30 days')""").fetchone()["n"]
    week = db.execute("""
        SELECT CAST(COALESCE(SUM(MAX(to_ch - COALESCE(from_ch, to_ch), 0)), 0)
                    AS INTEGER) AS n
        FROM reading_log WHERE at >= datetime('now', '-7 days')""").fetchone()["n"]

    return {
        "total": total,
        "chapters": agg["chapters"],
        "rated": agg["rated"],
        "avg": agg["avg"],
        "byStatus": _bucket(db, "status", "status_id"),
        "byType": _bucket(db, "type", "type_id"),
        "byPub": _bucket(db, "pub", "pub_id"),
        "ratings": ratings,
        "finishable": finishable,
        "stalled": stalled,
        "chaptersWeek": week,
        "chaptersMonth": recent,
    }


def history(db, limit=40):
    return [dict(r) for r in db.execute("""
        SELECT rl.id, s.id AS series_id, s.title, rl.from_ch, rl.to_ch, rl.at
        FROM reading_log rl JOIN series s ON s.id = rl.series_id
        ORDER BY rl.at DESC, rl.id DESC LIMIT ?""", (limit,))]


def payload(db):
    return {"series": all_series(db), "stats": stats(db),
            "meta": vocab(db), "tags": tag_report(db), "history": history(db)}


# ------------------------------------------------------------------ writing

FIELDS = {"title", "chapter", "rating", "status", "pub", "type", "cover",
          "notes", "tags"}


def _num(v):
    if v is None or v == "":
        return None
    try:
        f = float(v)
    except (TypeError, ValueError):
        return None
    return f


def update_series(db, sid, fields):
    """Apply a partial field dict. Returns the field names that changed.

    Chapter and status changes are appended to their logs, which is the reason
    the database exists: the vault overwrote that history every time it was
    made.
    """
    before = one_series(db, sid)
    sets, args, changed = [], [], []

    for field in ("title", "cover", "notes"):
        if field in fields:
            new = str(fields[field] or "").strip()
            if field == "title" and not new:
                raise ValueError("a series needs a title")
            if new != before[field]:
                sets.append(f"{field} = ?")
                args.append(new)
                changed.append(field)

    for field in ("chapter", "rating"):
        if field in fields:
            new = _num(fields[field])
            if new is not None and field == "rating" and not (-10 <= new <= 10):
                raise ValueError("rating must be between -10 and 10")
            if new != before[field]:
                sets.append(f"{field} = ?")
                args.append(new)
                changed.append(field)

    for field, table in (("status", "status"), ("pub", "pub"), ("type", "type")):
        if field in fields:
            new = str(fields[field] or "").strip()
            if new != before[field]:
                sets.append(f"{table}_id = ?")
                args.append(S.vocab_id(db, table, new))
                changed.append(field)

    if sets:
        db.execute(f"UPDATE series SET {', '.join(sets)}, "
                   f"updated_at = datetime('now') WHERE id = ?", args + [sid])

    if "tags" in fields:
        want = {t.strip() for t in (fields["tags"] or []) if str(t).strip()}
        if want != set(before["tags"]):
            db.execute("DELETE FROM series_tag WHERE series_id = ?", (sid,))
            for t in want:
                db.execute(
                    "INSERT OR IGNORE INTO series_tag(series_id, tag_id) VALUES (?,?)",
                    (sid, S.tag_id(db, t)))
            changed.append("tags")

    if "chapter" in changed:
        db.execute(
            "INSERT INTO reading_log(series_id, from_ch, to_ch) VALUES (?,?,?)",
            (sid, before["chapter"], _num(fields["chapter"])))
    if "status" in changed:
        db.execute("""
            INSERT INTO status_log(series_id, from_id, to_id)
            VALUES (?, (SELECT id FROM status WHERE name = ?),
                       (SELECT id FROM status WHERE name = ?))""",
            (sid, before["status"], str(fields["status"] or "").strip()))

    if changed:
        S.reindex(db, sid)
        db.commit()
    return changed


def create_series(db, title, fields):
    title = (title or "").strip()
    if not title:
        raise ValueError("a series needs a title")
    if db.execute("SELECT 1 FROM series WHERE title = ?", (title,)).fetchone():
        raise FileExistsError(title)
    sid = db.execute("INSERT INTO series(title) VALUES (?)", (title,)).lastrowid
    update_series(db, sid, {k: v for k, v in (fields or {}).items() if k in FIELDS})
    S.reindex(db, sid)
    db.commit()
    return one_series(db, sid)


def delete_series(db, sid):
    row = db.execute("SELECT title FROM series WHERE id = ?", (sid,)).fetchone()
    if row is None:
        raise KeyError(sid)
    # ON DELETE CASCADE takes the tags and both logs with it; the FTS row is not
    # a real foreign key, so it goes by hand.
    db.execute("DELETE FROM series WHERE id = ?", (sid,))
    db.execute("DELETE FROM series_fts WHERE rowid = ?", (sid,))
    db.commit()
    return row["title"]


def search(db, q):
    q = re.sub(r"[^\w\s]+", " ", q or "", flags=re.UNICODE).strip()
    if not q:
        return []
    match = " ".join(f'"{t}"*' for t in q.split())
    return [row_to_series(r) for r in db.execute("""
        SELECT v.* FROM series_fts f JOIN v_series v ON v.id = f.rowid
        WHERE series_fts MATCH ? ORDER BY rank LIMIT 300""", (match,))]


# ------------------------------------------------------------------- covers
#
# The Cover values came across from the vault as DuckDuckGo image-proxy URLs
# pointing at a dozen hosts. Hotlinking 300 of them on every page load is slow,
# leaks the shelf to whoever is on the other end, and breaks the day a host
# disappears — so each is cached on first request, keyed by a hash of the URL.
# Changing a series' cover therefore changes the key, and there is no cache to
# bust.

MAGIC = [(b"\x89PNG", "image/png"), (b"\xff\xd8\xff", "image/jpeg"),
         (b"GIF8", "image/gif"), (b"RIFF", "image/webp"),
         (b"<svg", "image/svg+xml"), (b"<?xml", "image/svg+xml")]
MAX_COVER = 8 << 20
FAIL_RETRY = 6 * 3600
UA = ("Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) "
      "Chrome/124.0 Safari/537.36")

_fetch_lock = threading.Lock()
_fetching = {}


def cover_id(url):
    import hashlib
    return hashlib.sha256((url or "").encode("utf-8")).hexdigest()[:20]


def sniff(b):
    for magic, ctype in MAGIC:
        if b.startswith(magic):
            return ctype
    return "application/octet-stream"


def cover_path(cid):
    return CACHE / "covers" / cid


def unproxy(url):
    """The original image URL hiding inside a DuckDuckGo proxy link.

    Most covers were saved from DDG image search and look like
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

    Roughly one cover in six is simply dead — a host that no longer exists, or
    one that has started refusing hotlinks. Not worth engineering around: the UI
    draws a tinted plate with the title on it, which is the honest answer, and
    the failure is remembered so a dead host is not retried on every page load.
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


def cover_url(cid):
    db = connect()
    try:
        for (url,) in db.execute("SELECT cover FROM series WHERE cover <> ''"):
            if cover_id(url) == cid:
                return url
    finally:
        db.close()
    return None


def cover_bytes(cid):
    path = cover_path(cid)
    if path.exists():
        return path.read_bytes()
    url = cover_url(cid)
    if not url:
        return None
    # One fetch per cover even when the grid asks from six connections at once.
    with _fetch_lock:
        ev = _fetching.get(cid)
        mine = ev is None
        if mine:
            ev = _fetching[cid] = threading.Event()
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
    db = connect()
    rows = db.execute(
        "SELECT title, cover FROM series WHERE cover <> ''").fetchall()
    total = db.execute("SELECT COUNT(*) FROM series").fetchone()[0]
    db.close()
    ok = skip = bad = 0
    for r in rows:
        cid = cover_id(r["cover"])
        if cover_path(cid).exists():
            skip += 1
            continue
        if _fetch_cover(cid, r["cover"]):
            ok += 1
        else:
            bad += 1
            print(f"  no cover: {r['title']}")
    print(f"covers: {ok} fetched, {skip} already cached, {bad} failed "
          f"({total - len(rows)} series have no cover set)")


# ------------------------------------------------------------------- server

class Handler(BaseHTTPRequestHandler):
    server_version = "ReadingTracker/2.0"
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):
        pass

    def client_ip(self):
        # Behind a Cloudflare tunnel every request arrives from the edge, so
        # remote_addr would bucket the whole internet into one rate-limit key.
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

        # Fonts are served ahead of the auth gate deliberately: they are public
        # typefaces rather than data, and a 401 here would not look like an
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
                # 404 rather than a placeholder: the UI draws its own, and a
                # fake 200 would poison the browser cache for a year.
                return self.send_error(404, "cover unavailable")
            return self._bytes(data, sniff(data), cache=True)

        if not u.path.startswith("/api/"):
            return self.send_error(404, "not found")

        qs = parse_qs(u.query)
        db = connect()
        try:
            if u.path == "/api/library":
                return self._send(payload(db))
            if u.path == "/api/search":
                return self._send({"results": search(db, (qs.get("q") or [""])[0])})
            if u.path == "/api/history":
                return self._send({"history": history(db, 200)})
            if u.path == "/api/export":
                # Keyed on title, not id, so a backup survives a rebuilt
                # database — the same reason the Elden Ring tracker exports ukeys.
                return self._send({
                    "exported": time.strftime("%Y-%m-%d"),
                    "series": [{k: v for k, v in s.items()
                                if k not in ("id", "coverId")}
                               for s in all_series(db)]})
            return self.send_error(404, "no such endpoint")
        except Exception as e:
            return self._send({"error": str(e)}, 500)
        finally:
            db.close()

    # -- POST ------------------------------------------------------------

    def do_POST(self):
        if not self.authed():
            return
        u = urlparse(self.path)
        db = connect()
        try:
            b = self._body()

            if u.path == "/api/update":
                sid = int(b["id"])
                changed = update_series(db, sid, b.get("fields") or {})
                return self._send({"ok": True, "series": one_series(db, sid),
                                   "changed": changed, "stats": stats(db)})

            if u.path == "/api/bump":
                sid = int(b["id"])
                cur = one_series(db, sid)
                fields = {"chapter": (cur["chapter"] or 0) + int(b.get("by", 1))}
                if fields["chapter"] < 0:
                    fields["chapter"] = 0
                # Reading a chapter of something shelved means you picked it back
                # up. Nobody wants to change two fields for that.
                if b.get("resume") and cur["status"] in ("Hold", "Later", ""):
                    fields["status"] = "Reading"
                changed = update_series(db, sid, fields)
                return self._send({"ok": True, "series": one_series(db, sid),
                                   "changed": changed, "stats": stats(db),
                                   "history": history(db)})

            if u.path == "/api/create":
                s = create_series(db, b.get("title"), b.get("fields") or {})
                return self._send({"ok": True, "series": s})

            if u.path == "/api/delete":
                title = delete_series(db, int(b["id"]))
                return self._send({"ok": True, "title": title, **payload(db)})

            if u.path == "/api/tags/merge":
                n, _ = merge_tags(db, b.get("from") or [], int(b["to"]))
                return self._send({"ok": True, "series_touched": n, **payload(db)})

            return self.send_error(404, "no such endpoint")
        except FileExistsError as e:
            return self._send({"error": f"“{e}” is already on the shelf"}, 409)
        except KeyError:
            return self._send({"error": "no such series"}, 404)
        except (ValueError, sqlite3.IntegrityError) as e:
            return self._send({"error": str(e)}, 400)
        except Exception as e:
            return self._send({"error": str(e)}, 500)
        finally:
            db.close()


# -------------------------------------------------------------------- entry

def print_stats():
    db = connect()
    st = stats(db)
    print(f"\n{DB}\n{st['total']} series · {st['chapters']:,} chapters · "
          f"mean rating {st['avg']}\n")
    for row in st["byStatus"]:
        bar = "█" * round(40 * row["count"] / max(1, st["total"]))
        print(f"  {row['name']:<10} {row['count']:>4}  {bar}")
    print()
    for row in st["byType"]:
        print(f"  {row['name']:<18} {row['count']:>4}")
    print(f"\nread in the last 7 days: {st['chaptersWeek']} chapters"
          f"   ·   30 days: {st['chaptersMonth']}")
    if st["finishable"]:
        print(f"\nShelved and now complete — finishable ({len(st['finishable'])}):")
        for n in st["finishable"][:12]:
            print(f"  · {n}")
    if st["stalled"]:
        print(f"\nOn hold but still publishing ({len(st['stalled'])}):")
        for n in st["stalled"][:12]:
            print(f"  · {n}")
    var = tag_report(db)["variants"]
    if var:
        print(f"\n{len(var)} tags spelled more than one way:")
        for v in var:
            print("  " + " / ".join(f"{s['tag']}({s['count']})"
                                    for s in v["spellings"]))
    print()
    db.close()


def main():
    ap = argparse.ArgumentParser(description="Reading tracker")
    ap.add_argument("--port", type=int, default=DEFAULT_PORT)
    ap.add_argument("--host", default=DEFAULT_HOST)
    ap.add_argument("--stats", action="store_true", help="print the shelf and exit")
    ap.add_argument("--warm-covers", action="store_true",
                    help="fetch every cover into the cache and exit")
    ap.add_argument("--open", action="store_true", help="open a browser on start")
    a = ap.parse_args()

    if not DB.exists():
        raise SystemExit(f"{DB} not found — run: python3 seed.py")
    if a.stats:
        return print_stats()
    if a.warm_covers:
        return warm_covers()

    # Fail closed. Every POST here writes to the database and one of them drops
    # a series; binding a reachable interface with no password would put that on
    # the network. A restart loop is the better failure.
    loopback = a.host in ("127.0.0.1", "localhost", "::1")
    if not AUTH_ON and not loopback and not os.environ.get("RT_ALLOW_NO_AUTH"):
        raise SystemExit(
            f"refusing to bind {a.host} with no password set.\n"
            "Set RT_PASSWORD, provide a systemd credential named 'password', "
            "or bind 127.0.0.1. Override with RT_ALLOW_NO_AUTH=1 if you mean it.")

    db = connect()
    n = db.execute("SELECT COUNT(*) FROM series").fetchone()[0]
    db.close()

    srv = ThreadingHTTPServer((a.host, a.port), Handler)
    url = f"http://{a.host}:{a.port}"
    auth = "password required" if AUTH_ON else "NO AUTH (loopback only)"
    print(f"Reading tracker → {url}   [{auth}]   {n} series")
    if a.open:
        webbrowser.open(url)
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        print("\nstopped")


if __name__ == "__main__":
    main()
