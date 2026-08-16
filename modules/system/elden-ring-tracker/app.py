#!/usr/bin/env python3
"""Elden Ring completion tracker — web server.

Stdlib only. Serves a small JSON API over eldenring.db plus the UI in ui.html.

    python3 app.py                 # http://127.0.0.1:8777, no auth
    python3 app.py --port 9000
    python3 app.py --stats         # print progress and exit, no server

Auth is HTTP Basic, enabled whenever a password is present (systemd credential
'password', or $ER_PASSWORD). Binding anything other than loopback without one
is refused — see main().
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
import webbrowser
from collections import defaultdict, deque
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse, parse_qs

# Paths are env-overridable so the same script works from a checkout and from
# a read-only Nix store path with its database on /var/lib.
HERE = Path(__file__).resolve().parent
DB = Path(os.environ.get("ER_DB") or HERE / "eldenring.db")
UI = Path(os.environ.get("ER_UI") or HERE / "ui.html")
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
USERNAME = "tarnished"
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


def profiles(db):
    rows = db.execute("""
        SELECT p.id, p.name, p.note, p.created_at, p.archived,
               COALESCE(SUM(MIN(pr.value, i.target)), 0) AS done,
               (SELECT COALESCE(SUM(target), 0) FROM item)  AS total
        FROM profile p
        LEFT JOIN progress pr ON pr.profile_id = p.id AND pr.value > 0
        LEFT JOIN item     i  ON i.id = pr.item_id
        GROUP BY p.id
        ORDER BY p.archived, p.id
    """).fetchall()
    return [dict(r) for r in rows]


def tree(db, profile_id):
    rows = db.execute("""
        SELECT v.*, COALESCE(pr.value, 0) AS value,
               (SELECT COUNT(*) FROM progress x
                 WHERE x.item_id = v.item_id AND x.value > 0) AS runs
        FROM v_item v
        LEFT JOIN progress pr
               ON pr.item_id = v.item_id AND pr.profile_id = ?
        ORDER BY v.spos, v.gpos, v.ipos
    """, (profile_id,)).fetchall()

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
        grp["items"].append({
            "id": r["item_id"], "name": r["name"], "detail": r["detail"],
            "kind": r["kind"], "target": r["target"],
            "value": r["value"], "runs": r["runs"],
        })
    return sections


def stats(db, profile_id):
    overall = db.execute("""
        SELECT (SELECT COALESCE(SUM(target), 0) FROM item) AS total,
               COALESCE((SELECT SUM(MIN(pr.value, i.target))
                           FROM progress pr JOIN item i ON i.id = pr.item_id
                          WHERE pr.profile_id = ?), 0) AS done
    """, (profile_id,)).fetchone()

    per_section = db.execute("""
        SELECT s.id, s.slug, s.title,
               SUM(i.target) AS total,
               COALESCE(SUM(MIN(COALESCE(pr.value, 0), i.target)), 0) AS done
        FROM section s
        JOIN grp  g ON g.section_id = s.id
        JOIN item i ON i.group_id  = g.id
        LEFT JOIN progress pr ON pr.item_id = i.id AND pr.profile_id = ?
        GROUP BY s.id
        ORDER BY s.pos
    """, (profile_id,)).fetchall()

    return {
        "done": overall["done"], "total": overall["total"],
        "sections": [dict(r) for r in per_section],
    }


def coverage(db):
    """Units finished in at least one profile — the real answer to the
    mutually-exclusive-questline problem."""
    row = db.execute("""
        SELECT (SELECT COALESCE(SUM(target), 0) FROM item) AS total,
               COALESCE(SUM(u.best), 0) AS done
        FROM (SELECT MIN(MAX(pr.value), i.target) AS best
                FROM progress pr JOIN item i ON i.id = pr.item_id
               GROUP BY pr.item_id) u
    """).fetchone()
    missing = db.execute("""
        SELECT v.item_id, v.name, v.title, v.group_name, v.target
        FROM v_item v
        WHERE COALESCE((SELECT MAX(value) FROM progress WHERE item_id = v.item_id), 0)
              < v.target
        ORDER BY v.spos, v.gpos, v.ipos
    """).fetchall()
    return {"done": row["done"], "total": row["total"],
            "missing": [dict(r) for r in missing]}


FTS_SAFE = re.compile(r"[^\w\s]+", re.UNICODE)


def search(db, q, profile_id):
    q = FTS_SAFE.sub(" ", q or "").strip()
    if not q:
        return []
    match = " ".join(f'"{t}"*' for t in q.split())
    rows = db.execute("""
        SELECT v.item_id, v.name, v.detail, v.kind, v.target,
               v.title, v.group_name, v.dlc,
               COALESCE(pr.value, 0) AS value
        FROM item_fts f
        JOIN v_item v ON v.item_id = f.rowid
        LEFT JOIN progress pr ON pr.item_id = v.item_id AND pr.profile_id = ?
        WHERE item_fts MATCH ?
        ORDER BY rank
        LIMIT 300
    """, (profile_id, match)).fetchall()
    return [dict(r) for r in rows]


def set_value(db, profile_id, item_id, value):
    row = db.execute("SELECT target FROM item WHERE id = ?", (item_id,)).fetchone()
    if row is None:
        raise KeyError("no such item")
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

    def authed(self):
        """Gate every request. Returns True if the caller may proceed."""
        ok, why = check_auth(self.headers.get("Authorization"), self.client_ip())
        if ok:
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

    def _file(self, path, ctype):
        try:
            body = path.read_bytes()
        except FileNotFoundError:
            self.send_error(404, "missing file")
            return
        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
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
        if not self.authed():
            return
        u = urlparse(self.path)
        qs = parse_qs(u.query)
        if u.path in ("/", "/index.html"):
            return self._file(UI, "text/html; charset=utf-8")

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
                return self._send({"ok": True, "value": val, "stats": stats(db, pid)})

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
                n = 0
                for row in body.get("progress", []):
                    it = db.execute("SELECT id, target FROM item WHERE ukey = ?",
                                    (row.get("ukey"),)).fetchone()
                    if it:
                        set_value(db, pid, it["id"], row.get("value", 0))
                        n += 1
                return self._send({"ok": True, "imported": n, "stats": stats(db, pid)})

            return self.send_error(404, "no such endpoint")
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
