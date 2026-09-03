# DESIGN

The law for this repo. Structure only.

- **This file is law.** If the tree disagrees with it, the tree is wrong.
- **`NOTES.md` is lore.** Why a thing broke once, how a subsystem works, what to suspect
  when it misbehaves. Nothing in `NOTES.md` is binding.
- Mixing the two is why `ARCHITECTURE.md` stopped being obeyed. Don't put a rule here
  you cannot check, and don't put a story here at all.

`modules/tools/check-structure` enforces every law below. It runs as a pre-rebuild hook.

---

## 1. The model

Three layers. Importing is enabling. No layer reaches sideways.

| Layer | Where | Holds |
|---|---|---|
| **Manifest** | `hosts/*/configuration.nix`, `users/*/home.nix`, every `default.nix` | Import lists. Nothing else. |
| **Behavior** | `modules/` | What the imports do. |
| **Environment** | `hosts/*/hardware/`, `hosts/*/policy/` | Facts about, and choices for, one machine. |

---

## 2. The tree

Every directory below carries an **admission test**: one question with a yes/no answer.
A file that answers no to every test at a level does not belong at that level — you have
misunderstood the file, not found a gap in the list. **The lists are closed.** They grow
only by an edit to this file.

```
NixOS/
├── flake.nix              nixosConfigurations + mkSystem. No module bodies.
├── DESIGN.md  NOTES.md
├── secrets/               sops yaml — one per host, plus common.yaml
├── hosts/<host>/
│   ├── configuration.nix  manifest — imports only
│   ├── hardware/          physical facts — what the machine is
│   ├── policy/            choices — what you decided it does
│   └── generated/         written by tools, never by hand:
│                          hardware.nix, cf-tunnels.lock.json
├── users/<user>/
│   ├── default.nix        manifest — imports only
│   ├── account.nix        users.users.<user>
│   ├── home.nix           home-manager imports
│   └── dirs.nix           this user's directory layout
└── modules/
    ├── system/            NixOS modules. Nothing here is a home-manager module.
    │   ├── core/
    │   ├── boot/
    │   ├── hardware/
    │   ├── network/
    │   ├── session/
    │   └── services/
    ├── home/              home-manager modules. Nothing here is a NixOS module.
    │   ├── cli/
    │   ├── apps/
    │   ├── toolchains/
    │   └── desktop/<preset>/
    └── tools/             programs that operate this repo
```

### Admission tests

| Directory | Admission test |
|---|---|
| `hosts/<h>/hardware/` | Would this change if you swapped the machine but kept its job? |
| `hosts/<h>/policy/` | Would this change if you kept the machine but changed its job? |
| `hosts/<h>/generated/` | Did a tool write it? Then nothing here is ever hand-edited. |
| `modules/system/core/` | Would a box with no disk, no network and no display still want it? |
| `modules/system/boot/` | Does it decide what happens before the kernel? *(exactly one per host)* |
| `modules/system/hardware/` | Does this file exist because of a physical device? |
| `modules/system/network/` | Does it move bytes off this machine? |
| `modules/system/session/` | Is it a prerequisite for a graphical login, without being part of the look? |
| `modules/system/services/` | Does something other than this machine consume it? |
| `modules/home/cli/` | Does it work over ssh with no display? |
| `modules/home/apps/` | Does it need a Wayland session? |
| `modules/home/toolchains/` | Is it the compiler / LSP / debugger / scaffold set for one language? |
| `modules/home/desktop/<p>/` | Is it part of how *this one* desktop looks or behaves? |
| `modules/tools/` | Does it operate this repo, rather than the machine? |

`hardware/` vs `policy/` is the same question asked from both ends, and exactly one of the
two answers yes. If both do, the file is two files.

### Preset slots — closed

A preset directory holds only these names:

```
default.nix   palette.nix   terminal.nix   cursor.nix   lock.nix
shell/        wm/           bar/           launcher/
notifications/ osd/         wallpaper/     theming/
```

- **Omitting a slot is how a preset opts out.** Glass has no theme switcher because it has
  no `themes/`; that is the whole mechanism.
- **A preset may not add a slot.** If it needs one, it goes in this file first.
- A preset is home-manager only. It never contains a NixOS module.

---

## 3. The eight laws

Each is stated so `check-structure` can fail on it.

**L1 — Every directory level is a closed set.**
The lists in §2 are exhaustive. A file that fits none is a misunderstood file.

**L2 — A manifest is imports and nothing else.**
`hosts/*/configuration.nix`, `users/*/home.nix`, every `default.nix`: an `imports` list and
comments. Any other attribute is a bug.

**L3 — Options carry host facts, never module opinions.**
A module declares an option; `hosts/` sets it. That is the whole pattern.

*One bounded exception — a **resource claim**.* A module may set another module's option
when it is claiming a resource that module owns (a tunnel, a pre-rebuild hook, a firewall
port). All four conditions are required:

1. the option is `attrsOf`, keyed by the claimant's own name;
2. two claimants can never collide on a key;
3. claimant and owner live in **different** top-level directories of `modules/`;
4. nothing under `modules/home/desktop/` is involved, in either role.

Anything else is a shared layer written as an option. `cloudflare.declaredTunnels` passes.
`quickshell.*` and `themeHooks` fail on 1, 3 and 4 — they are the disease this law names.

**L4 — No registry is `lines`-typed.**
`lines` merges by concatenation, so a duplicate key produces a corrupt file instead of an
error. Extension points are attrsets of independent items.

**L5 — Imports go downward only.**
Hosts import system modules. Users import home modules. No user directory reaches into
`modules/system/`. No module reaches into `hosts/`.

**L6 — A name is a file or a directory, never both.**
No `foo.nix` beside `foo/`. And no directory holds a single file — that is a label
pretending to be structure. Promote it or collapse it.

**L7 — Fact, choice and generated state are three things.**
What the machine *is*, what you decided it *does*, what a tool wrote. Never one directory.
Generated files are never hand-edited.

**L8 — Install and look are different files.**
A program in `apps/` or `cli/` is preset-agnostic. Every palette in the repo lives inside
a desktop. There is no repo-wide theme.

---

## 4. Where does this file go?

| The file… | Goes to |
|---|---|
| installs a program needing a display | `modules/home/apps/<name>.nix` |
| installs a terminal program | `modules/home/cli/<name>.nix` |
| colours a program to match a desktop | `modules/home/desktop/<preset>/theming/<name>.nix` |
| is a palette | `modules/home/desktop/<preset>/palette.nix` or `…/themes/` |
| configures a bar, launcher, OSD, wallpaper | `modules/home/desktop/<preset>/<slot>/` |
| sets up a language's compiler and LSP | `modules/home/toolchains/<lang>/` |
| enables a daemon others connect to | `modules/system/services/<name>.nix` |
| exists because of a physical device | `modules/system/hardware/<name>.nix` |
| opens a port or dials out | `modules/system/network/<name>.nix` |
| is needed before a graphical login | `modules/system/session/<name>.nix` |
| every host wants, unconditionally | `modules/system/core/<name>.nix` |
| is a PCI id, a display mode, a disk | `hosts/<host>/hardware/` |
| is which services / hostnames / backups this box has | `hosts/<host>/policy/` |
| is a script you run *on* the repo | `modules/tools/<name>.nix` |
| is a package definition with no config | next to its only consumer, as `package.nix` |

---

## 5. Recipes

**Add a GUI program** — one file in `modules/home/apps/`, one import line in
`users/<user>/home.nix`. If it needs colours, a second file in the preset's `theming/`.

**Add a terminal program** — one file in `modules/home/cli/`, one import line. It carries
its own colours; it must work on a headless server.

**Add a host** — `cp -r hosts/<nearest>/ hosts/<new>/`, strip imports, replace
`hardware/`, add one line to `flake.nix`. After first boot: commit the generated
`hardware.nix` and add the tailnet address to `modules/system/network/tailnet-hosts.nix`.
Do **not** set `networking.hostName`; the flake injects it.

**Add a user** — `cp -r users/<nearest>/`, edit `account.nix` and `home.nix`, reference it
from a host manifest.

**Add a preset** — a new directory under `modules/home/desktop/`, using the slot names in
§2. Copy from an existing preset; do not import from one.

**Swap a component** — change one import line inside the preset. The provider publishes its
own `$statusBar` / `$appLauncher` / `$wallpaperManager`; `wm/keybinds.nix` and
`wm/auto-exec.nix` never name a provider.

**Add a secret** — `secrets/<host>.yaml`, referenced by the module that reads it. Every
secret is encrypted to the one fleet age recipient; see `NOTES.md`.

---

## 6. Deliberate duplication

Two presets carry two copies of the quickshell registry and two complete Hyprland
configurations. This is the design, not debt.

- Presets diverge **on purpose**. A shared parent means editing one risks the other, and
  every shared layer in this repo's history grew back into exactly that.
- A fix in one preset is not a fix in the other. Accepted.
- The rule that makes it hold: **nothing crosses out of `modules/home/desktop/<preset>/`,
  in either direction.** One grep.

This does **not** license duplication anywhere else. Two hosts needing the same service
share the module in `modules/system/services/`; they are not presets.

---

## 7. Changes from ARCHITECTURE.md

| Was | Now |
|---|---|
| "Behavior modules never expose options" + 2 exceptions | **L3.** Options carry host facts. The 2 blessed exceptions were the actual violation. |
| "Cross-cutting data flows as module arguments" | Deleted. Its only user was `themes`, now dissolved into the presets. |
| "System vs home split is mirrored" | Deleted. They were never mirrorable. |
| `hardware-layout/` | Split into `hardware/` (facts) and `policy/` (choices). Lock files leave both. |
| `iso/` at the repo root | `hosts/installer/`. It is a host. |
| `themes/` as a top-level tree | Each desktop owns its palettes. CLI tools carry their own. |
| Everything else | Stands. Manifest + Additive, the three layers, one concern per file, no host is special, shell auto-wiring, the single fleet age key. |
