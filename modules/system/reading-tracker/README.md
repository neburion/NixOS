# Reading tracker

SQLite + a small web UI. Stdlib Python only — no Flask, no pip.

Deployed by `service.nix` on `personal-server`: **http://personal-server:8778**,
tailnet only. See the module tree entry in `ARCHITECTURE.md`.

300 series, 13,316 chapters, imported once from the **Reading-Ob** Obsidian
vault on pod042.

## Files

| file | what it is |
|---|---|
| `service.nix` | systemd unit, cover-warming timer, tailnet firewall rule |
| `schema.sql` | tables, views, FTS5 index |
| `seed.json` | the 300-series origin snapshot |
| `seed.py` | builds the database; **additive**, never overwrites your edits |
| `app.py` | HTTP server + JSON API + cover cache |
| `ui.html` | the UI |
| `import-vault.py` | hand-run, one-way: Obsidian vault → `seed.json` |

## The vault is gone from the loop

`seed.json` was produced once by `import-vault.py` reading
`~/Media/Books/Reading-Ob` on pod042. That is a **snapshot, not a link**:

- The vault is not a dependency of this service. It lives on a laptop; this runs
  on a server, and it works with that laptop shut.
- Edits made here **do not travel back** to the markdown notes.
- Edits made in Obsidian **do not arrive here** unless you re-run
  `import-vault.py`, and even then only as *new* series (see below).

So pick one. Keeping both is how you end up with two half-right shelves.
`import-vault.py` is deliberately read-only — there is no write path in the
file — so the direction of travel cannot be got wrong by accident.

## Seeding is additive

`seed.py` runs as `ExecStartPre` on every start, like the Elden Ring tracker's
seeder, but it does a different job.

There, `seed.json` is the game's reference checklist: the reference tables are
dropped and rebuilt every start, and only your ticks are preserved. Here
everything in `seed.json` — chapter, rating, status — *is* the mutable state the
app exists to edit. Rebuilding it on every start would hand back the reading you
did last week.

| seed entry | what happens |
|---|---|
| never imported before | inserted, and recorded in `seed_applied` |
| already imported | skipped, whatever became of it |
| not from `seed.json` at all | left completely alone |

**Why `seed_applied` exists.** The obvious version of an additive seeder asks
"is this title already in `series`?" — and it is wrong, because a title is not
stable. Rename a series in the app and the next restart sees its original title
missing and imports it a second time, so a duplicate quietly appears after a
reboot. Delete one on purpose and it comes back. Recording what was imported
instead of inferring it closes both holes; the key is the title *as it appears
in `seed.json`*, which never changes because that file is in the read-only
store.

Verified: rename one series and delete another, re-seed twice, and the count
stays at 299 with neither resurrected. A hand-made series that happens to share
a seeded title is adopted rather than duplicated.

`--force-import` re-applies `seed.json` over the rows it originally created.
The vocabularies are the one thing upserted every start, so fixing an ordering
or adding a status is an edit and a redeploy.

## What the database buys

The vault could only ever describe the present: one note per series, each
frontmatter key overwritten in place. Two things follow from owning a real
schema.

**History.** `reading_log` and `status_log` append on every chapter and status
change, so the shelf can answer *what have I actually been reading lately* —
which the notes threw away every time it was answered. The **history** view and
the "this week / this month" figures come from there.

**Integrity.** Status, publication and medium are three closed vocabularies with
foreign keys rather than free text, which is how the vault ended up with one
note reading `Publication Status: Hold` where every other says Hiatus. Tags are
a real many-to-many, so merging two spellings is one `UPDATE` on the join table
instead of rewriting eleven files.

One check is deliberately loose. **Mushoku Tensei is rated −10.** That is not
corrupt data, it is an opinion, and clamping it to fit a 0–10 scale would be
editing a verdict to suit a schema — so the range admits it and the UI slider
goes down to −10.

## Tag spellings

The vault was hand-written over years, so the same tag arrived in more than one
form: `HunterFantasy` / `Hunter Fantasy`, `SchoolLife` / `School Life`,
`Video Game` / `VideoGame`. They mean one thing and filter as two.

Folding them automatically would decide for you which spelling was the mistake,
so the **Tags** view surfaces them and the merge is a button press. `tag_key()`
decides what counts as the same tag: case-folded, non-alphanumerics stripped.
The merge inserts before it deletes, because a series carrying *both* spellings
has to end up with one row rather than a primary-key violation.

## Cover artwork

The cover URLs came across from the vault as DuckDuckGo image-proxy links
pointing at a dozen hosts. Hotlinking 300 of them on every page load is slow,
leaks the shelf to whoever is on the other end, and breaks the day a host
disappears — so each is cached under `/var/lib/reading-tracker/covers/`, keyed
by a hash of the URL. Change a series' cover and the key changes with it, so
there is no cache to bust.

Unlike `elden-ring-tracker`'s `icons/`, these are **not committed**: they are
artwork for whatever happens to be on this shelf, not a fixed reference set.

**180 of the 213 series with a cover resolve. 33 do not**, and are not worth
engineering around — those hosts are gone or have started refusing hotlinks.
Those cards draw a tinted plate with the title set on it, the tint derived from
the title so a book still looks like itself. The 87 series with no cover at all
get the same treatment.

Two cheap recoveries run before giving up: a `Referer` of `duckduckgo.com`
satisfies their proxy sometimes, and when the proxy returns 400 because its
`ipt` signature has expired, the real image URL is sitting in the `u=` query
parameter, so `unproxy()` fetches that instead. Expect the second to matter more
over time as signatures age out.

Failures are remembered for six hours so a dead host is not retried on every
page load. `reading-tracker-covers.timer` warms the cache three minutes after
boot and weekly after, purely so the first page load is not the slow one.

## Where the data lives

`/var/lib/reading-tracker/reading.db` — a `StateDirectory`, so it survives
deploys and reboots. The covers beside it are a cache and cost one re-download
each.

Back it up with the export, which is keyed on title rather than row id and so
survives a rebuilt database:

```bash
curl -su reader:PASSWORD 'http://personal-server:8778/api/export' > reading-backup.json
```

## Running it from a checkout

Paths fall back to beside the script, so a plain checkout works with no
arguments:

```bash
cd modules/system/reading-tracker
python3 seed.py && python3 app.py --open   # 127.0.0.1:8778, db in this directory
python3 app.py --stats                     # print the shelf and exit
python3 app.py --warm-covers
```

Overrides: `RT_DB`, `RT_SEED`, `RT_SCHEMA`, `RT_UI`, `RT_FONTS`, `RT_CACHE`,
`RT_HOST`, `RT_PORT`, `RT_USERNAME`, `RT_PASSWORD`.

`reading-tracker --stats` is also on `PATH` on the host.

## API

| method | path | body / query |
|---|---|---|
| GET | `/api/library` | every series, plus stats, vocabularies, tags, history |
| GET | `/api/search?q=…` | FTS5 prefix search over title, tags, type, notes |
| GET | `/api/history` | the last 200 chapter changes |
| GET | `/api/export` | portable JSON keyed on title |
| POST | `/api/update` | `{id, fields}` — partial; returns which fields changed |
| POST | `/api/bump` | `{id, by, resume}` — chapter +1, optionally un-shelving it |
| POST | `/api/create` | `{title, fields}` |
| POST | `/api/delete` | `{id}` — cascades tags and both logs |
| POST | `/api/tags/merge` | `{from:[tag ids], to: tag id}` |

A field whose value did not change is not written and does not appear in
`changed`, so the logs record real edits rather than every Save.

## Security

HTTP Basic Auth, on whenever a password is present — the systemd credential
`password` (the `reading-tracker-password` sops secret in
`secrets/personal-server.yaml`) or `$RT_PASSWORD`. Without one the app refuses
to bind anything but loopback, so a misconfigured deploy fails to start rather
than putting a writable API on the network. The username is `reader` and lives
in `service.nix`, since it is not a secret.

That is a second gate, not the only one: the `tailscale0`-scoped firewall rule
in `service.nix` limits who can reach :8778. Unlike the Elden Ring tracker this
has **no public hostname** — no Cloudflare tunnel, no Access policy to forget.
If it ever gets one, cloudflared reaches it over loopback and needs no firewall
rule, and the Basic Auth gate is what would stand behind a missing policy.
