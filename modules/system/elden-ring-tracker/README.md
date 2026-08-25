# Elden Ring completion tracker

SQLite + a small web UI. Stdlib Python only — no Flask, no pip.

Deployed by `service.nix` on `personal-server`: **http://personal-server:8777**,
tailnet only. See the module tree entry in `ARCHITECTURE.md`.

## Files

| file | what it is |
|---|---|
| `service.nix` | systemd unit, system user, tailnet firewall rule |
| `schema.sql` | tables, views, FTS5 index |
| `seed.json` | the 1,640-entry reference dataset |
| `links.json` | the implication graph — what a tick settles automatically |
| `seed.py` | rebuilds reference tables from `seed.json`, **keeps progress** |
| `app.py` | HTTP server + JSON API |
| `ui.html` | the UI |
| `fetch-icons.py` | hand-run scraper that vendors the artwork |
| `icons/` | 1,494 WebP files, ~6 MB — the artwork itself |
| `icons.json` | item → filename, read by `seed.py` |
| `icons.map.json` | where each file came from, for re-fetching |

1,704 tickable units across 17 sections (1,640 rows; tallies like the 45 Golden
Seeds and 104 Cookbooks count for more than one).

## Where the data lives

`/var/lib/elden-ring-tracker/eldenring.db` on the host — a `StateDirectory`, so
it survives deploys and reboots. Everything else is read-only in the Nix store.

Back it up with the UI's **Export JSON**, which keys on item names rather than
row ids and therefore survives a schema rebuild:

```bash
curl -s 'http://personal-server:8777/api/export?profile=1' > er-backup.json
```

## Editing the dataset

Edit `seed.json`, `git push`, `rebuild personal-server`. `seed.py` runs as
`ExecStartPre` on every start, rebuilds the reference tables, and re-attaches
progress by natural key (section + group + item + position), so ticks survive.
It logs a warning to the journal if a progress row loses its item:

```bash
ssh personal-server journalctl -u elden-ring-tracker -n 30
```

## Derived entries

Much of the list is redundant by nature: killing Godrick *is* the Shardbearer
Godrick achievement, *is* the Remembrance of the Grafted, *is* Godrick's Great
Rune. Ticking four boxes for one kill is busywork and drifts out of sync.

`links.json` declares those implications. A target is satisfied when all its
sources are; targets render read-only with an `auto` chip, and `POST /api/set`
refuses them with **409**. Tick the prerequisite instead. One Godrick tick
settles four units.

Sources can be a single item, every item in a group (the legendary sets), or a
tally threshold — 14 flask charges needs 30 of the 45 Golden Seeds, not all.

Every reference is resolved at seed time and **an unresolvable or ambiguous one
aborts the seed**. A silently dropped link would be indistinguishable from
"you haven't done it yet", which is the worst possible failure for a checklist.
Names that repeat inside a section (`Mohg, the Omen` appears in both Leyndell
variants) must be qualified as `section|Group|Item`.

Relations that are "any of" rather than "all of" are deliberately left manual,
because a tick can't be traced back to one cause: the **Elden Lord** achievement
(any of four endings) and **Great Rune** (any one Divine Tower).

`seed.py` migrates in both directions. If an entry becomes derived while you
already ticked it, the tick is pushed down onto its sources — ticking
"Shardbearer Godrick" means you demonstrably killed Godrick — and the stored row
is removed so the computed value takes over. Without that, turning items derived
would silently zero them.

## Gauges

Three kinds of row. A **check** is one box. A **tally** is worth its target and
every point counts — 47 gestures really are 47 things to find. A **gauge** is a
figure you carry rather than a pile of things to collect: Vigor, flask charges,
Scadutree Blessing. It shows where you are on the way there (`55/99`, with a
bar), takes a typed number rather than a checkbox, and is worth **one** unit
like the check it replaced.

That last part is the point. Weighting the eight attributes by their figures
would add 792 units to a 1,704-unit list and let levelling drown out every item
in the game. `weight()` and `earned()` in `app.py` are the one place that
distinction lives; `rowUnit()`/`rowGot()` in `ui.html` are the same sum on the
client so a keystroke feels instant.

```json
{"n": "Vigor", "gauge": 99}
{"n": "Gestures", "max": 47}
```

`schema.sql` is written with `CREATE TABLE IF NOT EXISTS`, so an existing
database keeps the `CHECK (kind IN …)` it was born with and rejects a kind
added later. `migrate_kinds()` compares the live constraint against the schema
file and rebuilds the table when the schema has grown a kind — progress is read
out first and re-attached by `ukey` afterwards, exactly like any other reseed.
A row that changes from check to gauge carries its tick across as the full
figure, because a ticked box meant done and `1/99` would not.

## Artwork

1,543 of the 1,640 rows carry a picture, served from `icons/` at `/img/…`
behind the same auth gate as everything else. Equipment gets its transparent
96px game icon; bosses and quest NPCs get a landscape screenshot cropped to a
plate, because no icon assets exist for them.

The remaining 97 rows are abstractions — achievements, endings, `Vigor 99`,
`All cookbook recipes learned` — and no artwork exists for them anywhere. They
render with the space where the icon would be, which is the honest answer.

**The images are committed, not fetched.** Neither wiki is a dependency of this
service: nothing downloads at build time or at run time, and the tracker works
with both of them offline or gone. `fetch-icons.py` is the only thing here that
touches the network, it is never run by systemd, and its output is what ships.

```bash
python3 fetch-icons.py resolve      # find a source for every row -> icons.map.json
nix shell nixpkgs#libwebp --command python3 fetch-icons.py fetch
python3 fetch-icons.py resolve --only boss,quest   # redo one section
```

`resolve` tries three sources in order. **wiki.gg**'s API covers all equipment:
its icon filenames are mechanical (`ER Icon <kind> <exact item name>.png`), so
one bulk listing of the File: namespace resolves ~1,200 rows offline in six
requests. **Fextralife** covers bosses and NPCs, which wiki.gg has no icon
assets for, by reading the `og:image` meta tag off each page — no API exists, so
that is one request per row. **wiki.gg infoboxes** catch the stragglers by
pulling `image =` out of the raw wikitext.

Most of the work is undoing disambiguation this list adds and the wikis do not
have: parentheticals, `Duo`/`Trio`/`and allies`, and `A & B` pairs the wiki
files under either half alone. `ALIASES` in the script holds the nine entries
where the two simply use different names (`Iji the Blacksmith` is wiki.gg's
`War Counselor Iji`). Apostrophes must survive — Night's Cavalry is not Nights
Cavalry.

Two things to know. Fextralife's `og:image` occasionally names a file missing
from their own server, so `fetch` falls back to wiki.gg and **rewrites the map
entry** so the repair sticks. And roughly one boss portrait in twenty is simply
the wrong picture on their end — `Kindred of Rot` currently shows a miner prawn.
Both are worth an eyeball pass after a re-fetch.

## Runs

Each **run** is a profile with its own progress, because Elden Ring's endings and
~10 questlines are mutually exclusive in one save. Make one per playthrough, then
hit **All runs**: it unions every profile and filters down to entries never
finished in *any* run. That is the real 100% list.

## Running it from a checkout

The scripts fall back to paths beside themselves when the `ER_*` variables are
unset, so a plain checkout works with no arguments:

```bash
cd modules/system/elden-ring-tracker
python3 seed.py && python3 app.py --open   # 127.0.0.1:8777, db in this directory
```

Overrides: `ER_DB`, `ER_SEED`, `ER_SCHEMA`, `ER_UI`, `ER_HOST`, `ER_PORT`.
`python3 app.py --stats` prints per-section bars for every run plus the union.

## API

| method | path | body / query |
|---|---|---|
| GET | `/api/tree?profile=N` | sections → groups → items, with values |
| GET | `/api/stats?profile=N` | totals overall and per section |
| GET | `/api/search?q=…&profile=N` | FTS5 prefix search over name, detail, group, section |
| GET | `/api/coverage` | union across all runs + everything never finished |
| GET | `/api/export?profile=N` | portable JSON keyed on `ukey` |
| POST | `/api/set` | `{profile, item, value}` — clamped to the item's target |
| POST | `/api/profiles` | `{name, note}` |
| POST | `/api/profiles/rename` | `{profile, name}` |
| POST | `/api/profiles/delete` | `{profile}` — refuses to delete your last run |
| POST | `/api/reset` | `{profile}` — clears ticks, keeps the run |
| POST | `/api/import` | `{profile, progress:[{ukey, value}]}` |

## Security

HTTP Basic Auth, on whenever a password is present — the systemd credential
`password` (the `elden-ring-password` sops secret) or `$ER_PASSWORD`. Without
one the app refuses to bind anything but loopback, so a misconfigured deploy
fails to start rather than serving the ledger to the internet.

A successful login also sets `er_session`, a signed cookie good for 30 days and
re-issued whenever it drops under 21 days left, so the password is typed about
once a month instead of once per browser session. It is a signed expiry
timestamp rather than a session id, so a restart logs nobody out; the signing
key is derived from the password, so rotating the sops secret invalidates every
outstanding cookie. Same mechanism as the reading tracker.

That is a second gate, not the only one: the `tailscale0`-scoped firewall rule
in `service.nix` still limits who can reach :8777, and the Cloudflare tunnel to
`eldenring.azuresalt.app` wants an Access policy in front of it — `cf-reconcile`
does not manage Access, so a tunnel with no policy leans on Basic Auth alone.

## Sources

Fextralife and wiki.gg Elden Ring wikis, PowerPyx, Game8. Current through Shadow
of the Erdtree. Boss lists cover named and unique encounters; ordinary field and
dungeon repeats are not listed individually. Consumables, crafting materials and
Stonesword Keys are excluded as renewable or trivial — the one exception is the
Sacrificial Twig, which is consumable but sits in the talisman list in-game, and
the talisman section is complete on purpose.
