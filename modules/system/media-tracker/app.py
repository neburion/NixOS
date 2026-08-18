#!/usr/bin/env python3
"""Media tracker — web server.

Stdlib only: no Flask, no pip. Serves a JSON API over reading.db plus the UI in
ui.html, and caches cover artwork on disk.

    python3 app.py                 # http://127.0.0.1:8778, no auth
    python3 app.py --port 9000
    python3 app.py --stats         # print the shelf and exit, no server
    python3 app.py --warm-covers   # fetch every cover into the cache and exit

Auth is HTTP Basic, enabled whenever a password is present (systemd credential
'password', or $MT_PASSWORD). Binding anything other than loopback without one
is refused — see main(). A successful login also sets a signed cookie good for
a month, so the password is typed once rather than once per browser session.

The database is the store. It was imported once from an Obsidian vault by
import-vault.py, and that vault is not consulted again: seed.json is a snapshot
of it, seeding is additive, and edits made here never travel back. See README.
"""
import argparse
import base64
import hashlib
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
from http.cookies import CookieError, SimpleCookie
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse, parse_qs, urlencode

import seed as S

HERE = Path(__file__).resolve().parent
DB = S.DB
UI = Path(os.environ.get("MT_UI") or HERE / "ui.html")
FONTS = Path(os.environ["MT_FONTS"]) if os.environ.get("MT_FONTS") else None
CACHE = Path(os.environ.get("MT_CACHE") or HERE / ".cache")
DEFAULT_HOST = os.environ.get("MT_HOST", "127.0.0.1")
DEFAULT_PORT = int(os.environ.get("MT_PORT", "8778"))

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
    return (os.environ.get("MT_PASSWORD") or "").strip()


PASSWORD = _load_password()
USERNAME = os.environ.get("MT_USERNAME", "tracker")
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


# ------------------------------------------------------------------ session
#
# Basic Auth on its own is a login per browser session, which on a phone means
# retyping the password most times the app is opened — Safari drops the cached
# credential when the tab goes away. So a successful login also hands out a
# cookie that stands in for it for a month.
#
# It is a signed timestamp, not a session id: there is no server-side table to
# store, sweep, or lose across a restart. The signing key is derived from the
# password, which is what makes rotation work — change the sops secret and
# every cookie in the wild stops verifying, for free.

SESSION_COOKIE = "mt_session"
SESSION_TTL = 30 * 86400
# Re-issued once a cookie is down to its last three weeks, so a browser that
# visits at all never reaches the expiry — the month is a floor, not a clock
# that runs out mid-use.
SESSION_REFRESH = 21 * 86400


def _session_key():
    return hashlib.sha256(b"mt-session\x00" + PASSWORD.encode("utf-8")).digest()


def _session_sig(exp):
    return hmac.new(_session_key(), str(exp).encode("ascii"),
                    hashlib.sha256).hexdigest()


def make_session(now=None):
    exp = int(now or time.time()) + SESSION_TTL
    return f"{exp}.{_session_sig(exp)}"


def check_session(value):
    """(ok, seconds_left). Unsigned, malformed and expired all read as False."""
    if not AUTH_ON or not value:
        return False, 0
    exp, _, sig = value.partition(".")
    if not exp.isdigit() or not sig:
        return False, 0
    if not hmac.compare_digest(sig, _session_sig(exp)):
        return False, 0
    left = int(exp) - int(time.time())
    return left > 0, max(0, left)


# ----------------------------------------------------------------- database

def connect():
    return S.connect(DB)


def row_to_series(r):
    cover = r["cover"] or ""
    return {
        "id": r["id"],
        "title": r["title"],
        "kind": r["kind"],
        # What `chapter` counts for this kind — "ch", "ep", "hrs", or nothing
        # at all for a film. The number is generic; the word is not.
        "unit": r["unit"],
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


def kinds(db):
    return [{"name": r["name"], "unit": r["unit"]}
            for r in db.execute("SELECT name, unit FROM kind ORDER BY pos")]


def types_by_kind(db):
    """{kind: [type…]} — a Manhwa menu on a game is noise."""
    out = defaultdict(list)
    for r in db.execute("""
            SELECT t.name AS type, COALESCE(k.name, '') AS kind
            FROM type t LEFT JOIN kind k ON k.id = t.kind_id
            ORDER BY t.pos"""):
        out[r["kind"]].append(r["type"])
    return dict(out)


def vocab(db):
    """The closed sets, in their stored presentation order."""
    out = {name: [r["name"] for r in
                  db.execute(f"SELECT name FROM {name} ORDER BY pos")]
           for name in ("status", "pub", "type")}
    out["kind"] = [k["name"] for k in kinds(db)]
    out["units"] = {k["name"]: k["unit"] for k in kinds(db)}
    out["typesByKind"] = types_by_kind(db)
    return out


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
        SELECT t.id, t.name, t.axis, COUNT(st.series_id) AS n
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
    counts = [{"id": r["id"], "tag": r["name"], "axis": r["axis"] or "",
               "count": r["n"]} for r in rows if r["n"]]
    # Grouped for the UI, in the vocabulary's own order rather than by count —
    # a menu whose items move every time you tag something is a menu you have
    # to read every time. Anything the user typed himself lands in "other".
    order = {name: i for i, name in enumerate(
        n for names in S.TAGS.values() for n in names)}
    axes = []
    for axis in list(S.TAGS) + ["other"]:
        want = axis if axis != "other" else ""
        members = [c for c in counts if (c["axis"] or "") == want]
        if members:
            members.sort(key=lambda c: (order.get(c["tag"], 1e9), c["tag"]))
            axes.append({"axis": axis, "tags": members})
    return {"counts": counts, "axes": axes, "variants": variants}


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


def _tag_bucket(db):
    """Series per tag, grouped by axis — the shape the stats panel wants.

    This is what replaced the two "shelved and now complete" / "on hold, still
    publishing" lists that used to sit at the bottom of Stats. Those were
    recommendations: the page deciding what he should read next, out of two
    fields it had no business drawing a conclusion from. A breakdown of what
    the shelf actually contains is a statistic; a nudge is not."""
    rows = db.execute("""
        SELECT t.axis, t.name, COUNT(st.series_id) AS n
        FROM tag t JOIN series_tag st ON st.tag_id = t.id
        GROUP BY t.id HAVING n > 0
    """).fetchall()
    out = []
    for axis in list(S.TAGS) + ["other"]:
        want = axis if axis != "other" else None
        members = sorted(((r["name"], r["n"]) for r in rows if r["axis"] == want),
                         key=lambda p: (-p[1], p[0]))
        if members:
            out.append({"axis": axis,
                        "rows": [{"name": n, "count": c} for n, c in members]})
    return out


def stats(db):
    total = db.execute("SELECT COUNT(*) FROM series").fetchone()[0]
    agg = db.execute("""
        SELECT CAST(COALESCE(SUM(chapter), 0) AS INTEGER) AS chapters,
               COUNT(rating) AS rated,
               ROUND(AVG(rating), 2) AS avg
        FROM series
    """).fetchone()

    ratings = [{"score": int(r["b"]), "count": r["n"]} for r in db.execute("""
        SELECT CAST(ROUND(rating) AS INTEGER) AS b, COUNT(*) AS n
        FROM series WHERE rating IS NOT NULL GROUP BY b ORDER BY b""")]

    return {
        "total": total,
        "chapters": agg["chapters"],
        "rated": agg["rated"],
        "avg": agg["avg"],
        "byKind": _bucket(db, "kind", "kind_id"),
        "byStatus": _bucket(db, "status", "status_id"),
        "byType": _bucket(db, "type", "type_id"),
        "byPub": _bucket(db, "pub", "pub_id"),
        "ratings": ratings,
        "byTag": _tag_bucket(db),
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

FIELDS = {"title", "chapter", "rating", "kind", "status", "pub", "type",
          "cover", "notes", "tags"}


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
            if new is not None and field == "rating" and not (0 <= new <= 10):
                raise ValueError("rating must be between 0 and 10")
            if new != before[field]:
                sets.append(f"{field} = ?")
                args.append(new)
                changed.append(field)

    for field, table in (("kind", "kind"), ("status", "status"),
                        ("pub", "pub"), ("type", "type")):
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
    sid = db.execute(
        "INSERT INTO series(title, kind_id) VALUES (?, "
        "(SELECT id FROM kind WHERE name = 'Reading'))", (title,)).lastrowid
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


# ------------------------------------------------------------- image search
#
# The cover picker, modelled on Playnite's: a globe next to the artwork field
# opens a web image search seeded with the title, you look at a grid, you click
# the one you want. Deliberately a *web image search* rather than a metadata
# provider — AniList and Anime-Planet serve the official volume art, and the
# covers on this shelf are the ones scan sites make, in the tall format the
# grid is built around. A provider cannot offer that; a search can.
#
# DuckDuckGo, which needs no key and is where the vault's cover URLs came from
# in the first place. Two requests: the HTML page carries a `vqd` token that
# the JSON endpoint then requires.

DDG_UA = ("Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) "
          "Chrome/126 Safari/537.36")
# DuckDuckGo serves its image thumbnails off Bing's CDN, so the proxy allows
# that family and nothing else. A pattern rather than a list because the shard
# number varies per result; it is still one domain, not an open relay.
THUMB_HOST = re.compile(r"^tse\d+(\.explicit)?\.mm\.bing\.net$|"
                        r"^external-content\.duckduckgo\.com$")
_vqd_cache = {}


def _ddg(url, referer=None):
    h = {"User-Agent": DDG_UA, "Accept-Language": "en-US,en;q=0.9"}
    if referer:
        h["Referer"] = referer
    req = urllib.request.Request(url, headers=h)
    with urllib.request.urlopen(req, timeout=20) as r:
        return r.read().decode("utf-8", "replace")


def _vqd(query):
    hit = _vqd_cache.get(query)
    if hit and time.time() - hit[1] < 900:
        return hit[0]
    page = _ddg("https://duckduckgo.com/?" + urlencode(
        {"q": query, "iax": "images", "ia": "images"}))
    m = re.search(r'vqd="?([\w-]+)"?', page) or re.search(r"vqd=([\d-]+)", page)
    if not m:
        return None
    _vqd_cache[query] = (m.group(1), time.time())
    return m.group(1)


def image_search(query, page=0):
    """[{url, thumb, w, h, host}] — biggest and most portrait first.

    The shelf draws every plate at 2:3, so a wide screenshot is worse than a
    small poster no matter how many pixels it has. Ranking on shape before
    size puts the ones that will actually look right at the top.
    """
    query = (query or "").strip()
    if not query:
        return []
    vqd = _vqd(query)
    if not vqd:
        return []
    raw = _ddg("https://duckduckgo.com/i.js?" + urlencode(
        {"l": "us-en", "o": "json", "q": query, "vqd": vqd,
         "f": ",,,", "p": "1", "s": str(page * 100)}),
        referer="https://duckduckgo.com/")
    try:
        results = json.loads(raw).get("results") or []
    except ValueError:
        return []
    out = []
    for r in results:
        w, h = int(r.get("width") or 0), int(r.get("height") or 0)
        if not (w and h) or w < 200 or h < 280:
            continue          # too small to be cover art
        ratio = w / h
        if not (0.5 <= ratio <= 0.95):
            continue          # landscape, or a square icon
        out.append({
            "url": r.get("image"),
            "thumb": r.get("thumbnail"),
            "w": w, "h": h,
            "host": urlparse(r.get("image") or "").netloc,
        })
    # closest to 2:3 first, then largest
    out.sort(key=lambda i: (abs(i["w"] / i["h"] - 2 / 3), -i["w"] * i["h"]))
    return out[:60]


def thumb_bytes(url):
    """Proxy one DuckDuckGo thumbnail.

    Two reasons it is not loaded straight from the browser: the tailnet reaches
    this over plain HTTP and a browser blocks https images on an http page, and
    it keeps the picker from telling a third party what is being searched for
    from which address. Locked to one host so it cannot be used as a relay.
    """
    if not THUMB_HOST.match(urlparse(url).netloc or ""):
        return None, None
    try:
        req = urllib.request.Request(url, headers={"User-Agent": DDG_UA,
                                                   "Referer": "https://duckduckgo.com/"})
        with urllib.request.urlopen(req, timeout=15) as r:
            data = r.read(4_000_000)
        return data, sniff(data)
    except Exception:
        return None, None


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
    server_version = "MediaTracker/3.0"
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):
        pass

    def client_ip(self):
        # Behind a Cloudflare tunnel every request arrives from the edge, so
        # remote_addr would bucket the whole internet into one rate-limit key.
        return (self.headers.get("CF-Connecting-IP")
                or self.client_address[0] or "unknown")

    def cookie(self, name):
        raw = self.headers.get("Cookie")
        if not raw:
            return ""
        try:
            jar = SimpleCookie()
            jar.load(raw)
        except CookieError:
            return ""
        got = jar.get(name)
        return got.value if got else ""

    def _secure_link(self):
        # Set-Cookie; Secure is dropped outright by the browser over plain
        # HTTP, and the tailnet reaches this on http://…:8778 — so the flag is
        # set from what the request actually arrived on rather than always.
        return ((self.headers.get("X-Forwarded-Proto") or "").lower() == "https"
                or "https" in (self.headers.get("CF-Visitor") or ""))

    def _issue_session(self):
        self._cookie_out = (
            f"{SESSION_COOKIE}={make_session()}; Max-Age={SESSION_TTL}; "
            f"Path=/; HttpOnly; SameSite=Lax"
            + ("; Secure" if self._secure_link() else ""))

    def end_headers(self):
        # One hook for every response path — _send, _bytes, _file and
        # send_error all funnel through here, so the cookie rides out on
        # whatever the authenticated request happened to be.
        out = getattr(self, "_cookie_out", "")
        if out:
            self._cookie_out = ""
            self.send_header("Set-Cookie", out)
        super().end_headers()

    def authed(self):
        ok, left = check_session(self.cookie(SESSION_COOKIE))
        if ok:
            if left < SESSION_REFRESH:
                self._issue_session()
            return True

        ok, why = check_auth(self.headers.get("Authorization"), self.client_ip())
        if ok:
            if AUTH_ON:
                self._issue_session()
            return True
        if why == "rate":
            self.send_response(429)
            self.send_header("Retry-After", str(RATE_WINDOW))
        else:
            self.send_response(401)
            self.send_header("WWW-Authenticate", 'Basic realm="Media Tracker"')
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

        if u.path == "/thumb":
            data, ctype = thumb_bytes((parse_qs(u.query).get("u") or [""])[0])
            if not data:
                return self.send_error(404, "no such thumbnail")
            return self._bytes(data, ctype, cache=True)

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
            if u.path == "/api/images":
                return self._send({"results": image_search(
                    (qs.get("q") or [""])[0], int((qs.get("p") or ["0"])[0]))})
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
                    fields["status"] = "Current"
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
    for group in st["byTag"]:
        top = ", ".join(f"{r['name']} {r['count']}" for r in group["rows"][:6])
        print(f"\n  {group['axis']:<8} {top}")
    print()
    var = tag_report(db)["variants"]
    if var:
        print(f"\n{len(var)} tags spelled more than one way:")
        for v in var:
            print("  " + " / ".join(f"{s['tag']}({s['count']})"
                                    for s in v["spellings"]))
    print()
    db.close()


def main():
    ap = argparse.ArgumentParser(description="Media tracker")
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
    if not AUTH_ON and not loopback and not os.environ.get("MT_ALLOW_NO_AUTH"):
        raise SystemExit(
            f"refusing to bind {a.host} with no password set.\n"
            "Set MT_PASSWORD, provide a systemd credential named 'password', "
            "or bind 127.0.0.1. Override with MT_ALLOW_NO_AUTH=1 if you mean it.")

    db = connect()
    n = db.execute("SELECT COUNT(*) FROM series").fetchone()[0]
    db.close()

    srv = ThreadingHTTPServer((a.host, a.port), Handler)
    url = f"http://{a.host}:{a.port}"
    auth = "password required" if AUTH_ON else "NO AUTH (loopback only)"
    print(f"Media tracker → {url}   [{auth}]   {n} series")
    if a.open:
        webbrowser.open(url)
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        print("\nstopped")


if __name__ == "__main__":
    main()
