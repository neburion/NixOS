# Reading tracker

SQLite + a small web UI. Stdlib Python only — no Flask, no pip.

Deployed by `service.nix` on `personal-server`: **http://personal-server:8778**
on the tailnet, and publicly at **https://reading.azuresalt.app** through the
Cloudflare tunnel declared in the host's `cloudflare-layout.nix`.
See the module tree entry in `ARCHITECTURE.md`.

918 series. 300 came from the **Reading-Ob** Obsidian vault on pod042; the
other 617 from an Anime-Planet export (`export-manga-Jacine0520.json`) of an
older account, imported 2026-08-17. Both are snapshots — see below.

## Files

| file | what it is |
|---|---|
| `service.nix` | systemd unit, cover-warming timer, tailnet firewall rule |
| `schema.sql` | tables, views, FTS5 index |
| `seed.json` | the origin snapshot: 300 vault series + 617 from Anime-Planet |
| `tags.json` | every title classified on the two tag axes, applied once |
| `anime-planet.json` | publication status + type looked up on Anime-Planet, applied once |
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

## Tags are on two axes

The vault's tags were a flat pile of 59, written by hand over years, in which
`Fantasy` (half the shelf), `Transmigrassion` (a typo, 109 series) and `Boxing`
(one series) were peers in one alphabetical menu. Eighteen of the 59 were used
twice or less, and six were the same tag spelled two ways.

They are now a closed vocabulary of 25, and every one of them answers exactly
one question:

| axis | question | e.g. |
|---|---|---|
| **setting** | where does it take place | Fantasy, Murim, Wuxia, Modern, Hunter Fantasy, Apocalypse, Academy |
| **genre** | what does reading it feel like | Action, Adventure, Romance, Horror, Slice of Life |

The axis is a column on `tag`, and it is what makes the filters work: two tag
dropdowns holding different kinds of thing, ANDed, rather than one 59-item menu
in which picking Fantasy meant not picking Action. A tag typed straight into the
sheet gets no axis and shows up under **Unfiled** until it is given one.

There was a third axis for a while — **premise**, holding Transmigration,
Regression, System, Revenge and eleven more. It described the shelf accurately
and it is gone anyway, because it was not asked for. `tag-drop-premise` in
`seed.py` removes it; three series wore nothing else and are re-read from
`tags.json` so that losing an axis does not mean losing a series from the
filters.

**Wuxia, not Xianxia.** They were separate for one revision — Chinese immortal
cultivation against Korean martial arts — and are now one tag under the name
that gets said out loud. `Murim` stays separate.

`tags.json` holds the classification for every title. It was built from three
layers, in increasing authority: regex over the title — which works far better
here than it should, because this genre names its books after their own
synopsis — then the tags the vault already carried, then a hand-written table
for the ~380 whose titles give nothing away. Each axis is capped (2 settings,
3 genres), keeping the rarest, because eight true tags is not a classification,
it is the synopsis again.

It is applied **once**, as a recorded migration, not on every start: replacing a
series' tags is destructive of anything typed by hand, and a seeder that
re-applied it would undo your edits on the next reboot. That is the same reason
`seed_applied` exists — see below.

### Spellings

`tag_key()` still backs a merge tool in the **Tags** view — case-folded,
non-alphanumerics stripped — for spellings typed into the sheet by hand. It is
a net now rather than the standing condition it was when the tags came out of
the vault, so the panel only appears when there is something in it. The merge
inserts before it deletes, because a series carrying *both* spellings has to end
up with one row rather than a primary-key violation.

## Vocabularies, and what each one is asking

Three closed sets, and the whole point is that they ask different questions.
They were easy to confuse when the menus were unlabelled, and the vault had in
fact confused two of them:

| field | the question | values |
|---|---|---|
| **status** — *Shelf* | where **you** are with it | Reading, Later, Hold, Read, Dropped |
| **pub** — *Publication status* | whether the **author** is still writing it | Ongoing, Hiatus, Completed, Cancelled |
| **type** — *Type* | what it is | Manhwa, Manhua, Manga, Web Novel, Indonesian Comic |

`Hold` used to appear in *both* status and pub, on the strength of one vault
note reading `Publication Status: Hold`. Hold is a shelf. That value is retired
and the note reads Hiatus; the migration is `pub-drop-hold` in `seed.py`.

Every filter dropdown carries its question above it rather than a placeholder
describing what it will accept — "Any publication" told you what the menu held
and never what it was for. **Order** comes first, being the one control that
changes the shelf rather than narrowing it.

The filters do not survive leaving the shelf. Going to Stats or Tags clears
them and hides the control that opens them, because the alternative was
returning to a shelf quietly showing a third of itself with the only evidence a
lit icon inside a closed drawer.

## Ratings are 0–10

They were once −10 to 10, to admit a single series rated −10. That was a verdict
rather than a score; it is 0 now, the `CHECK` in `schema.sql` is `0..10`, and
both writers — `update_series()` in app.py, `clamp_rating()` in seed.py — refuse
a negative. Databases created before the change keep the wider `CHECK`, since
rebuilding a table to tighten a constraint is not worth the risk to the reading
history hanging off it, and nothing can write a negative through it anyway.

## Stats has no recommendations, and no clock

It used to end with two lists — *shelved and now complete*, *on hold and still
publishing* — computed by joining status against pub. Those were not statistics.
They were the page deciding what you should read next out of two fields that
were never asked that question. They are gone, and what replaced them is a
breakdown of the shelf by setting and genre, which is a fact about the library
rather than a nudge.

The *this week* / *this month* chapter counters are gone too. The reading log
they were computed from is still written on every chapter change — see below.

## No reading-history view, and no light mode


Both are removals of a screen, not of a capability.

`reading_log` is still appended on every chapter change and `/api/history` still
answers; there is simply no tab for it. Putting the view back is a dock button
and a `renderHistory()`. Deleting the log to hide a tab would have been the
expensive half of a cheap decision — a note can only ever hold the number you
are on now, which is the whole reason this is a database.

The theme is dark, full stop: no toggle, no `prefers-color-scheme`, no stored
preference.

## The palette is a neutral scale, and there is no accent

The first dark pass kept the old "paper" palette's warmth — `#14130F` ground,
`#EDE9DC` text — which is a warm near-white on a warm near-black, and reads as
cream rather than as white. The mustard on the Hold marker was only the most
obvious part of it.

It is now [Radix Colors](https://www.radix-ui.com/colors)' `gray` dark scale,
used as designed: a true neutral where R, G and B are equal at every step, with
each step having a documented job — 1 app background, 3 element background, 6
border, 11 low-contrast text, 12 high-contrast text. That numbering is why a
dark UI stops being guesswork about which grey goes where.

The greys are the ground, not the whole palette. Colour sits on top of them in
exactly two places, and both of them mean something.

**The accent is Radix `iris`**, at the steps it was designed for: 9 as a solid
fill (primary button, floating Add), 11 as text on dark (links, active nav), 3
as a subtle tinted background, 7 as a border and focus ring. A dark UI cannot
take a fully saturated hue — it optically vibrates against the ground and
struggles to clear 4.5:1, which is why the advice is uniformly to desaturate
20–30% for dark mode. Radix's dark scales are already built that way, which is
the reason for taking them rather than mixing by hand.

**The shelf markers are three hues and two greys.** Reading is green, Later
blue, Hold orange — the shelves where something is still true of the book.
Read and Dropped are finished states and are told apart by lightness, which
leaves colour to mean *this is live*. The mustard that was on Hold is now
orange at step 11: the same idea at a lightness that reads as orange on a dark
ground rather than as something spilled on it.

Red survives on exactly one control, the one that deletes a series, where it is
semantic rather than decorative.

Placeholder plates for the 605 series with no artwork keep a per-title hue so
they stay distinguishable, at 7% saturation, which reads as a shade rather than
as a colour scheme.

### The selected chip cannot be a solid light fill

It was, for one revision, and Reading's marker vanished into it — a near-white
dot on a near-white chip, on the one shelf you were most likely to be looking
at. That is not a value to nudge; it is the shape of the idea. Any solid light
fill can swallow some marker, and which marker is a property you cannot keep
hold of as the palette changes.

So a selected chip is the tinted-surface pattern instead: `--a3` ground,
`--a7` border, `--a11` label. Both states are dark, so all five markers clear
3:1 in both. Every text colour clears 4.5:1 on all three surface greys — that
is checked, not asserted; `--ink-3` moved off Radix step 9 because step 9 is a
*solid* step, not a text step, and at 3.7:1 it was failing the 11px labels it
was carrying.

## Radius

`--r-sm 4` · `--r-md 6` · `--r-lg 10` · `--r-xl 12`, and full-round for dots
and nothing else.

That is the scale every serious system converged on:
[Vercel's Geist](https://vercel.com/geist) caps functional UI at 12px and uses
6px as standard; [Linear](https://linear.app) uses exactly 6 for controls and
12 for containers; [GitHub's Primer](https://primer.style) sits lower still.
The pass before this one had 999px pills on every button and a 28px sheet lip,
which is a phone-app costume rather than a scale.

## The serif is for titles only

Literata sets book titles — on the cover plates, in the fallback art, and at
the top of the sheet — because that is a name and it is what an e-reader face
is good at. Everything that is interface is Public Sans. Serif section
headings on a tool make it look like a magazine.

## What Anime-Planet was asked, and what it can answer

The export carried a name, a status, a chapter and a rating, and nothing else —
so 617 series arrived with no publication status and 605 with no type.
`anime-planet.json` fills both from the source they came from.

The lookup is AP's own search, which 302s straight to the entry on an exact
name, and these titles *are* AP's names. What the entry page gives:

- **Publication status**, from the year range in the entry bar: `2018 - ?` is
  running, `2018 - 2023` is finished. That is the only signal there — AP does
  not distinguish hiatus or cancellation from completion — so this can produce
  **Ongoing** and **Completed** and nothing else. Hiatus and Cancelled are
  judgements it does not make, and guessing them from a stalled year range
  would put a wrong word on a shelf rather than leave an honest blank.
- **Type**, from the tags: `Manhwa`, `Manhua` and `Light Novels` are tagged
  explicitly, and a Japanese manga carries no medium tag at all because on a
  manga database that is the default. So *no medium tag* means Manga. (`Based
  on a Light Novel` is a source tag and deliberately does not match.)

The backfill is a recorded migration like the others, and it only writes where
the field is **still empty**. Anything already on the shelf beats anything a
lookup says — the same rule the import ran under.

AP answers 429 at any real pace, so the scraper waits 2.5s between calls and
backs off on `Retry-After`.

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
curl -su tracker:PASSWORD 'http://personal-server:8778/api/export' > reading-backup.json
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
than putting a writable API on the network. The username is `tracker` and lives
in `service.nix`, since it is not a secret. Failed attempts are rate-limited to
20 per hour per client IP, read from `CF-Connecting-IP` so the tunnel does not
bucket the whole internet into one key.

A successful login also sets `rt_session`, a signed cookie good for 30 days and
re-issued whenever it drops under 21 days left, so the password is typed about
once a month instead of once per browser session — which on a phone was most
times the app was opened. The cookie is a signed expiry timestamp rather than a
session id, so there is no session table to keep and a service restart does not
log anyone out. The signing key is derived from the password: rotating the sops
secret invalidates every outstanding cookie, which is also the way to force a
logout everywhere. `Secure` is set only when the request arrived over HTTPS, so
the same cookie works on the plain-HTTP tailnet address.

Three layers gate `reading.azuresalt.app`, and two of them are set by hand:

1. **Cloudflare Access policy** — dashboard only, *not* managed by cf-reconcile,
   so it can silently go missing.
2. **HTTP Basic Auth** in app.py, from the sops secret above.
3. **app.py refuses to bind a non-loopback address with no password**, so a
   credential failure is a restart loop and a 502 rather than an open service.

The `tailscale0`-scoped firewall rule stays as it is; cloudflared dials
127.0.0.1:8778 from inside the host and needs no rule of its own, so the LAN
still cannot reach the port.

**Set the Access policy.** This hostname deserves it more than
`eldenring.azuresalt.app` does: a wiped playthrough is re-seedable from
`seed.json`, whereas `POST /api/delete` drops a series and its chapter history
with no undo. The Basic Auth password is also only eight characters, which is
fine behind Access and thin without it.
