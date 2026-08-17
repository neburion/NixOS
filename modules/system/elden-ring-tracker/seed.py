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
LINKS = Path(os.environ.get("ER_LINKS") or HERE / "links.json")
ICONS = Path(os.environ.get("ER_ICON_MAP") or HERE / "icons.json")


def split_detail(raw):
    """'Name::detail' -> ('Name', 'detail'); dict -> tally item."""
    if isinstance(raw, dict):
        return raw["n"], raw.get("d", ""), "tally", int(raw["max"])
    head, sep, tail = raw.partition("::")
    return head, tail if sep else "", "check", 1


def load_icons():
    """{section id + item name: filename} from fetch-icons.py.

    Keyed on section and name rather than the full ukey, which carries a
    position that shifts whenever the list is edited. The same name in the
    same section is the same picture, so this survives reordering for free
    and lets one file serve every place a name appears.

    Optional: the tracker runs fine with no artwork at all.
    """
    if not ICONS.exists():
        return {}
    return json.loads(ICONS.read_text(encoding="utf-8"))


def migrate_columns(db):
    """Add columns this schema has gained since the database was created.

    schema.sql uses CREATE TABLE IF NOT EXISTS, so an existing item table is
    left exactly as it was — a new column has to be added by hand or every
    insert below fails on a database that predates it.
    """
    have = {r[1] for r in db.execute("PRAGMA table_info(item)")}
    if have and "icon" not in have:
        db.execute("ALTER TABLE item ADD COLUMN icon TEXT NOT NULL DEFAULT ''")
        print("migrated: added item.icon")


def main():
    data = json.loads(SEED.read_text(encoding="utf-8"))
    icons = load_icons()
    db = sqlite3.connect(DB)
    db.execute("PRAGMA foreign_keys = ON")
    migrate_columns(db)
    db.executescript(SCHEMA.read_text(encoding="utf-8"))

    # Preserve progress across a reseed by remembering it under the natural key.
    saved = db.execute(
        "SELECT p.profile_id, i.ukey, p.value, p.updated_at "
        "FROM progress p JOIN item i ON i.id = p.item_id"
    ).fetchall()

    db.execute("DELETE FROM section")  # cascades to grp -> item -> progress
    # a contentless fts5 table has no DELETE; this is the supported way to empty it
    db.execute("INSERT INTO item_fts(item_fts) VALUES('delete-all')")

    n_sec = n_grp = n_item = n_icon = 0
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
                icon = icons.get(f"{sec['id']}\x1f{name}", "")
                cur = db.execute(
                    "INSERT INTO item(group_id, ukey, name, detail, kind, target, pos, icon) "
                    "VALUES (?,?,?,?,?,?,?,?)",
                    (gid, ukey, name, detail, kind, target, ipos, icon),
                )
                db.execute(
                    "INSERT INTO item_fts(rowid, name, detail, group_name, section_title) "
                    "VALUES (?,?,?,?,?)",
                    (cur.lastrowid, name, detail, grp["name"], sec["t"]),
                )
                n_item += 1
                n_icon += 1 if icon else 0

    n_links = load_links(db)

    # Default profile on a fresh database.
    if not db.execute("SELECT 1 FROM profile LIMIT 1").fetchone():
        db.execute(
            "INSERT INTO profile(name, note) VALUES (?,?)",
            ("Main run", "First playthrough"),
        )

    # An item inserted mid-list shifts every position after it, and with it the
    # ukey of items nobody touched. Fall back to section/group/name, which is
    # position-free — but only when it picks out exactly one item, so a group
    # with repeated names (the bosses) still needs the position to disambiguate.
    by_name = {}
    for iid, ukey in db.execute("SELECT id, ukey FROM item"):
        by_name.setdefault(ukey.rsplit("\x1f", 1)[0], []).append(iid)

    restored = 0
    for profile_id, ukey, value, updated_at in saved:
        row = db.execute("SELECT id FROM item WHERE ukey = ?", (ukey,)).fetchone()
        if not row:
            moved_ids = by_name.get(ukey.rsplit("\x1f", 1)[0], ())
            row = (moved_ids[0],) if len(moved_ids) == 1 else None
        if row:
            db.execute(
                "INSERT OR REPLACE INTO progress(profile_id, item_id, value, updated_at) "
                "VALUES (?,?,?,?)",
                (profile_id, row[0], value, updated_at),
            )
            restored += 1

    moved = backfill_derived(db)

    db.commit()
    db.execute("PRAGMA journal_mode = WAL")
    db.execute("VACUUM")
    db.close()

    total = db_total(DB)
    print(f"seeded {DB}")
    print(f"  {n_sec} sections, {n_grp} groups, {n_item} items ({total} tickable units)")
    print(f"  {n_links} implications ({len(set(t for t, _ in _link_pairs))} derived items)")
    if icons:
        print(f"  {n_icon}/{n_item} items have artwork")
    else:
        print("  no icons.json — running without artwork")
    if saved:
        print(f"  restored {restored}/{len(saved)} progress rows")
    if moved:
        print(f"  migrated {moved} tick(s) from derived items down to their sources")
    if restored < len(saved):
        print("  WARNING: some progress rows had no matching item and were dropped",
              file=sys.stderr)


_link_pairs = []


def load_links(db):
    """Resolve links.json against the freshly-inserted items.

    Every reference must resolve to exactly one item. An unresolvable or
    ambiguous reference aborts the seed rather than silently dropping a link —
    a missing implication would look identical to "you haven't done it yet".
    """
    _link_pairs.clear()
    if not LINKS.exists():
        return 0

    rows = db.execute("""
        SELECT i.id, s.slug, g.name AS gname, i.name
        FROM item i JOIN grp g ON g.id = i.group_id JOIN section s ON s.id = g.section_id
    """).fetchall()

    by_sec_name = {}
    by_sec_grp_name = {}
    by_group = {}
    for iid, slug, gname, name in rows:
        by_sec_name.setdefault((slug, name), []).append(iid)
        by_sec_grp_name.setdefault((slug, gname, name), []).append(iid)
        by_group.setdefault((slug, gname), []).append(iid)

    def resolve(ref):
        """-> list of item ids, or raises."""
        if ref.startswith("group:"):
            slug, _, gname = ref[6:].partition("|")
            ids = by_group.get((slug, gname))
            if not ids:
                raise SystemExit(f"links.json: no such group {ref!r}")
            return ids
        parts = ref.split("|")
        if len(parts) == 2:
            ids = by_sec_name.get((parts[0], parts[1]), [])
            if len(ids) > 1:
                raise SystemExit(
                    f"links.json: {ref!r} is ambiguous ({len(ids)} matches) — "
                    f"qualify it as 'section|Group|Item'")
        elif len(parts) == 3:
            ids = by_sec_grp_name.get((parts[0], parts[1], parts[2]), [])
        else:
            raise SystemExit(f"links.json: malformed reference {ref!r}")
        if not ids:
            raise SystemExit(f"links.json: unresolved reference {ref!r}")
        return ids

    spec = json.loads(LINKS.read_text(encoding="utf-8"))
    n = 0
    for link in spec.get("links", []):
        tids = resolve(link["target"])
        if len(tids) != 1:
            raise SystemExit(f"links.json: target {link['target']!r} must be one item")
        target = tids[0]
        for src in link["sources"]:
            ref, at_least = (src, None) if isinstance(src, str) else (src["ref"], src.get("atLeast"))
            for sid in resolve(ref):
                # A group expansion can legitimately contain its own target
                # (Rune Level 713 sits inside "Level & stats"); skip it rather
                # than tripping the CHECK constraint.
                if sid == target:
                    continue
                db.execute(
                    "INSERT OR REPLACE INTO implies(target_id, source_id, at_least) "
                    "VALUES (?,?,?)", (target, sid, at_least))
                _link_pairs.append((target, sid))
                n += 1
    return n


def backfill_derived(db):
    """Move ticks off derived items and onto whatever implies them.

    Without this, turning an item derived would silently erase it: a run with
    33 achievements ticked and no bosses ticked would recompute to zero. If you
    ticked "Shardbearer Godrick" you demonstrably killed Godrick, so the tick
    belongs on the boss.
    """
    targets = {r[0] for r in db.execute("SELECT DISTINCT target_id FROM implies")}
    if not targets:
        return 0

    moved = 0
    stale = db.execute("""
        SELECT p.profile_id, p.item_id, p.value
        FROM progress p
        WHERE p.item_id IN (SELECT target_id FROM implies)
    """).fetchall()

    for profile_id, target_id, value in stale:
        if value > 0:
            for source_id, at_least in db.execute(
                    "SELECT source_id, at_least FROM implies WHERE target_id = ?",
                    (target_id,)):
                tgt = db.execute("SELECT target FROM item WHERE id = ?",
                                 (source_id,)).fetchone()[0]
                want = at_least if at_least is not None else tgt
                cur = db.execute(
                    "SELECT value FROM progress WHERE profile_id = ? AND item_id = ?",
                    (profile_id, source_id)).fetchone()
                if (cur[0] if cur else 0) < want:
                    db.execute("""
                        INSERT INTO progress(profile_id, item_id, value, updated_at)
                        VALUES (?,?,?, datetime('now'))
                        ON CONFLICT(profile_id, item_id)
                        DO UPDATE SET value = excluded.value
                    """, (profile_id, source_id, want))
            moved += 1
        # Derived values are computed on read; a stored row would shadow them.
        db.execute("DELETE FROM progress WHERE profile_id = ? AND item_id = ?",
                   (profile_id, target_id))
    return moved


def db_total(path):
    db = sqlite3.connect(path)
    n = db.execute("SELECT COALESCE(SUM(target), 0) FROM item").fetchone()[0]
    db.close()
    return n


if __name__ == "__main__":
    main()
