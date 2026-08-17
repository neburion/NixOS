# Reading tracker

A web UI over the **Reading-Ob** Obsidian vault. Stdlib Python only — no Flask,
no pip, and no database.

Deployed by `service.nix` on `pod042`: **http://pod042:8778**, tailnet only.
See the module tree entry in `ARCHITECTURE.md`.

## The one decision everything else follows from

**The vault is the database.** There is no SQLite mirror. `vault.py` reads and
writes the YAML frontmatter of the notes under `Series/` in place, so this app
and Obsidian are looking at the same bytes. A second store would need syncing,
and two sources of truth for a reading list means one of them is wrong.

That is what makes this different from `elden-ring-tracker`, which owns its
data and seeds it from `seed.json`. Here the data is somebody else's — 300
notes written by hand over years — and the app is a guest in it.

Three consequences:

- **It runs on `pod042`,** because that is where the vault is and where Obsidian
  edits it. Putting it on a server would mean a copy.
- **It runs as `neburion`,** because the notes are that user's files.
  `ProtectHome` is therefore off, and the vault is the only writable path the
  unit is granted.
- **Writes are surgical.** Setting a field splices the lines for that one
  frontmatter key. Every other byte survives: unknown keys, key order, comments,
  blank lines, the note body, and whether the file ends with a newline.

## Files

| file | what it is |
|---|---|
| `service.nix` | systemd unit, cover-warming timer, tailnet firewall rule |
| `vault.py` | the storage layer — frontmatter parser, surgical writer |
| `app.py` | HTTP server, JSON API, cover cache |
| `ui.html` | the UI |

## Not clobbering Obsidian

Two editors on one file needs an answer, and "last write wins" is not it.

Every write **re-reads the note immediately beforehand** and applies only the
fields that request changed. An edit made in Obsidian between the page loading
and the Save landing is merged rather than overwritten. The page also re-reads
the whole vault whenever the tab regains focus.

A field whose value did not actually change is **never written**. `Rating: 3.0`
and `Rating: 3` are the same rating, and normalising one into the other would
have put a diff into 90 notes the first time anything saved. This also leaves
mtimes alone, which keeps syncthing and the index cache quiet.

The parser understands a deliberately small subset of YAML — `Key: scalar`, and
`Key:` followed by `  - item` lines — which is all 300 notes use. It is not a
general YAML implementation and does not need to be, because it never
re-serialises a document: it only ever replaces the lines belonging to one key.
Anything it does not recognise is passed through untouched and surfaced in the
UI read-only under **Other frontmatter**.

Both spellings of the tag key are handled. Forty-three notes use `tags:` and the
rest use `Tags:`; a note keeps whichever it already has.

## Deleting

`POST /api/delete` moves the note to the vault's `.trash/`, which is Obsidian's
own convention, so it is recoverable from inside Obsidian. Nothing here unlinks
a file.

## Tag spellings

The vault has the same tag in more than one form — `HunterFantasy` and
`Hunter Fantasy`, `SchoolLife` and `School Life`, `Video Game` and `VideoGame`.
They mean one thing and filter as two.

Merging them automatically would edit notes nobody asked to edit, so the
**Tags** view surfaces them as a suggestion and the merge is a button press.
It rewrites only the notes carrying the losing spelling — verified: merging
`Hunter Fantasy` touched 11 notes, one line each, and left the other 289 byte
for byte identical.

`tag_key()` decides what counts as the same tag: case-folded, with everything
non-alphanumeric removed.

## Cover artwork

The `Cover` values are DuckDuckGo image-proxy URLs pointing at a dozen
different hosts. Hotlinking 300 of them on every page load is slow, leaks the
shelf to whoever is on the other end, and breaks the day a host disappears.

So the server caches each one under `/var/lib/reading-tracker/covers/`, keyed by
a hash of the URL — which means changing a note's `Cover` changes the key, and
the new image is fetched with no cache to bust. Unlike `elden-ring-tracker`'s
`icons/`, this is **not** committed: the covers are a property of the vault,
not of this repo, and the vault is not in git.

**180 of the 213 notes that have a `Cover` resolve. 33 do not**, and are not
worth engineering around — the hosts are gone or have started refusing
hotlinks. Those cards draw a tinted plate with the title set on it, the tint
derived from the title itself so a book still looks like itself. The other 87
notes have no `Cover` at all and get the same treatment.

Two cheap recoveries are attempted before giving up. A `Referer` of
`duckduckgo.com` satisfies their proxy in some cases; and when the proxy returns
400 because its `ipt` signature has expired, the real image URL is sitting in
the `u=` query parameter, so `unproxy()` pulls it out and fetches that instead.
Expect the second path to matter more over time as more signatures age out.

Failures are remembered for six hours so a dead host is not retried on every
page load. `reading-tracker-covers.timer` warms the cache three minutes after
boot and weekly after that, purely so the first page load is not the slow one.

## Running it from a checkout

Paths fall back to sensible defaults, so a plain checkout works with no
arguments:

```bash
cd modules/system/reading-tracker
python3 app.py --open          # 127.0.0.1:8778, vault at ~/Media/Books/Reading-Ob
python3 app.py --stats         # print the shelf and exit
python3 app.py --warm-covers   # fetch every cover, then exit
python3 app.py --vault /path/to/a/copy
```

Overrides: `RT_VAULT`, `RT_UI`, `RT_FONTS`, `RT_CACHE`, `RT_HOST`, `RT_PORT`,
`RT_USERNAME`, `RT_PASSWORD`.

`reading-tracker` is also on `PATH` system-wide, so `reading-tracker --stats`
works from any terminal on `pod042`.

**Point it at a copy before testing anything that writes.** `--vault` exists for
exactly that.

## API

| method | path | body / query |
|---|---|---|
| GET | `/api/library` | every series, plus stats, meta and the tag report |
| GET | `/api/export` | the series list alone |
| GET | `/api/note?name=…` | the raw markdown of one note |
| POST | `/api/update` | `{name, fields}` — partial; returns which fields changed |
| POST | `/api/bump` | `{name, by, resume}` — chapter +1, optionally un-shelving it |
| POST | `/api/create` | `{name, fields}` — writes a new note |
| POST | `/api/rename` | `{name, to}` — renames the file |
| POST | `/api/delete` | `{name}` — moves it to `.trash/` |
| POST | `/api/tags/merge` | `{from:[…], to}` |

`name` is the note's filename without `.md`. It is resolved against `Series/`
and anything that escapes that directory is refused, so `../../etc/passwd` is a
400 rather than a write.

## What the UI shows that Obsidian's card view cannot

`Reading.base` already gives cards per status. The two things worth opening this
for instead:

- **A `+` on every cover.** One click is a chapter read and a note written. If
  the series was on Hold or Later it moves to Reading in the same click, with an
  Undo in the toast.
- **Two lists derived from the pair of status fields.** *Shelved, and now
  complete* — 42 series you put down while they were still running that have
  since finished, so there is an ending waiting. And *on hold, still publishing*
  — 77 where the author never stopped and chapters have piled up.

## Security

HTTP Basic Auth, on whenever a password is present — the systemd credential
`password` (the `reading-tracker-password` sops secret, in `secrets/pod042.yaml`)
or `$RT_PASSWORD`. Without one the app refuses to bind anything but loopback, so
a misconfigured deploy fails to start rather than putting a vault-editing API on
the network.

The username is `reader` and lives in `service.nix`, since it is not a secret.

That is a second gate, not the only one: the `tailscale0`-scoped firewall rule
in `service.nix` limits who can reach :8778. That matters more here than on a
server — `pod042` is a laptop and joins whatever wifi it is pointed at, so the
port is deliberately not opened on the LAN.

This is the first thing in `secrets/pod042.yaml`; before it, `pod042` had no
host secrets file at all.
