-- Reading tracker schema.
--
-- The vault this was imported from could only ever hold current state: one
-- markdown note per series, each frontmatter key overwritten in place. Moving
-- to a real database is what buys the two things it could not express —
-- referential integrity over the vocabularies, and history.

PRAGMA journal_mode = WAL;
PRAGMA foreign_keys = ON;

-- ── vocabularies ─────────────────────────────────────────────────────────
-- Three closed sets that were free text in the frontmatter, which is how the
-- vault ended up spelling one value two ways. `pos` carries presentation order,
-- which is not alphabetical: what you are reading now belongs at the top of the
-- shelf and what you abandoned belongs at the bottom.

-- `kind` is what turned a reading tracker into a media tracker: the axis above
-- everything else. A series, a season, a film and a playthrough are all "one
-- thing you are working through", and they differ in three ways that this
-- table carries — what its `type` values are, what its progress counts, and
-- nothing else. Everything below (status, rating, tags, history) was already
-- kind-agnostic and needed no changes at all.
--
-- `unit` is what the progress column counts here: chapters, episodes, hours.
-- Empty for a film, which you have either watched or not.

CREATE TABLE IF NOT EXISTS kind (
  id   INTEGER PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  pos  INTEGER NOT NULL,
  unit TEXT NOT NULL DEFAULT ''
);

CREATE TABLE IF NOT EXISTS status (
  id   INTEGER PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  pos  INTEGER NOT NULL
);

-- `pub` answers "is the author still writing it", which is not the same
-- question as "am I still reading it" — that is `status`. The vault confused
-- the two and left a `Publication Status: Hold` on one note; Hold is a shelf,
-- so that value is gone and the note reads Hiatus.
CREATE TABLE IF NOT EXISTS pub (
  id   INTEGER PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  pos  INTEGER NOT NULL
);

-- `type` hangs off a kind: Manhwa belongs to Reading, OVA to Anime, and
-- offering all of them in one menu is the same mistake the flat tag list was.
-- Nullable kind_id for a value that predates the split.
CREATE TABLE IF NOT EXISTS type (
  id      INTEGER PRIMARY KEY,
  name    TEXT NOT NULL UNIQUE,
  pos     INTEGER NOT NULL,
  kind_id INTEGER REFERENCES kind(id) ON DELETE SET NULL
);

-- ── series ───────────────────────────────────────────────────────────────
-- `title` is the natural key: it is what the vault note was named, and it is
-- what seed.py re-attaches on, so re-importing never duplicates a row.
--
-- The three vocabulary columns are nullable because the vault has a note with
-- no Type and a note with no Publication Status. ON DELETE RESTRICT so a
-- vocabulary entry cannot be removed out from under a series that uses it.

CREATE TABLE IF NOT EXISTS series (
  id         INTEGER PRIMARY KEY,
  title      TEXT NOT NULL UNIQUE,
  -- Still called `chapter`, and it now counts episodes and hours too. Renaming
  -- it would mean rewriting the view, both history tables, every read and
  -- write in app.py and the whole of ui.html, against a live database with
  -- reading history hanging off it — a lot of blast radius for a word. What it
  -- means is carried by kind.unit, which is the part the reader sees.
  chapter    REAL,
  -- 0-10. This once admitted -10, to hold a single series rated in anger; that
  -- was a verdict rather than a score, and it has been set to 0. Databases
  -- created before that keep the wider CHECK — rebuilding a table to tighten a
  -- constraint is not worth the risk to the reading history hanging off it —
  -- but nothing can write a negative any more: app.py clamps on the way in and
  -- seed.py clamps on import, which are the only two writers there are.
  rating     REAL CHECK (rating IS NULL OR (rating >= 0 AND rating <= 10)),
  kind_id    INTEGER REFERENCES kind(id)   ON DELETE RESTRICT,
  status_id  INTEGER REFERENCES status(id) ON DELETE RESTRICT,
  pub_id     INTEGER REFERENCES pub(id)    ON DELETE RESTRICT,
  type_id    INTEGER REFERENCES type(id)   ON DELETE RESTRICT,
  cover      TEXT NOT NULL DEFAULT '',
  notes      TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS series_status ON series(status_id);
CREATE INDEX IF NOT EXISTS series_updated ON series(updated_at DESC);

-- ── tags ─────────────────────────────────────────────────────────────────
-- A real many-to-many, which is what makes `UPDATE tag SET name = ?` a
-- complete merge of two spellings rather than a rewrite of 11 files.
--
-- `axis` is what stops a tag list from turning back into the 59-item pile this
-- started as. Every tag answers exactly one of three questions — where it is
-- set, how it reads, what the hook is — and the UI groups the picker and the
-- filters by that, so "Fantasy" and "Regression" never sit in the same menu
-- again. Nullable for a tag typed straight into the sheet, which lands
-- unfiled until it is given an axis.
CREATE TABLE IF NOT EXISTS tag (
  id   INTEGER PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  axis TEXT
);

CREATE TABLE IF NOT EXISTS series_tag (
  series_id INTEGER NOT NULL REFERENCES series(id) ON DELETE CASCADE,
  tag_id    INTEGER NOT NULL REFERENCES tag(id)    ON DELETE CASCADE,
  PRIMARY KEY (series_id, tag_id)
) WITHOUT ROWID;

CREATE INDEX IF NOT EXISTS series_tag_tag ON series_tag(tag_id);

-- ── history ──────────────────────────────────────────────────────────────
-- The point of owning a database. Every chapter change is appended here, so
-- the shelf can answer "what have I actually been reading lately", which no
-- amount of frontmatter could. `from_ch` is nullable for a series that had no
-- chapter recorded before the change.

CREATE TABLE IF NOT EXISTS reading_log (
  id        INTEGER PRIMARY KEY,
  series_id INTEGER NOT NULL REFERENCES series(id) ON DELETE CASCADE,
  from_ch   REAL,
  to_ch     REAL,
  at        TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS reading_log_at ON reading_log(at DESC);
CREATE INDEX IF NOT EXISTS reading_log_series ON reading_log(series_id, at DESC);

-- Status changes are worth keeping too: "when did I give up on this" is a
-- question the vault threw away every time it was answered.
CREATE TABLE IF NOT EXISTS status_log (
  id        INTEGER PRIMARY KEY,
  series_id INTEGER NOT NULL REFERENCES series(id) ON DELETE CASCADE,
  from_id   INTEGER REFERENCES status(id) ON DELETE SET NULL,
  to_id     INTEGER REFERENCES status(id) ON DELETE SET NULL,
  at        TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS status_log_at ON status_log(at DESC);

-- ── seed bookkeeping ─────────────────────────────────────────────────────
-- Which seed.json entries have ever been imported.
--
-- The obvious implementation of an additive seeder is "insert every title that
-- is not already in `series`" — and it is wrong, because a title is not stable:
-- the app can rename one. Rename a seeded series and the next restart sees its
-- original title missing and imports it again, so a duplicate quietly appears
-- after a reboot. The same hole swallows deletions: anything you removed on
-- purpose comes back.
--
-- Recording what was imported, rather than inferring it, closes both. The key
-- is the title *as it appeared in seed.json*, which never changes because that
-- file is in the read-only store.

CREATE TABLE IF NOT EXISTS seed_applied (
  title     TEXT PRIMARY KEY,
  series_id INTEGER REFERENCES series(id) ON DELETE SET NULL,
  at        TEXT NOT NULL DEFAULT (datetime('now'))
) WITHOUT ROWID;

-- One-time repairs that have already run, so they do not run again. The seeder
-- is otherwise entirely declarative — this is the escape hatch for the handful
-- of things that are a *change of mind* rather than a change of data, like
-- retiring a vocabulary value or reclassifying every tag on the shelf. Those
-- must happen exactly once, because the user is free to undo them afterwards
-- and a seeder that re-applied them would be arguing with him every restart.

CREATE TABLE IF NOT EXISTS migration (
  name TEXT PRIMARY KEY,
  at   TEXT NOT NULL DEFAULT (datetime('now'))
) WITHOUT ROWID;

-- ── views ────────────────────────────────────────────────────────────────
-- One row per series with the vocabularies resolved and tags collapsed, so the
-- API is a single SELECT rather than 300 round trips.

CREATE VIEW IF NOT EXISTS v_series AS
SELECT
  s.id, s.title, s.chapter, s.rating, s.cover, s.notes,
  s.created_at, s.updated_at,
  COALESCE(kn.name, '') AS kind,
  COALESCE(kn.unit, '') AS unit,
  COALESCE(st.name, '') AS status,
  COALESCE(pb.name, '') AS pub,
  COALESCE(ty.name, '') AS type,
  st.pos AS status_pos,
  (SELECT COUNT(*) FROM reading_log rl WHERE rl.series_id = s.id) AS log_count,
  (SELECT MAX(rl.at) FROM reading_log rl WHERE rl.series_id = s.id) AS last_read,
  (SELECT GROUP_CONCAT(t.name, CHAR(31))
     FROM series_tag stg JOIN tag t ON t.id = stg.tag_id
    WHERE stg.series_id = s.id
    ORDER BY t.name) AS tags
FROM series s
LEFT JOIN kind   kn ON kn.id = s.kind_id
LEFT JOIN status st ON st.id = s.status_id
LEFT JOIN pub    pb ON pb.id = s.pub_id
LEFT JOIN type   ty ON ty.id = s.type_id;

-- ── search ───────────────────────────────────────────────────────────────
-- FTS5 over title, tags and type. nixpkgs builds python3's sqlite3 with FTS5,
-- same as the Elden Ring tracker relies on.
--
-- Deliberately NOT an external-content table and deliberately not maintained by
-- triggers: a series' searchable text includes its tags, which live in a join
-- table, so a trigger would have to fire on series_tag as well and recompute
-- the parent row anyway. `reindex()` in app.py does that in one place and is
-- called from every write path, which is easier to keep honest than four
-- triggers that have to agree. rowid is series.id.

CREATE VIRTUAL TABLE IF NOT EXISTS series_fts USING fts5(
  title, tags, type, notes,
  tokenize = "unicode61 remove_diacritics 2"
);
