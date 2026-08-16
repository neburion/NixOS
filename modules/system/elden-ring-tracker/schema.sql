-- Elden Ring completion tracker — schema
-- Reference data (section/grp/item) is rebuilt from seed.json by seed.py.
-- User data (profile/progress) is never touched by a reseed.

PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS section (
  id     INTEGER PRIMARY KEY,
  slug   TEXT    NOT NULL UNIQUE,
  title  TEXT    NOT NULL,
  note   TEXT    NOT NULL DEFAULT '',
  pos    INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS grp (
  id         INTEGER PRIMARY KEY,
  section_id INTEGER NOT NULL REFERENCES section(id) ON DELETE CASCADE,
  name       TEXT    NOT NULL,
  dlc        INTEGER NOT NULL DEFAULT 0 CHECK (dlc IN (0,1)),
  choice     INTEGER NOT NULL DEFAULT 0 CHECK (choice IN (0,1)),
  pos        INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS item (
  id       INTEGER PRIMARY KEY,
  group_id INTEGER NOT NULL REFERENCES grp(id) ON DELETE CASCADE,
  -- stable natural key, so a reseed keeps your progress attached to the right row
  ukey     TEXT    NOT NULL UNIQUE,
  name     TEXT    NOT NULL,
  detail   TEXT    NOT NULL DEFAULT '',
  kind     TEXT    NOT NULL CHECK (kind IN ('check','tally')),
  target   INTEGER NOT NULL DEFAULT 1 CHECK (target > 0),
  pos      INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS profile (
  id         INTEGER PRIMARY KEY,
  name       TEXT    NOT NULL UNIQUE,
  note       TEXT    NOT NULL DEFAULT '',
  created_at TEXT    NOT NULL DEFAULT (datetime('now')),
  archived   INTEGER NOT NULL DEFAULT 0 CHECK (archived IN (0,1))
);

CREATE TABLE IF NOT EXISTS progress (
  profile_id INTEGER NOT NULL REFERENCES profile(id) ON DELETE CASCADE,
  item_id    INTEGER NOT NULL REFERENCES item(id)    ON DELETE CASCADE,
  value      INTEGER NOT NULL DEFAULT 0 CHECK (value >= 0),
  updated_at TEXT    NOT NULL DEFAULT (datetime('now')),
  PRIMARY KEY (profile_id, item_id)
) WITHOUT ROWID;

CREATE INDEX IF NOT EXISTS ix_grp_section  ON grp(section_id, pos);
CREATE INDEX IF NOT EXISTS ix_item_group   ON item(group_id, pos);
CREATE INDEX IF NOT EXISTS ix_prog_item    ON progress(item_id);
CREATE INDEX IF NOT EXISTS ix_prog_updated ON progress(profile_id, updated_at DESC);

-- Flat join used by nearly every read path.
CREATE VIEW IF NOT EXISTS v_item AS
SELECT i.id         AS item_id,
       i.ukey       AS ukey,
       i.name       AS name,
       i.detail     AS detail,
       i.kind       AS kind,
       i.target     AS target,
       i.pos        AS ipos,
       g.id         AS group_id,
       g.name       AS group_name,
       g.dlc        AS dlc,
       g.choice     AS choice,
       g.pos        AS gpos,
       s.id         AS section_id,
       s.slug       AS slug,
       s.title      AS title,
       s.note       AS note,
       s.pos        AS spos
FROM item i
JOIN grp     g ON g.id = i.group_id
JOIN section s ON s.id = g.section_id;

-- Full-text search over item name + detail (locations, boss names, quest notes).
CREATE VIRTUAL TABLE IF NOT EXISTS item_fts USING fts5(
  name, detail, group_name, section_title,
  content = '',
  tokenize = "unicode61 remove_diacritics 2"
);
