#!/usr/bin/env python3
"""The vault is the database.

Reading-Ob is an Obsidian vault: one markdown note per series under `Series/`,
with everything tracked living in the note's YAML frontmatter. This module
reads that directory and writes back into it, so the web UI and Obsidian are
looking at the same bytes instead of two copies that drift apart. There is no
SQLite mirror here on purpose — a second store would need syncing, and the one
thing worse than no tracker is a tracker that disagrees with the vault.

Writes are surgical. Frontmatter is parsed into line ranges and setting a field
splices the lines for that one key; every other byte of the file survives
untouched — unknown keys, key order, comments, blank lines, and the note body.
That matters because this understands a deliberately small subset of YAML
(`Key: scalar` and `Key:` followed by `  - item` lines, which is all 300 notes
use today) and the vault may one day contain something richer. A parser that
re-serialised the whole document would quietly flatten it.

Every write re-reads the file immediately beforehand and applies only the
changed fields to that fresh content. An edit made in Obsidian between the page
loading and the save landing is therefore merged, not clobbered.
"""
import hashlib
import os
import re
import tempfile
from pathlib import Path

SERIES_DIR = "Series"
TRASH_DIR = ".trash"          # Obsidian's own convention, so deletes are undoable
FENCE = "---"

# A frontmatter key: starts with a letter, may contain spaces ("Reading
# Status"). Non-greedy so the first colon wins, which is what keeps
# `Cover: https://...` from being read as a key of "Cover: https".
KEY_RE = re.compile(r"^(?P<key>[A-Za-z][A-Za-z0-9 _/-]*?)\s*:(?P<rest>.*)$")
ITEM_RE = re.compile(r"^\s+-\s*(?P<val>.*)$")

# Field name used by the API  ->  the key spelling written into a note that
# does not have it yet. Lookup is case-insensitive, so a note using `tags:`
# rather than `Tags:` is found and keeps its own spelling on write.
FIELD_KEYS = {
    "chapter": "Chapter",
    "rating": "Rating",
    "status": "Reading Status",
    "pub": "Publication Status",
    "type": "Type",
    "tags": "Tags",
    "cover": "Cover",
}
LIST_FIELDS = {"tags"}
NUM_FIELDS = {"chapter", "rating"}

# Everything above is ours; anything else in a note is somebody's own note-
# keeping and is passed through to the UI read-only rather than dropped.
OWNED = {k.lower() for k in FIELD_KEYS.values()} | {"tags"}


# ----------------------------------------------------------------- scalars

def _unquote(s):
    s = s.strip()
    if len(s) >= 2 and s[0] == s[-1] and s[0] in "\"'":
        body = s[1:-1]
        return body.replace('\\"', '"') if s[0] == '"' else body
    return s


def _quote(s):
    """Quote only when a bare scalar would not survive a YAML round trip."""
    s = str(s)
    if s == "":
        return ""
    risky = (s != s.strip()
             or s[0] in "#-?:,[]{}&*!|>%@`\"'"
             or ": " in s
             or s.endswith(":"))
    if not risky:
        return s
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def fmt_num(v):
    """7.0 -> '7', 7.5 -> '7.5'. The vault writes ratings both ways."""
    if v is None or v == "":
        return ""
    f = float(v)
    return str(int(f)) if f.is_integer() else f"{f:g}"


def parse_num(s):
    if s is None or str(s).strip() == "":
        return None
    try:
        return float(str(s).strip())
    except ValueError:
        return None


# -------------------------------------------------------------------- note

class Block:
    """One frontmatter key and the line range it occupies."""

    __slots__ = ("key", "start", "end", "kind", "value")

    def __init__(self, key, start, end, kind, value):
        self.key, self.start, self.end = key, start, end
        self.kind, self.value = kind, value


class Note:
    """A markdown note, addressable by frontmatter key without losing the rest."""

    def __init__(self, path, text):
        self.path = Path(path)
        self.eol_at_eof = text.endswith("\n")
        self.lines = text.split("\n")
        if self.eol_at_eof:
            self.lines.pop()          # re-added by render(), keeps splices clean
        self._parse()

    # -- parsing ---------------------------------------------------------

    def _parse(self):
        self.blocks = {}
        self.order = []
        self.fm_lo = self.fm_hi = None

        if not self.lines or self.lines[0].strip() != FENCE:
            return
        for i in range(1, len(self.lines)):
            if self.lines[i].strip() == FENCE:
                self.fm_lo, self.fm_hi = 1, i
                break
        else:
            return                    # opened but never closed: leave it alone

        i = self.fm_lo
        while i < self.fm_hi:
            m = KEY_RE.match(self.lines[i])
            if not m:
                i += 1
                continue
            key, rest, start = m.group("key").strip(), m.group("rest").strip(), i
            i += 1
            if rest:
                self._add(Block(key, start, i, "scalar", _unquote(rest)))
                continue
            items = []
            while i < self.fm_hi and (im := ITEM_RE.match(self.lines[i])):
                items.append(_unquote(im.group("val")))
                i += 1
            if items:
                self._add(Block(key, start, i, "list", items))
            else:
                # `Chapter:` with nothing after it. Empty scalar, not a list —
                # an empty list would render as `Chapter:` anyway.
                self._add(Block(key, start, i, "scalar", ""))

    def _add(self, b):
        k = b.key.lower()
        if k not in self.blocks:
            self.order.append(k)
        self.blocks[k] = b

    # -- reading ---------------------------------------------------------

    def get(self, key, default=""):
        b = self.blocks.get(key.lower())
        return default if b is None else b.value

    def spelling(self, key, fallback):
        b = self.blocks.get(key.lower())
        return b.key if b else fallback

    def extras(self):
        """Keys this app does not own, in file order — surfaced, never touched."""
        return {self.blocks[k].key: self.blocks[k].value
                for k in self.order if k not in OWNED}

    def body(self):
        if self.fm_hi is None:
            return "\n".join(self.lines).strip()
        return "\n".join(self.lines[self.fm_hi + 1:]).strip()

    # -- writing ---------------------------------------------------------

    def _splice(self, key, newlines):
        b = self.blocks.get(key.lower())
        if b is not None:
            self.lines[b.start:b.end] = newlines
        elif not newlines:
            return
        elif self.fm_hi is not None:
            self.lines[self.fm_hi:self.fm_hi] = newlines
        else:
            self.lines[0:0] = [FENCE] + newlines + [FENCE]
        self._parse()                 # cheap, and beats shifting every index

    def set_scalar(self, key, value, spelling=None):
        name = self.spelling(key, spelling or key)
        text = _quote(value) if value not in (None, "") else ""
        self._splice(key, [f"{name}: {text}" if text else f"{name}:"])

    def set_list(self, key, items, spelling=None):
        name = self.spelling(key, spelling or key)
        items = [str(x).strip() for x in items if str(x).strip()]
        self._splice(key, [f"{name}:"] + [f"  - {_quote(x)}" for x in items])

    def drop(self, key):
        self._splice(key, [])

    def render(self):
        # Roughly a quarter of the vault's notes end without a trailing
        # newline. Adding one would be a diff in every such file for no reason,
        # so the file keeps whatever it arrived with.
        text = "\n".join(self.lines)
        return text + "\n" if self.eol_at_eof else text


# ------------------------------------------------------------------ series

def _tags_of(note):
    v = note.get("tags", [])
    if isinstance(v, list):
        return v
    return [t.strip() for t in str(v).split(",") if t.strip()] if v else []


def series_from_note(note):
    """The shape the API and the UI speak."""
    st = note.path.stat()
    return {
        "name": note.path.stem,
        "chapter": parse_num(note.get("chapter")),
        "rating": parse_num(note.get("rating")),
        "status": str(note.get("reading status") or ""),
        "pub": str(note.get("publication status") or ""),
        "type": str(note.get("type") or ""),
        "tags": _tags_of(note),
        "cover": str(note.get("cover") or ""),
        "extras": note.extras(),
        "body": note.body(),
        "mtime": st.st_mtime,
    }


def _current(note, field):
    if field in LIST_FIELDS:
        return _tags_of(note)
    return note.get(FIELD_KEYS[field].lower(), "")


def _unchanged(field, cur, new):
    """Compare by meaning, not by spelling.

    `Rating: 3.0` and `Rating: 3` are the same rating, and rewriting one as the
    other would put a diff in 90 notes the first time anything saved. A field
    that did not actually change is never written, which also leaves mtimes —
    and so syncthing, and the fingerprint cache — alone.
    """
    if field in NUM_FIELDS:
        return parse_num(cur) == parse_num(new)
    if field in LIST_FIELDS:
        norm = lambda xs: [str(x).strip() for x in (xs or []) if str(x).strip()]
        return norm(cur) == norm(new)
    return str(cur or "").strip() == str(new or "").strip()


def apply_fields(note, fields):
    """Apply a partial field dict to a note. Returns the fields actually changed.

    Unknown field names are ignored rather than written, so a stale or hostile
    client cannot invent frontmatter keys.
    """
    changed = []
    for field, value in fields.items():
        if field not in FIELD_KEYS:
            continue
        if _unchanged(field, _current(note, field), value):
            continue
        key = FIELD_KEYS[field]
        if field in LIST_FIELDS:
            note.set_list(key.lower(), value or [], spelling=key)
        elif field in NUM_FIELDS:
            note.set_scalar(key.lower(), fmt_num(parse_num(value)), spelling=key)
        else:
            note.set_scalar(key.lower(), str(value or "").strip(), spelling=key)
        changed.append(field)
    return changed


# ------------------------------------------------------------------- files

def series_dir(vault):
    return Path(vault) / SERIES_DIR


def series_path(vault, name):
    """Resolve a series name to its note, refusing anything that escapes Series/."""
    name = (name or "").strip()
    if not name or name.startswith(".") or "/" in name or "\\" in name or "\x00" in name:
        raise ValueError("invalid series name")
    root = series_dir(vault).resolve()
    p = (root / f"{name}.md").resolve()
    if p.parent != root:
        raise ValueError("invalid series name")
    return p


def read_note(path):
    return Note(path, Path(path).read_text(encoding="utf-8"))


def write_note(note):
    """Replace the file atomically, preserving its mode.

    Same-directory temp file plus os.replace, so a reader — Obsidian, syncthing
    — sees either the old file or the new one and never a half-written note.
    """
    path = note.path
    text = note.render()
    fd, tmp = tempfile.mkstemp(dir=str(path.parent), prefix=".rt-", suffix=".tmp")
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(text)
            fh.flush()
            os.fsync(fh.fileno())
        if path.exists():
            os.chmod(tmp, path.stat().st_mode & 0o7777)
        os.replace(tmp, path)
    except BaseException:
        Path(tmp).unlink(missing_ok=True)
        raise


def scan(vault):
    """Every note under Series/, newest-first name order left to the caller."""
    out = []
    d = series_dir(vault)
    if not d.is_dir():
        return out
    for p in sorted(d.glob("*.md")):
        if p.name.startswith("."):
            continue
        try:
            out.append(series_from_note(Note(p, p.read_text(encoding="utf-8"))))
        except (OSError, UnicodeDecodeError):
            continue                  # a note we cannot read is not a reason to 500
    return out


def vault_fingerprint(vault):
    """Cheap change detector: one stat per note.

    300 stats is well under a millisecond, so every request can check whether
    Obsidian touched anything rather than trusting a cache with a timeout.
    """
    d = series_dir(vault)
    if not d.is_dir():
        return ()
    return tuple(sorted(
        (p.name, p.stat().st_mtime_ns, p.stat().st_size)
        for p in d.glob("*.md") if not p.name.startswith(".")
    ))


def trash(vault, name):
    """Move a note into the vault's .trash/, where Obsidian can restore it."""
    src = series_path(vault, name)
    if not src.exists():
        raise FileNotFoundError(name)
    dest_dir = Path(vault) / TRASH_DIR
    dest_dir.mkdir(exist_ok=True)
    dest = dest_dir / src.name
    n = 1
    while dest.exists():
        dest = dest_dir / f"{src.stem} ({n}).md"
        n += 1
    os.replace(src, dest)
    return dest


def cover_id(url):
    return hashlib.sha256((url or "").encode("utf-8")).hexdigest()[:20]
