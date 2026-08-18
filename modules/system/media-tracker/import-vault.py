#!/usr/bin/env python3
"""One-shot importer: Obsidian vault -> seed.json.

    python3 import-vault.py                      # reads ~/Media/Books/Reading-Ob
    python3 import-vault.py --vault /path/to/it
    python3 import-vault.py --out seed.json

This is the only thing here that ever opens the vault, and **systemd never runs
it**. Its committed output, `seed.json`, is what ships — the vault on pod042 is
not a dependency of a service on personal-server, and the tracker works with
that laptop shut.

Read-only by construction: there is no write path in this file. The vault was
the live store in the first cut of this module and is now the origin snapshot,
so the direction of travel is one-way and the code should make that impossible
to get wrong.

The notes are Obsidian markdown with the tracked values in YAML frontmatter.
This understands the small subset all 300 use — `Key: scalar`, and `Key:`
followed by `  - item` lines — and folds everything it does not own (the one
`Best Read:` line, note bodies) into a free-text `notes` field so nothing in
the vault is silently dropped on the way across.
"""
import argparse
import json
import re
from collections import Counter
from datetime import date
from pathlib import Path

KEY_RE = re.compile(r"^(?P<key>[A-Za-z][A-Za-z0-9 _/-]*?)\s*:(?P<rest>.*)$")
ITEM_RE = re.compile(r"^\s+-\s*(?P<val>.*)$")

# frontmatter key (lowercased) -> field in seed.json. Both spellings of the tag
# key collapse here: 43 notes write `tags:` and the rest `Tags:`.
FIELDS = {
    "chapter": "chapter",
    "rating": "rating",
    "reading status": "status",
    "publication status": "pub",
    "type": "type",
    "tags": "tags",
    "cover": "cover",
}


def unquote(s):
    s = s.strip()
    if len(s) >= 2 and s[0] == s[-1] and s[0] in "\"'":
        return s[1:-1]
    return s


def parse_num(s):
    try:
        f = float(str(s).strip())
    except (TypeError, ValueError):
        return None
    return int(f) if f.is_integer() else f


def parse(text):
    """(frontmatter dict keyed lowercase, body string)."""
    lines = text.split("\n")
    if not lines or lines[0].strip() != "---":
        return {}, text.strip()
    close = next((i for i in range(1, len(lines)) if lines[i].strip() == "---"), None)
    if close is None:
        return {}, text.strip()

    fm, i = {}, 1
    while i < close:
        m = KEY_RE.match(lines[i])
        if not m:
            i += 1
            continue
        key, rest = m.group("key").strip(), m.group("rest").strip()
        i += 1
        if rest:
            fm[key.lower()] = (key, unquote(rest))
            continue
        items = []
        while i < close and (im := ITEM_RE.match(lines[i])):
            items.append(unquote(im.group("val")))
            i += 1
        fm[key.lower()] = (key, items if items else "")
    return fm, "\n".join(lines[close + 1:]).strip()


def read_series(path):
    fm, body = parse(path.read_text(encoding="utf-8"))
    out = {
        "title": path.stem,
        "chapter": None, "rating": None,
        "status": "", "pub": "", "type": "", "cover": "",
        "tags": [], "notes": "",
    }
    leftovers = []
    for lower, (spelling, value) in fm.items():
        field = FIELDS.get(lower)
        if field is None:
            # Something this app does not model — one note carries `Best Read`.
            # Keep it as text rather than lose it.
            shown = ", ".join(value) if isinstance(value, list) else value
            if str(shown).strip():
                leftovers.append(f"{spelling}: {shown}")
            continue
        if field == "tags":
            out["tags"] = [t.strip() for t in
                           (value if isinstance(value, list) else [])
                           if str(t).strip()]
        elif field in ("chapter", "rating"):
            out[field] = parse_num(value)
        else:
            out[field] = str(value or "").strip()

    notes = [n for n in ([body] + leftovers) if n]
    out["notes"] = "\n".join(notes)
    return out


def main():
    ap = argparse.ArgumentParser(description="Import the Reading-Ob vault into seed.json")
    ap.add_argument("--vault", default=str(Path.home() / "Media/Books/Reading-Ob"))
    ap.add_argument("--out", default=str(Path(__file__).resolve().parent / "seed.json"))
    a = ap.parse_args()

    root = Path(a.vault).expanduser()
    series_dir = root / "Series"
    if not series_dir.is_dir():
        raise SystemExit(f"no Series/ directory under {root}")

    series = [read_series(p) for p in sorted(series_dir.glob("*.md"))
              if not p.name.startswith(".")]
    series.sort(key=lambda s: s["title"].lower())

    payload = {
        "exported": date.today().isoformat(),
        "source": str(root),
        "series": series,
    }
    Path(a.out).write_text(
        json.dumps(payload, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")

    print(f"{len(series)} series -> {a.out}")
    for field in ("status", "pub", "type"):
        c = Counter(s[field] or "—" for s in series)
        print(f"  {field:<7} " + "  ".join(f"{k}:{v}" for k, v in c.most_common()))
    tags = Counter(t for s in series for t in s["tags"])
    print(f"  tags    {len(tags)} distinct, {sum(tags.values())} applied")
    print(f"  covers  {sum(1 for s in series if s['cover'])} of {len(series)}")
    print(f"  notes   {sum(1 for s in series if s['notes'])} carry free text")


if __name__ == "__main__":
    main()
