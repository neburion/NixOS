#!/usr/bin/env python3
"""Build the database from schema.sql and seed.json.

Runs as ExecStartPre on every start, like the Elden Ring tracker's seeder — but
it does a different job, because the data here is not a reference dataset.

There, seed.json is the game's checklist and your ticks are the only thing worth
keeping, so the reference tables are dropped and rebuilt every time. Here
seed.json is an *origin snapshot* of a vault, and everything in it — chapter,
rating, status — is exactly the mutable state the app exists to edit. Rebuilding
it on every start would hand back the reading you did last week.

So seeding is additive, and what it keys on matters:

    a seed entry never imported before  ->  inserted, and recorded
    a seed entry already imported       ->  skipped, whatever became of it
    a series not from seed.json         ->  left completely alone

Note the middle line. Keying on "is this title in the series table?" is the
obvious version and it is wrong, because a title is not stable — the app can
rename one. Rename a seeded series and the next restart would see its original
title missing and import it a second time, so a duplicate appears after a
reboot; delete one on purpose and it comes back. `seed_applied` records what was
imported instead of inferring it, which closes both holes.

That makes the first start an import, every later start a no-op, and adding an
entry to seed.json a way to bulk-add series without touching what is there. The
vocabularies (status / pub / type) are the one exception: those are closed sets
and are upserted every time, so fixing an ordering or adding a status is just an
edit and a redeploy.

    python3 seed.py                # $RT_DB, or ./reading.db from a checkout
    python3 seed.py --force-import # re-apply seed.json over existing rows
"""
import argparse
import json
import os
import sqlite3
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
DB = Path(os.environ.get("RT_DB") or HERE / "reading.db")
SEED = Path(os.environ.get("RT_SEED") or HERE / "seed.json")
SCHEMA = Path(os.environ.get("RT_SCHEMA") or HERE / "schema.sql")

# Presentation order for the three closed vocabularies. Every value the vault
# actually used is here; `Hold` appears under pub because one note says it.
VOCAB = {
    "status": ["Reading", "Later", "Hold", "Read", "Dropped"],
    "pub": ["Ongoing", "Hiatus", "Completed", "Cancelled", "Hold"],
    "type": ["Manhwa", "Manhua", "Manga", "Web Novel", "Indonesian Comic"],
}


def connect(path=DB):
    db = sqlite3.connect(path, timeout=10)
    db.row_factory = sqlite3.Row
    db.execute("PRAGMA foreign_keys = ON")
    db.execute("PRAGMA busy_timeout = 5000")
    return db


def vocab_id(db, table, name):
    """Resolve a vocabulary value, adding it if the data has one we did not
    anticipate. Returns None for the empty string — two notes have no Type."""
    name = (name or "").strip()
    if not name:
        return None
    row = db.execute(f"SELECT id FROM {table} WHERE name = ?", (name,)).fetchone()
    if row:
        return row["id"]
    pos = db.execute(f"SELECT COALESCE(MAX(pos), 0) + 1 FROM {table}").fetchone()[0]
    return db.execute(
        f"INSERT INTO {table}(name, pos) VALUES (?,?)", (name, pos)).lastrowid


def tag_id(db, name):
    name = name.strip()
    row = db.execute("SELECT id FROM tag WHERE name = ?", (name,)).fetchone()
    if row:
        return row["id"]
    return db.execute("INSERT INTO tag(name) VALUES (?)", (name,)).lastrowid


def reindex(db, series_id):
    """Rebuild one series' FTS row. The single place search text is defined."""
    r = db.execute("SELECT title, type, notes, tags FROM v_series WHERE id = ?",
                   (series_id,)).fetchone()
    db.execute("DELETE FROM series_fts WHERE rowid = ?", (series_id,))
    if r:
        db.execute(
            "INSERT INTO series_fts(rowid, title, tags, type, notes) VALUES (?,?,?,?,?)",
            (series_id, r["title"], (r["tags"] or "").replace("\x1f", " "),
             r["type"] or "", r["notes"] or ""))


def upsert_vocab(db):
    for table, names in VOCAB.items():
        for pos, name in enumerate(names, start=1):
            db.execute(
                f"INSERT INTO {table}(name, pos) VALUES (?,?) "
                f"ON CONFLICT(name) DO UPDATE SET pos = excluded.pos", (name, pos))


def apply_series(db, s, series_id=None):
    """Insert, or overwrite an existing row when --force-import is given."""
    vals = (
        s["title"], s.get("chapter"), s.get("rating"),
        vocab_id(db, "status", s.get("status")),
        vocab_id(db, "pub", s.get("pub")),
        vocab_id(db, "type", s.get("type")),
        s.get("cover") or "", s.get("notes") or "",
    )
    if series_id is None:
        series_id = db.execute(
            "INSERT INTO series(title, chapter, rating, status_id, pub_id, type_id,"
            " cover, notes) VALUES (?,?,?,?,?,?,?,?)", vals).lastrowid
    else:
        db.execute(
            "UPDATE series SET title=?, chapter=?, rating=?, status_id=?, pub_id=?,"
            " type_id=?, cover=?, notes=?, updated_at=datetime('now') WHERE id=?",
            vals + (series_id,))
        db.execute("DELETE FROM series_tag WHERE series_id = ?", (series_id,))

    for t in s.get("tags") or []:
        db.execute("INSERT OR IGNORE INTO series_tag(series_id, tag_id) VALUES (?,?)",
                   (series_id, tag_id(db, t)))
    reindex(db, series_id)
    return series_id


def main():
    ap = argparse.ArgumentParser(description="Seed the reading tracker database")
    ap.add_argument("--force-import", action="store_true",
                    help="re-apply seed.json over rows that already exist")
    a = ap.parse_args()

    DB.parent.mkdir(parents=True, exist_ok=True)
    db = connect()
    db.executescript(SCHEMA.read_text(encoding="utf-8"))
    upsert_vocab(db)

    payload = json.loads(SEED.read_text(encoding="utf-8"))
    applied = {r["title"]: r["series_id"]
               for r in db.execute("SELECT title, series_id FROM seed_applied")}
    by_title = {r["title"]: r["id"] for r in db.execute("SELECT id, title FROM series")}

    added = updated = 0
    for s in payload["series"]:
        title = s["title"]
        if title not in applied:
            # A title present in `series` but not in `seed_applied` is a series
            # the user created by hand that happens to share the name. Adopt it
            # rather than fail on the UNIQUE constraint.
            sid = by_title.get(title)
            if sid is None:
                sid = apply_series(db, s)
                added += 1
            db.execute(
                "INSERT OR REPLACE INTO seed_applied(title, series_id) VALUES (?,?)",
                (title, sid))
        elif a.force_import and applied[title] is not None:
            apply_series(db, s, applied[title])
            updated += 1

    # A row whose FTS entry went missing — an interrupted write, or a database
    # that predates the index — would be invisible to search while looking
    # perfectly fine everywhere else. Cheap to check, so check every start.
    healed = 0
    for (sid,) in db.execute(
            "SELECT id FROM series WHERE id NOT IN "
            "(SELECT rowid FROM series_fts)").fetchall():
        reindex(db, sid)
        healed += 1

    db.commit()
    total = db.execute("SELECT COUNT(*) FROM series").fetchone()[0]
    tags = db.execute("SELECT COUNT(*) FROM tag").fetchone()[0]
    kept = total - added
    print(f"seed: {total} series ({added} imported, {kept} left untouched"
          + (f", {updated} re-imported" if updated else "")
          + (f", {healed} search rows healed" if healed else "")
          + f"), {tags} tags → {DB}")
    db.close()


if __name__ == "__main__":
    sys.exit(main())
