#!/usr/bin/env python3
"""Elden Ring completion tracker — web server.

Stdlib only. Serves a small JSON API over eldenring.db plus the UI in ui.html.

    python3 app.py                 # http://127.0.0.1:8777, no auth
    python3 app.py --port 9000
    python3 app.py --stats         # print progress and exit, no server

Auth is HTTP Basic, enabled whenever a password is present (systemd credential
'password', or $ER_PASSWORD). Binding anything other than loopback without one
is refused — see main(). A successful login also sets a signed cookie good for
a month, so the password is typed once rather than once per browser session.
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
import webbrowser
from collections import defaultdict, deque
from http.cookies import CookieError, SimpleCookie
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse, parse_qs

# Paths are env-overridable so the same script works from a checkout and from
# a read-only Nix store path with its database on /var/lib.
HERE = Path(__file__).resolve().parent
DB = Path(os.environ.get("ER_DB") or HERE / "eldenring.db")
UI = Path(os.environ.get("ER_UI") or HERE / "ui.html")
FONTS = Path(os.environ["ER_FONTS"]) if os.environ.get("ER_FONTS") else None
ICONS = Path(os.environ.get("ER_ICONS") or HERE / "icons")
DEFAULT_HOST = os.environ.get("ER_HOST", "127.0.0.1")
DEFAULT_PORT = int(os.environ.get("ER_PORT", "8777"))


# --------------------------------------------------------------------- auth
#
# HTTP Basic Auth, because this is reachable from the public internet through
# a Cloudflare tunnel. Cloudflare Access is meant to sit in front of it too,
# but Access is configured by hand in the dashboard and is not managed by
# cf-reconcile — so if it is ever missing or misconfigured, this is what
# stands between the database and the internet. Belt and braces on purpose:
# every POST endpoint here can delete a run.
#
# The password comes from systemd LoadCredential (same pattern as the print
# server). With no password configured, auth is disabled entirely so the
# script still runs from a checkout with no arguments — that path is only
# ever bound to 127.0.0.1.

def _load_password():
    creds = os.environ.get("CREDENTIALS_DIRECTORY")
    if creds:
        p = Path(creds) / "password"
        if p.exists():
            return p.read_text().strip()
    return (os.environ.get("ER_PASSWORD") or "").strip()


PASSWORD = _load_password()
# Not a secret, so it lives in the unit rather than in sops — keeping both
# halves of the login in service.nix beats splitting them across two files.
USERNAME = os.environ.get("ER_USERNAME", "tracker")
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
    ok_user = hmac.compare_digest(user, USERNAME)
    ok_pw = hmac.compare_digest(pw, PASSWORD)
    if ok_user and ok_pw:
        return True, ""
    _rate_fail(ip)
    return False, "bad"


# ------------------------------------------------------------------ session
#
# Basic Auth on its own is a login per browser session, which on a phone means
# retyping the password most times the app is opened — Safari drops the cached
# credential when the tab goes away. So a successful login also hands out a
# cookie that stands in for it for a month. Same mechanism as the reading
# tracker, deliberately.
#
# It is a signed timestamp, not a session id: there is no server-side table to
# store, sweep, or lose across a restart. The signing key is derived from the
# password, which is what makes rotation work — change the sops secret and
# every cookie in the wild stops verifying, for free.

SESSION_COOKIE = "er_session"
SESSION_TTL = 30 * 86400
# Re-issued once a cookie is down to its last three weeks, so a browser that
# visits at all never reaches the expiry — the month is a floor, not a clock
# that runs out mid-use.
SESSION_REFRESH = 21 * 86400


def _session_key():
    return hashlib.sha256(b"er-session\x00" + PASSWORD.encode("utf-8")).digest()


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
    db = sqlite3.connect(DB, timeout=10)
    db.row_factory = sqlite3.Row
    db.execute("PRAGMA foreign_keys = ON")
    db.execute("PRAGMA busy_timeout = 5000")
    return db


def default_profile(db):
    row = db.execute(
        "SELECT id FROM profile WHERE archived = 0 ORDER BY id LIMIT 1"
    ).fetchone()
    return row["id"] if row else None


def implication_graph(db):
    """{target_id: [(source_id, needed)]} plus the set of derived ids."""
    graph = {}
    for tid, sid, at_least in db.execute(
            "SELECT i.target_id, i.source_id, "
            "       COALESCE(i.at_least, it.target) "
            "FROM implies i JOIN item it ON it.id = i.source_id"):
        graph.setdefault(tid, []).append((sid, at_least))
    return graph


def effective_values(db, profile_id, graph=None):
    """Stored progress with derived items resolved to a fixpoint.

    Derived items never have stored rows (seed.py strips them), so their value
    is computed here. Iterating to a fixpoint keeps chains correct if a derived
    item ever becomes another's source; the graph is tiny, so the cost is noise.
    """
    if graph is None:
        graph = implication_graph(db)
    vals = {r[0]: r[1] for r in db.execute(
        "SELECT item_id, value FROM progress WHERE profile_id = ?", (profile_id,))}
    if not graph:
        return vals

    targets = {r[0]: r[1] for r in db.execute(
        "SELECT id, target FROM item WHERE id IN (SELECT target_id FROM implies)")}

    for _ in range(len(graph) + 1):
        changed = False
        for tid, sources in graph.items():
            got = targets[tid] if all(
                vals.get(sid, 0) >= needed for sid, needed in sources) else 0
            if vals.get(tid, 0) != got:
                if got:
                    vals[tid] = got
                else:
                    vals.pop(tid, None)
                changed = True
        if not changed:
            break
    return vals


def profiles(db):
    rows = db.execute(
        "SELECT id, name, note, created_at, archived FROM profile "
        "ORDER BY archived, id").fetchall()
    total = db.execute("SELECT COALESCE(SUM(target), 0) FROM item").fetchone()[0]
    caps = {r[0]: r[1] for r in db.execute("SELECT id, target FROM item")}
    graph = implication_graph(db)
    out = []
    for r in rows:
        vals = effective_values(db, r["id"], graph)
        done = sum(min(v, caps.get(i, v)) for i, v in vals.items())
        out.append(dict(r) | {"done": done, "total": total})
    return out


def derivation_labels(db):
    """{target_id: 'from Godrick the Grafted'} for the UI's auto chip."""
    out = {}
    for tid, name in db.execute("""
            SELECT i.target_id, it.name
            FROM implies i JOIN item it ON it.id = i.source_id
            ORDER BY i.target_id, it.name"""):
        out.setdefault(tid, []).append(name)
    return {t: (ns[0] if len(ns) == 1 else f"{len(ns)} prerequisites")
            for t, ns in out.items()}


def tree(db, profile_id):
    rows = db.execute("""
        SELECT v.* FROM v_item v ORDER BY v.spos, v.gpos, v.ipos
    """).fetchall()

    graph = implication_graph(db)
    vals = effective_values(db, profile_id, graph)
    labels = derivation_labels(db)

    # "done in N runs" has to respect derivation too, or a boss ticked in three
    # runs would show its achievement as done in none.
    runs = {}
    for (pid,) in db.execute("SELECT id FROM profile"):
        for iid, v in effective_values(db, pid, graph).items():
            if v > 0:
                runs[iid] = runs.get(iid, 0) + 1

    sections, by_sec, by_grp = [], {}, {}
    for r in rows:
        sec = by_sec.get(r["section_id"])
        if sec is None:
            sec = {"id": r["section_id"], "slug": r["slug"], "title": r["title"],
                   "note": r["note"], "groups": []}
            by_sec[r["section_id"]] = sec
            sections.append(sec)
        grp = by_grp.get(r["group_id"])
        if grp is None:
            grp = {"id": r["group_id"], "name": r["group_name"],
                   "dlc": r["dlc"], "choice": r["choice"], "items": []}
            by_grp[r["group_id"]] = grp
            sec["groups"].append(grp)
        iid = r["item_id"]
        grp["items"].append({
            "id": iid, "name": r["name"], "detail": r["detail"],
            "kind": r["kind"], "target": r["target"],
            "value": vals.get(iid, 0), "runs": runs.get(iid, 0),
            "derived": iid in graph,
            "from": labels.get(iid, ""),
            "icon": r["icon"],
        })
    return sections


def stats(db, profile_id):
    vals = effective_values(db, profile_id)
    meta = db.execute("""
        SELECT i.id, i.target, s.id AS sid, s.slug, s.title, s.pos
        FROM item i JOIN grp g ON g.id = i.group_id JOIN section s ON s.id = g.section_id
        ORDER BY s.pos
    """).fetchall()

    per = {}
    done = total = 0
    for r in meta:
        got = min(vals.get(r["id"], 0), r["target"])
        done += got
        total += r["target"]
        e = per.setdefault(r["sid"], {"id": r["sid"], "slug": r["slug"],
                                      "title": r["title"], "done": 0, "total": 0})
        e["done"] += got
        e["total"] += r["target"]

    return {"done": done, "total": total, "sections": list(per.values())}


def coverage(db):
    """Units finished in at least one profile — the real answer to the
    mutually-exclusive-questline problem."""
    graph = implication_graph(db)
    best = {}
    for (pid,) in db.execute("SELECT id FROM profile"):
        for iid, v in effective_values(db, pid, graph).items():
            if v > best.get(iid, 0):
                best[iid] = v

    rows = db.execute("""
        SELECT v.item_id, v.name, v.title, v.group_name, v.target
        FROM v_item v ORDER BY v.spos, v.gpos, v.ipos
    """).fetchall()

    done = total = 0
    missing = []
    for r in rows:
        got = min(best.get(r["item_id"], 0), r["target"])
        done += got
        total += r["target"]
        if got < r["target"]:
            missing.append(dict(r))
    return {"done": done, "total": total, "missing": missing}


FTS_SAFE = re.compile(r"[^\w\s]+", re.UNICODE)


def search(db, q, profile_id):
    q = FTS_SAFE.sub(" ", q or "").strip()
    if not q:
        return []
    match = " ".join(f'"{t}"*' for t in q.split())
    rows = db.execute("""
        SELECT v.item_id, v.name, v.detail, v.kind, v.target,
               v.title, v.group_name, v.dlc
        FROM item_fts f
        JOIN v_item v ON v.item_id = f.rowid
        WHERE item_fts MATCH ?
        ORDER BY rank
        LIMIT 300
    """, (match,)).fetchall()
    vals = effective_values(db, profile_id)
    return [dict(r) | {"value": vals.get(r["item_id"], 0)} for r in rows]


def set_value(db, profile_id, item_id, value):
    row = db.execute("SELECT target FROM item WHERE id = ?", (item_id,)).fetchone()
    if row is None:
        raise KeyError("no such item")
    if db.execute("SELECT 1 FROM implies WHERE target_id = ?", (item_id,)).fetchone():
        # Storing a value here would shadow the computed one and drift out of
        # sync with its sources. Tick the prerequisite instead.
        raise PermissionError("this entry is derived — tick what it comes from")
    value = max(0, min(int(value), row["target"]))
    if value:
        db.execute("""
            INSERT INTO progress(profile_id, item_id, value, updated_at)
            VALUES (?,?,?, datetime('now'))
            ON CONFLICT(profile_id, item_id)
            DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at
        """, (profile_id, item_id, value))
    else:
        db.execute("DELETE FROM progress WHERE profile_id = ? AND item_id = ?",
                   (profile_id, item_id))
    db.commit()
    return value


# ------------------------------------------------------------------- server

class Handler(BaseHTTPRequestHandler):
    server_version = "ERTracker/1.0"

    def log_message(self, fmt, *args):
        pass  # quiet

    def client_ip(self):
        # Behind the Cloudflare tunnel every request arrives from the edge, so
        # remote_addr would bucket the whole internet into one rate-limit key.
        return (self.headers.get("CF-Connecting-IP")
                or self.client_address[0]
                or "unknown")

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
        # HTTP, and the tailnet reaches this on http://…:8777 — so the flag is
        # set from what the request actually arrived on rather than always.
        return ((self.headers.get("X-Forwarded-Proto") or "").lower() == "https"
                or "https" in (self.headers.get("CF-Visitor") or ""))

    def _issue_session(self):
        self._cookie_out = (
            f"{SESSION_COOKIE}={make_session()}; Max-Age={SESSION_TTL}; "
            f"Path=/; HttpOnly; SameSite=Lax"
            + ("; Secure" if self._secure_link() else ""))

    def end_headers(self):
        # One hook for every response path — _send, _file and send_error all
        # funnel through here, so the cookie rides out on whatever the
        # authenticated request happened to be.
        out = getattr(self, "_cookie_out", "")
        if out:
            self._cookie_out = ""
            self.send_header("Set-Cookie", out)
        super().end_headers()

    def authed(self):
        """Gate every request. Returns True if the caller may proceed."""
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
            self.send_header("Content-Length", "0")
            self.end_headers()
        else:
            self.send_response(401)
            self.send_header("WWW-Authenticate", 'Basic realm="Tarnished Ledger"')
            self.send_header("Content-Length", "0")
            self.end_headers()
        return False

    def _send(self, obj, code=200):
        body = json.dumps(obj).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def _file(self, path, ctype, cache=False):
        try:
            body = path.read_bytes()
        except (FileNotFoundError, IsADirectoryError):
            self.send_error(404, "missing file")
            return
        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        # Fonts come from an immutable store path; the UI must never be stale.
        self.send_header("Cache-Control",
                         "public, max-age=31536000, immutable" if cache else "no-store")
        self.end_headers()
        self.wfile.write(body)

    def _body(self):
        n = int(self.headers.get("Content-Length") or 0)
        if not n:
            return {}
        return json.loads(self.rfile.read(n).decode("utf-8"))

    def _pid(self, qs, db):
        raw = (qs.get("profile") or [None])[0]
        if raw and raw.isdigit():
            if db.execute("SELECT 1 FROM profile WHERE id = ?", (int(raw),)).fetchone():
                return int(raw)
        return default_profile(db)

    def do_GET(self):
        u = urlparse(self.path)

        # Fonts are served before the auth gate on purpose. They are public
        # typefaces, not data, and a 401 here would not surface as an error —
        # the page would just silently fall back to a system stack.
        # Whitelisted by exact filename, so there is nothing for ".." to do.
        if u.path.startswith("/fonts/"):
            name = u.path[len("/fonts/"):]
            if FONTS and re.fullmatch(r"[a-z-]+\.woff2", name):
                return self._file(FONTS / name, "font/woff2", cache=True)
            return self.send_error(404, "no such font")

        if not self.authed():
            return
        qs = parse_qs(u.query)
        if u.path in ("/", "/index.html"):
            return self._file(UI, "text/html; charset=utf-8")

        # Artwork. Behind the auth gate, unlike the fonts above: these are game
        # assets that spell out what the ledger tracks, not public typefaces.
        # The filename pattern is what seed.py wrote into item.icon, so there
        # is nothing here for ".." to do.
        if u.path.startswith("/img/"):
            name = u.path[len("/img/"):]
            if re.fullmatch(r"[a-z0-9-]+\.webp", name):
                return self._file(ICONS / name, "image/webp", cache=True)
            return self.send_error(404, "no such image")

        if not u.path.startswith("/api/"):
            return self.send_error(404, "not found")

        db = connect()
        try:
            if u.path == "/api/profiles":
                return self._send({"profiles": profiles(db)})
            if u.path == "/api/tree":
                pid = self._pid(qs, db)
                return self._send({"profile": pid, "sections": tree(db, pid),
                                   "stats": stats(db, pid)})
            if u.path == "/api/stats":
                pid = self._pid(qs, db)
                return self._send(stats(db, pid))
            if u.path == "/api/coverage":
                return self._send(coverage(db))
            if u.path == "/api/search":
                pid = self._pid(qs, db)
                return self._send({"results": search(db, (qs.get("q") or [""])[0], pid)})
            if u.path == "/api/export":
                pid = self._pid(qs, db)
                rows = db.execute("""
                    SELECT i.ukey, pr.value, pr.updated_at
                    FROM progress pr JOIN item i ON i.id = pr.item_id
                    WHERE pr.profile_id = ?
                """, (pid,)).fetchall()
                name = db.execute("SELECT name FROM profile WHERE id = ?",
                                  (pid,)).fetchone()["name"]
                return self._send({"profile": name,
                                   "progress": [dict(r) for r in rows]})
            return self.send_error(404, "no such endpoint")
        except Exception as e:
            return self._send({"error": str(e)}, 500)
        finally:
            db.close()

    def do_POST(self):
        if not self.authed():
            return
        u = urlparse(self.path)
        db = connect()
        try:
            body = self._body()
            if u.path == "/api/set":
                pid = int(body["profile"])
                val = set_value(db, pid, int(body["item"]), int(body["value"]))
                # Ticking a boss can settle its achievement, Remembrance and
                # Great Rune at once. Return every derived value (there are
                # only a few dozen) so the UI repaints them without refetching
                # the whole tree.
                vals = effective_values(db, pid)
                derived = {t: vals.get(t, 0) for (t,) in
                           db.execute("SELECT DISTINCT target_id FROM implies")}
                return self._send({"ok": True, "value": val, "derived": derived,
                                   "stats": stats(db, pid)})

            if u.path == "/api/profiles":
                name = (body.get("name") or "").strip()
                if not name:
                    return self._send({"error": "name required"}, 400)
                try:
                    cur = db.execute("INSERT INTO profile(name, note) VALUES (?,?)",
                                     (name, (body.get("note") or "").strip()))
                except sqlite3.IntegrityError:
                    return self._send({"error": "a run with that name already exists"}, 409)
                db.commit()
                return self._send({"ok": True, "id": cur.lastrowid,
                                   "profiles": profiles(db)})

            if u.path == "/api/profiles/delete":
                pid = int(body["profile"])
                if len(db.execute("SELECT id FROM profile").fetchall()) <= 1:
                    return self._send({"error": "cannot delete your only run"}, 400)
                db.execute("DELETE FROM profile WHERE id = ?", (pid,))
                db.commit()
                return self._send({"ok": True, "profiles": profiles(db)})

            if u.path == "/api/profiles/rename":
                db.execute("UPDATE profile SET name = ? WHERE id = ?",
                           ((body.get("name") or "").strip(), int(body["profile"])))
                db.commit()
                return self._send({"ok": True, "profiles": profiles(db)})

            if u.path == "/api/reset":
                pid = int(body["profile"])
                db.execute("DELETE FROM progress WHERE profile_id = ?", (pid,))
                db.commit()
                return self._send({"ok": True, "stats": stats(db, pid)})

            if u.path == "/api/import":
                pid = int(body["profile"])
                n = skipped = 0
                for row in body.get("progress", []):
                    it = db.execute("SELECT id, target FROM item WHERE ukey = ?",
                                    (row.get("ukey"),)).fetchone()
                    if not it:
                        continue
                    try:
                        set_value(db, pid, it["id"], row.get("value", 0))
                        n += 1
                    except PermissionError:
                        # Backups taken before derivation existed carry rows for
                        # entries that are now computed. Skipping them loses
                        # nothing: whatever implies them is in the same backup.
                        skipped += 1
                return self._send({"ok": True, "imported": n, "derived_skipped": skipped,
                                   "stats": stats(db, pid)})

            return self.send_error(404, "no such endpoint")
        except PermissionError as e:
            # Derived entries are computed, not stored — a 409 tells the UI to
            # put the checkbox back rather than treating it as a server fault.
            return self._send({"error": str(e)}, 409)
        except Exception as e:
            return self._send({"error": str(e)}, 500)
        finally:
            db.close()


def print_stats():
    db = connect()
    for p in profiles(db):
        pct = 100 * p["done"] / p["total"] if p["total"] else 0
        print(f"\n{p['name']}  —  {p['done']}/{p['total']}  ({pct:.1f}%)")
        for s in stats(db, p["id"])["sections"]:
            bar = "█" * round(20 * s["done"] / s["total"]) if s["total"] else ""
            print(f"  {s['title']:<28} {s['done']:>4}/{s['total']:<4} {bar}")
    cov = coverage(db)
    pct = 100 * cov["done"] / cov["total"] if cov["total"] else 0
    print(f"\nAcross all runs: {cov['done']}/{cov['total']} ({pct:.1f}%) — "
          f"{len(cov['missing'])} items never finished in any run")
    db.close()


def main():
    ap = argparse.ArgumentParser(description="Elden Ring completion tracker")
    ap.add_argument("--port", type=int, default=DEFAULT_PORT)
    ap.add_argument("--host", default=DEFAULT_HOST)
    ap.add_argument("--stats", action="store_true", help="print progress and exit")
    ap.add_argument("--open", action="store_true", help="open a browser on start")
    a = ap.parse_args()

    if not DB.exists():
        raise SystemExit("eldenring.db not found — run: python3 seed.py")
    if a.stats:
        return print_stats()

    # Fail closed. Binding a public interface with no password would put every
    # POST endpoint — including "delete this run" — on the open internet. If
    # the credential ever fails to load, a restart loop and a 502 through the
    # tunnel is a far better outcome than a silently unauthenticated service.
    loopback = a.host in ("127.0.0.1", "localhost", "::1")
    if not AUTH_ON and not loopback and not os.environ.get("ER_ALLOW_NO_AUTH"):
        raise SystemExit(
            f"refusing to bind {a.host} with no password set.\n"
            "Set ER_PASSWORD, provide a systemd credential named 'password', "
            "or bind 127.0.0.1. Override with ER_ALLOW_NO_AUTH=1 if you really "
            "mean it."
        )

    srv = ThreadingHTTPServer((a.host, a.port), Handler)
    url = f"http://{a.host}:{a.port}"
    auth = "password required" if AUTH_ON else "NO AUTH (loopback only)"
    print(f"Elden Ring tracker → {url}   [{auth}]   (ctrl-c to stop)")
    if a.open:
        webbrowser.open(url)
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        print("\nstopped")


if __name__ == "__main__":
    main()
