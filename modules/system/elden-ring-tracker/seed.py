#!/usr/bin/env python3
"""Build (or rebuild) the reference tables in eldenring.db from seed.json.

Progress is keyed on a stable natural key (section/group/item name), so
reseeding after an edit to seed.json keeps every tick you have already made.
Run it any time you change seed.json:

    python3 seed.py
"""
import json
import os
import sqlite3
import sys
from pathlib import Path

# Env-overridable so the NixOS unit can read seed data from the (read-only)
# store while writing the database to its StateDirectory.
HERE = Path(__file__).resolve().parent
DB = Path(os.environ.get("ER_DB") or HERE / "eldenring.db")
SEED = Path(os.environ.get("ER_SEED") or HERE / "seed.json")
SCHEMA = Path(os.environ.get("ER_SCHEMA") or HERE / "schema.sql")


def split_detail(raw):
    """'Name::detail' -> ('Name', 'detail'); dict -> tally item."""
    if isinstance(raw, dict):
        return raw["n"], raw.get("d", ""), "tally", int(raw["max"])
    head, sep, tail = raw.partition("::")
    return head, tail if sep else "", "check", 1


def main():
    data = json.loads(SEED.read_text(encoding="utf-8"))
    db = sqlite3.connect(DB)
    db.execute("PRAGMA foreign_keys = ON")
    db.executescript(SCHEMA.read_text(encoding="utf-8"))

    # Preserve progress across a reseed by remembering it under the natural key.
    saved = db.execute(
        "SELECT p.profile_id, i.ukey, p.value, p.updated_at "
        "FROM progress p JOIN item i ON i.id = p.item_id"
    ).fetchall()

    db.execute("DELETE FROM section")  # cascades to grp -> item -> progress
    # a contentless fts5 table has no DELETE; this is the supported way to empty it
    db.execute("INSERT INTO item_fts(item_fts) VALUES('delete-all')")

    n_sec = n_grp = n_item = 0
    for spos, sec in enumerate(data):
        cur = db.execute(
            "INSERT INTO section(slug, title, note, pos) VALUES (?,?,?,?)",
            (sec["id"], sec["t"], sec.get("n", ""), spos),
        )
        sid = cur.lastrowid
        n_sec += 1
        for gpos, grp in enumerate(sec["g"]):
            cur = db.execute(
                "INSERT INTO grp(section_id, name, dlc, choice, pos) VALUES (?,?,?,?,?)",
                (sid, grp["name"], int(bool(grp.get("dlc"))), int(bool(grp.get("x"))), gpos),
            )
            gid = cur.lastrowid
            n_grp += 1
            for ipos, raw in enumerate(grp["items"]):
                name, detail, kind, target = split_detail(raw)
                ukey = f"{sec['id']}\x1f{grp['name']}\x1f{name}\x1f{ipos}"
                cur = db.execute(
                    "INSERT INTO item(group_id, ukey, name, detail, kind, target, pos) "
                    "VALUES (?,?,?,?,?,?,?)",
                    (gid, ukey, name, detail, kind, target, ipos),
                )
                db.execute(
                    "INSERT INTO item_fts(rowid, name, detail, group_name, section_title) "
                    "VALUES (?,?,?,?,?)",
                    (cur.lastrowid, name, detail, grp["name"], sec["t"]),
                )
                n_item += 1

    # Default profile on a fresh database.
    if not db.execute("SELECT 1 FROM profile LIMIT 1").fetchone():
        db.execute(
            "INSERT INTO profile(name, note) VALUES (?,?)",
            ("Main run", "First playthrough"),
        )

    restored = 0
    for profile_id, ukey, value, updated_at in saved:
        row = db.execute("SELECT id FROM item WHERE ukey = ?", (ukey,)).fetchone()
        if row:
            db.execute(
                "INSERT OR REPLACE INTO progress(profile_id, item_id, value, updated_at) "
                "VALUES (?,?,?,?)",
                (profile_id, row[0], value, updated_at),
            )
            restored += 1

    db.commit()
    db.execute("PRAGMA journal_mode = WAL")
    db.execute("VACUUM")
    db.close()

    total = db_total(DB)
    print(f"seeded {DB}")
    print(f"  {n_sec} sections, {n_grp} groups, {n_item} items ({total} tickable units)")
    if saved:
        print(f"  restored {restored}/{len(saved)} progress rows")
    if restored < len(saved):
        print("  WARNING: some progress rows had no matching item and were dropped",
              file=sys.stderr)


def db_total(path):
    db = sqlite3.connect(path)
    n = db.execute("SELECT COALESCE(SUM(target), 0) FROM item").fetchone()[0]
    db.close()
    return n


if __name__ == "__main__":
    main()
