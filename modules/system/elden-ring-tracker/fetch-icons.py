#!/usr/bin/env python3
"""Vendor the tracker's artwork.

Run by hand, not by systemd — unlike seed.py this one talks to the internet,
and the whole point is that the result is committed so the live service never
does. Two passes:

  resolve   figure out a source URL for every item, write icons.map.json
  fetch     download those URLs into icons/, convert to WebP, write icons.json

`icons.json` is what seed.py reads: {key: filename}, keyed on
"<section id>\\x1f<item name>" — deliberately *not* the full ukey, which carries
a position that shifts whenever the list is edited. Same name in the same
section means the same picture, so this dedupes for free.

Two sources, because they cover different things:

  eldenring.wiki.gg   Equipment. A real MediaWiki API, and the icon filenames
                      are mechanical: "ER Icon <kind> <exact item name>.png".
                      One bulk listing of the whole File: namespace resolves
                      most of the list offline, with no per-item requests.

  Fextralife          Bosses and NPCs, which wiki.gg has no icon assets for.
                      Not MediaWiki — no API, so this reads the og:image meta
                      tag off each page. One request per item, rate limited.

Neither is hit at runtime, and neither needs to be up for the tracker to work.

    python3 fetch-icons.py resolve      # ~5 min, writes icons.map.json
    python3 fetch-icons.py fetch        # ~5 min, writes icons/ + icons.json
    python3 fetch-icons.py resolve --only boss,quest    # redo one section
"""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

HERE = Path(__file__).resolve().parent
SEED = Path(os.environ.get("ER_SEED", HERE / "seed.json"))
MAP = HERE / "icons.map.json"
MANIFEST = HERE / "icons.json"
ICONS = HERE / "icons"

WIKIGG = "https://eldenring.wiki.gg/api.php"
FEXTRA = "https://eldenring.wiki.fextralife.com"

# wiki.gg is fine with a bot that identifies itself. Fextralife is a plain
# website behind a CDN and only serves a browser UA, so it gets one.
UA_API = "elden-ring-tracker/1.0 (personal completion tracker; one-shot asset fetch)"
UA_WEB = ("Mozilla/5.0 (X11; Linux x86_64; rv:128.0) "
          "Gecko/20100101 Firefox/128.0")

# Which "ER Icon <kind> …" prefixes to try, per section, in order. Sections
# absent from this map have no equipment icons and fall through to Fextralife
# or to nothing at all.
PREFIXES = {
    "tal":  ["Talisman"],
    "ash":  ["Ash", "ash", "Spirit Ash"],
    "sor":  ["Spell", "sorcery"],
    "inc":  ["Spell", "incantation"],
    "aow":  ["ash of war", "Ash of War"],
    "wep":  ["weapon", "Weapon"],
    "shl":  ["shield", "Shield"],
    "tear": ["Key Item", "Tool"],
    "coll": ["Tool", "Key Item", "Consumable", "Bolstering", "Book", "Cookbook",
             "Flask", "Crafting", "material", "Scroll", "Map", "rune"],
    "rune": ["rune", "Key Item", "Tool"],
    "max":  ["Tool", "Key Item", "Bolstering", "Flask"],
    "leg":  ["Talisman", "weapon", "Weapon", "Spell", "Ash", "ash", "Armor"],
}

# Crystal Tears ship as a mirrored pair; either half is the same flask.
SUFFIXES = ["", " (Right)", " (Left)"]

# Sections whose entries are creatures and people rather than objects.
PORTRAIT = {"boss", "quest"}

# Armor icons are per-piece and the list tracks whole sets, so a set has to
# pick a representative. Headgear reads best at 64px — it is the silhouette
# you recognise — and (Altered) variants are the same piece with the cape off.
HEADGEAR = re.compile(r"\b(helm|helmet|hood|hat|mask|crown|cap|circlet|tiara|"
                      r"veil|headband|coif|horn|diadem)\b", re.I)


def log(*a):
    print(*a, file=sys.stderr, flush=True)


def get(url, ua=UA_API, tries=3, timeout=45):
    last = None
    for n in range(tries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": ua})
            return urllib.request.urlopen(req, timeout=timeout).read()
        except urllib.error.HTTPError as e:
            if e.code == 404:
                return None
            last = e
        except Exception as e:
            last = e
        time.sleep(1.5 * (n + 1))
    raise last


def api(params):
    params["format"] = "json"
    body = get(WIKIGG + "?" + urllib.parse.urlencode(params))
    return json.loads(body)


def items_by_section():
    """[(section id, group name, item name)] in seed order."""
    out = []
    for sec in json.loads(SEED.read_text()):
        for grp in sec["g"]:
            for raw in grp["items"]:
                name = raw.split("::")[0] if isinstance(raw, str) else raw["n"].split("::")[0]
                out.append((sec["id"], grp["name"], name))
    return out


# --------------------------------------------------------------------------
# wiki.gg


def icon_index():
    """Every File:ER Icon … on the wiki, keyed on the part after the prefix."""
    idx = defaultdict(list)
    cont, pages = None, 0
    while True:
        p = {"action": "query", "list": "allimages", "aiprefix": "ER Icon",
             "ailimit": "500", "aiprop": "url"}
        if cont:
            p["aicontinue"] = cont
        d = api(p)
        for i in d["query"]["allimages"]:
            bare = i["name"][:-4].replace("_", " ")
            m = re.match(r"ER Icon (.+)", bare)
            if m:
                idx[m.group(1).lower()].append(i["name"])
        pages += 1
        cont = d.get("continue", {}).get("aicontinue")
        if not cont:
            break
    log(f"  wiki.gg icon index: {sum(len(v) for v in idx.values())} files "
        f"in {pages} requests")
    return idx


def thumb(filename, width):
    """MediaWiki's scaler. No hash path needed, and it caches the result."""
    q = urllib.parse.quote(filename.replace(" ", "_"))
    return f"https://eldenring.wiki.gg/images/thumb/{q}/{width}px-{q}"


def match_icon(idx, section, name):
    # Filenames drop the colon in "Aspects of the Crucible: Breath", so try
    # the punctuation-stripped form as well as the literal one.
    forms = [name]
    bare = name.replace(":", "")
    if bare != name:
        forms.append(bare)
    for pref in PREFIXES.get(section, []):
        for form in forms:
            for suf in SUFFIXES:
                hit = idx.get(f"{pref} {form}{suf}".lower())
                if hit:
                    return sorted(hit)[0]
    return None


def armor_icons(names):
    """Set page -> its per-piece icons. 25 titles a request."""
    found = {}
    for i in range(0, len(names), 25):
        batch = names[i:i + 25]
        d = api({"action": "query", "titles": "|".join(batch), "prop": "images",
                 "imlimit": "500", "redirects": "1"})["query"]
        norm = {r["from"]: r["to"] for r in d.get("normalized", [])}
        redir = {r["from"]: r["to"] for r in d.get("redirects", [])}
        pages = {
            pg["title"]: [x["title"][len("File:"):] for x in pg.get("images", [])
                          if x["title"].startswith("File:ER Icon Armor")]
            for pg in d["pages"].values()
        }
        for n in batch:
            t = norm.get(n, n)
            found[n] = pages.get(redir.get(t, t), [])
        time.sleep(0.2)
    return found


def pick_piece(pieces):
    """One icon to stand for a set: headgear if there is any, unaltered."""
    plain = [p for p in pieces if "(Altered)" not in p] or list(pieces)
    heads = [p for p in plain if HEADGEAR.search(p)]
    return sorted(heads or plain)[0] if plain else None


def armor_by_stem(idx, name):
    """Fallback for sets with no page of their own.

    Eight sets (Nox Monk, Blue Silver, Shaman…) are only rows on the shared
    Armor Sets page, so the page lookup finds nothing — but their pieces are
    named after them, so the icon index still has them under "Armor <set stem>
    <piece>". Match on the stem and pick a piece the usual way.
    """
    stem = re.sub(r"\s+Set$", "", name).lower()
    hits = [f for key in idx if key.startswith(f"armor {stem}") for f in idx[key]]
    pieces = [f[len("ER Icon Armor "):-4].replace("_", " ") for f in hits]
    pick = pick_piece(pieces)
    return f"ER Icon Armor {pick}.png" if pick else None


# --------------------------------------------------------------------------
# Fextralife


# Fights and NPCs the list names differently from the wiki. Heuristics get
# everything else; these are just different words for the same thing, and
# guessing harder would only make the rules wrong somewhere else.
ALIASES = {
    # Fextralife has no Iji page at all; wiki.gg files him as War Counselor Iji
    # and redirects the bare name, so this one lands via the infobox fallback.
    "Iji the Blacksmith": "Iji",
    "Sir Gideon Ofnir": "Sir Gideon Ofnir the All-Knowing",
    "Vyke, Knight of the Roundtable": "Roundtable Knight Vyke",
    "Count Ymir, Mother of Fingers": "Ymir, Mother of Fingers",
    "Godskin Duo": "Godskin Apostle",
    "Sir Gideon Ofnir": "Gideon Ofnir",
    "Crystalian Spear & Crystalian Staff": "Crystalian",
    "Crystalian Spear & Crystalian Ringblade": "Crystalian",
    "Putrid Crystalian Trio": "Crystalian",
}


def slugs(name):
    """Candidate page titles for a boss or NPC, best guess first.

    Most of the work is undoing disambiguation the list adds and the wiki does
    not have: parentheticals, "Duo"/"Trio"/"second", "and allies", and the
    "A & B" / "A / B" pairs the wiki files under either half alone.
    Apostrophes are real and must survive — Night's Cavalry is not Nights
    Cavalry.
    """
    if name in ALIASES:
        return [ALIASES[name]]
    n = re.sub(r"\s*\([^)]*\)", "", name).strip()
    n = re.sub(r"\s+and allies$", "", n, flags=re.I).strip()
    n = re.sub(r"\s+(Duo|Trio|second|third|first)$", "", n, flags=re.I).strip()
    out = []
    for part in (p.strip() for p in re.split(r"\s*[/&]\s*", n)):
        if not part:
            continue
        out += [part, part.replace(",", ""), part.split(",")[0].strip(),
                re.sub(r"^The\s+", "", part)]
    out.append(n.replace("-", " "))
    seen = set()
    return [x for x in out if x and not (x in seen or seen.add(x))]


OG = re.compile(r'<meta\s+property="og:image"\s+content="([^"]+)"', re.I)
INFOBOX = re.compile(r"\|\s*image\s*=\s*([^\n|}<]+)")


def wikigg_infobox(names, width):
    """Last resort for people wiki.gg has a page for but no icon asset.

    Reads the infobox's `image =` straight out of the wikitext. Curation is
    worse than Fextralife's — a few resolve to a generic screenshot, and
    Rugalea lands on the plain Runebear — so this only runs on what is left.
    """
    # Same title-guessing as Fextralife: "Iji the Blacksmith" is filed as Iji.
    cands, owner = [], {}
    for n in names:
        for c in slugs(n) + [n]:
            if c not in owner:
                owner[c] = n
                cands.append(c)

    found = {}
    for i in range(0, len(cands), 25):
        batch = cands[i:i + 25]
        d = api({"action": "query", "titles": "|".join(batch), "prop": "revisions",
                 "rvprop": "content", "rvslots": "main", "redirects": "1"})["query"]
        norm = {r["from"]: r["to"] for r in d.get("normalized", [])}
        redir = {r["from"]: r["to"] for r in d.get("redirects", [])}
        pages = {}
        for pg in d["pages"].values():
            if "missing" in pg:
                continue
            m = INFOBOX.search(pg["revisions"][0]["slots"]["main"]["*"])
            if m and m.group(1).strip():
                pages[pg["title"]] = m.group(1).strip()
        for c in batch:
            t = norm.get(c, c)
            f = pages.get(redir.get(t, t))
            if f and owner[c] not in found:
                found[owner[c]] = thumb(f, width)
        time.sleep(0.2)
    return found


def fextra_image(name, literal_first=False):
    # Equipment keeps its parenthetical — "Greatsword of Radahn (Light)" is a
    # different weapon from the (Lord) one, so stripping it would be wrong.
    cands = slugs(name)
    if literal_first and name not in cands:
        cands.insert(0, name)
    for cand in cands:
        path = urllib.parse.quote(cand.replace(" ", "+"), safe="+")
        body = get(f"{FEXTRA}/{path}", ua=UA_WEB, tries=2)
        if body is None:
            continue
        m = OG.search(body.decode("utf-8", "replace"))
        if m and "/file/" in m.group(1) and not m.group(1).endswith("/logo.png"):
            return m.group(1)
    return None


# --------------------------------------------------------------------------


def cmd_resolve(args):
    only = set(args.only.split(",")) if args.only else None
    rows = items_by_section()
    if only:
        rows = [r for r in rows if r[0] in only]

    out = json.loads(MAP.read_text()) if MAP.exists() and only else {}
    known = {(s, n) for s, _, n in rows}

    equip = [(s, n) for s, _, n in rows if s in PREFIXES]
    armor = [(s, n) for s, _, n in rows if s == "arm"]
    people = [(s, n) for s, _, n in rows if s in PORTRAIT]

    idx = icon_index() if (equip or armor) else {}

    if equip:
        log("resolving equipment against wiki.gg…")
        for s, n in equip:
            f = match_icon(idx, s, n)
            if f:
                out[f"{s}\x1f{n}"] = {"src": thumb(f, args.width), "kind": "icon"}

    if armor:
        log(f"resolving {len(set(n for _, n in armor))} armor sets…")
        got = armor_icons(sorted({n for _, n in armor}))
        for s, n in armor:
            piece = pick_piece(got.get(n, [])) or armor_by_stem(idx, n)
            if piece:
                f = piece if piece.startswith("ER Icon") else f"ER Icon Armor {piece}"
                if not f.endswith(".png"):
                    f += ".png"
                out[f"{s}\x1f{n}"] = {"src": thumb(f, args.width),
                                      "kind": "icon", "via": piece}

    if people:
        uniq = sorted({n for _, n in people})
        log(f"resolving {len(uniq)} bosses/NPCs against Fextralife "
            f"(one request each, rate limited)…")
        sec_of = {n: s for s, n in people}
        done = 0
        # Modest concurrency with a delay: fast enough to finish, gentle
        # enough not to look like a scrape to a site with no API.
        def work(n):
            time.sleep(0.25)
            return n, fextra_image(n)
        with ThreadPoolExecutor(max_workers=4) as pool:
            for n, url in pool.map(work, uniq):
                done += 1
                if url:
                    out[f"{sec_of[n]}\x1f{n}"] = {"src": url, "kind": "portrait"}
                if done % 40 == 0:
                    log(f"    {done}/{len(uniq)}")

    # Fextralife carries a handful of armaments wiki.gg has no icon file for
    # (Misericorde, Bonny Butchering Knife…). Only the stragglers, so this is
    # a few requests, not a second pass over the whole list.
    left = [(s, n) for s, n in equip + armor if f"{s}\x1f{n}" not in out]
    if left:
        log(f"  {len(left)} without a wiki.gg icon, trying Fextralife…")
        for s, n in left:
            url = fextra_image(n, literal_first=True)
            if url:
                out[f"{s}\x1f{n}"] = {"src": url, "kind": "icon", "via": "fextralife"}
            time.sleep(0.25)

    # And the reverse for people: wiki.gg has a page for a few NPCs whose
    # Fextralife title we cannot guess.
    left = [(s, n) for s, n in people if f"{s}\x1f{n}" not in out]
    if left:
        log(f"  {len(left)} without Fextralife art, trying wiki.gg infoboxes…")
        got = wikigg_infobox(sorted({n for _, n in left}), args.portrait_width)
        for s, n in left:
            if n in got:
                out[f"{s}\x1f{n}"] = {"src": got[n], "kind": "portrait",
                                      "via": "wikigg-infobox"}

    # Some names appear in more than one section — a boss is also a quest NPC,
    # a legendary armament is also a weapon. One lookup is enough for all of
    # them, and it also papers over a transient miss on a retryable fetch.
    by_name = {}
    for key, meta in out.items():
        by_name.setdefault(key.split("\x1f", 1)[1], meta)
    borrowed = 0
    for s, n in known:
        k = f"{s}\x1f{n}"
        if k not in out and n in by_name:
            out[k] = dict(by_name[n])
            borrowed += 1
    if borrowed:
        log(f"  filled {borrowed} rows from the same name in another section")

    MAP.write_text(json.dumps(out, indent=1, sort_keys=True, ensure_ascii=False))
    hit = len(out)
    total = len({(s, n) for s, _, n in items_by_section()})
    log(f"\nresolved {hit} of {total} rows -> {MAP.name}")
    miss = [f"{s}|{n}" for s, n in sorted(known) if f"{s}\x1f{n}" not in out]
    if miss:
        log(f"unresolved ({len(miss)}): {', '.join(miss[:12])}"
            f"{' …' if len(miss) > 12 else ''}")


def cmd_fetch(args):
    src = json.loads(MAP.read_text())
    ICONS.mkdir(exist_ok=True)
    repaired = {}
    have_cwebp = shutil.which("cwebp")
    if not have_cwebp:
        log("! cwebp not on PATH — keeping originals. "
            "Re-run inside: nix shell nixpkgs#libwebp")

    def name_for(key, url):
        section, item = key.split("\x1f", 1)
        stem = re.sub(r"[^a-z0-9]+", "-", item.lower()).strip("-")[:60]
        return f"{section}-{stem}"

    def one(kv):
        key, meta = kv
        stem = name_for(key, meta["src"])
        final = ICONS / f"{stem}.webp"
        if final.exists() and not args.force:
            return key, final.name, "cached"
        ua = UA_API if "wiki.gg" in meta["src"] else UA_WEB
        try:
            body = get(meta["src"], ua=ua, tries=3)
        except Exception as e:
            return key, None, f"error {e}"
        if not body:
            # Fextralife's og:image sometimes names a file that is not on
            # their server (Curseblade Labirith). Rather than leaving a hole,
            # fall back to wiki.gg's infobox and rewrite the map entry, so the
            # repair sticks for the next run.
            item = key.split("\x1f", 1)[1]
            alt = wikigg_infobox([item], args.portrait).get(item)
            if not alt:
                return key, None, "404, no wiki.gg fallback"
            meta["src"], meta["via"] = alt, "wikigg-infobox (repaired)"
            repaired[key] = meta
            try:
                body = get(alt, ua=UA_API, tries=3)
            except Exception as e:
                return key, None, f"error on fallback {e}"
            if not body:
                return key, None, "404 on fallback too"
        ext = ".png" if body[:8] == b"\x89PNG\r\n\x1a\n" else ".jpg"
        raw = ICONS / f"{stem}{ext}"
        raw.write_bytes(body)
        if have_cwebp:
            # -q 82 is indistinguishable at 64-300px and roughly halves it.
            # Portraits get resized here; wiki.gg already scaled the icons.
            cmd = ["cwebp", "-quiet", "-q", "82"]
            if meta["kind"] == "portrait":
                cmd += ["-resize", str(args.portrait), "0"]
            cmd += [str(raw), "-o", str(final)]
            r = subprocess.run(cmd, capture_output=True)
            if r.returncode == 0:
                raw.unlink()
                return key, final.name, "ok"
            return key, raw.name, "webp failed, kept original"
        return key, raw.name, "ok (no webp)"

    manifest, problems = {}, []
    with ThreadPoolExecutor(max_workers=6) as pool:
        for i, (key, fn, how) in enumerate(pool.map(one, sorted(src.items())), 1):
            if fn:
                manifest[key] = fn
            else:
                problems.append((key.replace("\x1f", "|"), how))
            if i % 100 == 0:
                log(f"    {i}/{len(src)}")

    if repaired:
        src.update(repaired)
        MAP.write_text(json.dumps(src, indent=1, sort_keys=True, ensure_ascii=False))
        log(f"  rewrote {len(repaired)} dead source URL(s) in {MAP.name}")

    MANIFEST.write_text(json.dumps(manifest, indent=1, sort_keys=True,
                                   ensure_ascii=False))
    total = sum(f.stat().st_size for f in ICONS.iterdir() if f.is_file())
    log(f"\n{len(manifest)} images, {total/1e6:.1f} MB in {ICONS.name}/ "
        f"-> {MANIFEST.name}")
    for k, why in problems[:20]:
        log(f"  failed {k}: {why}")


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)

    r = sub.add_parser("resolve", help="find a source URL for every item")
    r.add_argument("--only", help="comma-separated section ids")
    r.add_argument("--width", type=int, default=96,
                   help="wiki.gg thumbnail width (default 96)")
    r.add_argument("--portrait-width", type=int, default=300,
                   help="wiki.gg thumbnail width for people (default 300)")
    r.set_defaults(fn=cmd_resolve)

    f = sub.add_parser("fetch", help="download and convert")
    f.add_argument("--force", action="store_true", help="re-download cached files")
    f.add_argument("--portrait", type=int, default=200,
                   help="max width for boss/NPC art (default 200)")
    f.set_defaults(fn=cmd_fetch)

    a = ap.parse_args()
    a.fn(a)


if __name__ == "__main__":
    main()
