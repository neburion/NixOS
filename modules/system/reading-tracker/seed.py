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
# Title -> tags, on the three axes below. Applied once; see apply_tags().
TAGSFILE = Path(os.environ.get("RT_TAGS") or HERE / "tags.json")
SCHEMA = Path(os.environ.get("RT_SCHEMA") or HERE / "schema.sql")

# Presentation order for the three closed vocabularies.
#
# `pub` has no Hold. Hold is a shelf — it says you stopped reading — and it
# answers a different question from "is the author still writing this". The
# vault had it on one note and it made the filter menu unreadable, because two
# menus offered the same word for two different things.
VOCAB = {
    "status": ["Reading", "Later", "Hold", "Read", "Dropped"],
    "pub": ["Ongoing", "Hiatus", "Completed", "Cancelled"],
    "type": ["Manhwa", "Manhua", "Manga", "Web Novel", "Indonesian Comic"],
}

# The tag vocabulary, on three axes.
#
# This replaces a flat pile of 59 hand-written tags in which `Fantasy` (half the
# shelf), `Transmigrassion` (a typo, 109 series) and `Boxing` (one series) were
# peers in one alphabetical menu. Every tag now answers exactly one question:
#
#   setting  where does it take place
#   genre    what does reading it feel like
#   premise  what is the hook — the thing you would say first describing it
#
# Which is what makes the difference between a tag list and a filter. "Fantasy"
# and "Regression" were never alternatives to each other; putting them on
# separate axes lets you ask for a regression story set in a murim world, which
# one flat menu could not express.
#
# Order inside an axis is presentation order, roughly most-used first.
TAGS = {
    "setting": [
        "Fantasy", "Dark Fantasy", "Modern", "Hunter Fantasy", "Murim",
        "Xianxia", "Apocalypse", "Supernatural", "Sci-Fi", "Historical",
        "Academy", "School Life", "Tower", "Dungeon",
    ],
    "genre": [
        "Action", "Adventure", "Comedy", "Romance", "Drama", "Psychological",
        "Horror", "Thriller", "Mystery", "Slice of Life", "Sports",
    ],
    "premise": [
        "Transmigration", "System", "Regression", "Reincarnation", "Revenge",
        "Aristocracy", "Great Teacher", "Gender Swap", "Body Swap",
        "Time Loop", "Author", "Demon King", "Death Game", "Video Game",
        "Necromancy", "Profession",
    ],
}
AXIS_OF = {name: axis for axis, names in TAGS.items() for name in names}


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
    # Tags are upserted by name too, but only their axis is authoritative here:
    # a tag the user invented in the sheet keeps existing with axis NULL, and
    # one of ours gets its axis restored if it was somehow cleared.
    for axis, names in TAGS.items():
        for name in names:
            db.execute(
                "INSERT INTO tag(name, axis) VALUES (?,?) "
                "ON CONFLICT(name) DO UPDATE SET axis = excluded.axis",
                (name, axis))


def once(db, name):
    """True the first time a named repair is asked for, False ever after."""
    if db.execute("SELECT 1 FROM migration WHERE name = ?", (name,)).fetchone():
        return False
    db.execute("INSERT INTO migration(name) VALUES (?)", (name,))
    return True


def add_column(db, table, column, decl):
    """ALTER TABLE ... ADD COLUMN, but only when it is actually missing.

    `CREATE TABLE IF NOT EXISTS` in schema.sql is a no-op against a database
    that already exists, so a new column in that file reaches a fresh install
    and nothing else. This is how it reaches the one on the server."""
    cols = [r["name"] for r in db.execute(f"PRAGMA table_info({table})")]
    if column not in cols:
        db.execute(f"ALTER TABLE {table} ADD COLUMN {column} {decl}")


def migrate(db):
    """One-time repairs. Each runs once, on whichever start first sees it."""
    add_column(db, "tag", "axis", "TEXT")

    # A rating of -10 was a verdict rather than a score. Clamping it is the
    # user's own call, recorded here rather than done silently every start.
    if once(db, "rating-nonneg"):
        n = db.execute("UPDATE series SET rating = 0 WHERE rating < 0").rowcount
        if n:
            print(f"  migrate: {n} negative rating(s) set to 0")

    # Hold left `pub` (see VOCAB). Anything wearing it meant Hiatus.
    if once(db, "pub-drop-hold"):
        row = db.execute("SELECT id FROM pub WHERE name = 'Hold'").fetchone()
        if row:
            hiatus = db.execute("SELECT id FROM pub WHERE name = 'Hiatus'").fetchone()
            n = db.execute("UPDATE series SET pub_id = ? WHERE pub_id = ?",
                           (hiatus["id"], row["id"])).rowcount
            db.execute("DELETE FROM pub WHERE id = ?", (row["id"],))
            print(f"  migrate: pub 'Hold' retired, {n} series moved to Hiatus")


def apply_tags(db, plan):
    """Re-tag the shelf from tags.json, once.

    Deliberately a migration and not part of the additive seed. These are
    *classifications* — the axis vocabulary above applied to every title — and
    replacing a series' tags is destructive of anything hand-typed. Doing it
    once means the user can re-tag anything he disagrees with afterwards and
    keep the change; doing it every start would mean losing that edit on the
    next reboot, which is the exact failure `seed_applied` exists to prevent.
    """
    if not once(db, "tags-three-axis"):
        return 0
    by_title = {r["title"]: r["id"] for r in db.execute("SELECT id, title FROM series")}
    touched = 0
    for title, names in plan.items():
        sid = by_title.get(title)
        if sid is None:
            continue
        db.execute("DELETE FROM series_tag WHERE series_id = ?", (sid,))
        for name in names:
            db.execute(
                "INSERT OR IGNORE INTO series_tag(series_id, tag_id) VALUES (?,?)",
                (sid, tag_id(db, name)))
        reindex(db, sid)
        touched += 1
    # Whatever is left over from the old flat vocabulary and now carries
    # nothing. Tags the user made himself are not in TAGS and are kept only if
    # something still wears them, which is the same rule.
    dead = db.execute(
        "DELETE FROM tag WHERE id NOT IN (SELECT tag_id FROM series_tag)").rowcount
    print(f"  migrate: re-tagged {touched} series, dropped {dead} unused tag(s)")
    return touched


def clamp_rating(v):
    """0-10, or None. One of the two write paths that enforce it; app.py is the
    other. See the CHECK in schema.sql for why it is done here and not there."""
    if v is None or v == "":
        return None
    try:
        return min(10.0, max(0.0, float(v)))
    except (TypeError, ValueError):
        return None


def apply_series(db, s, series_id=None):
    """Insert, or overwrite an existing row when --force-import is given."""
    vals = (
        s["title"], s.get("chapter"), clamp_rating(s.get("rating")),
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
    migrate(db)
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

    if TAGSFILE.exists():
        apply_tags(db, json.loads(TAGSFILE.read_text(encoding="utf-8"))["tags"])

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
