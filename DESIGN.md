# DESIGN

How this repo is put together. Two words, four rules, one tree.

`NOTES.md` is the other file — war stories, why a thing broke once, what to suspect when
something misbehaves. Nothing in it is binding. Nothing in here is a story.

---

## Two words

**module** — one capability. A `.nix` file, or a directory with a `default.nix` when it
needs more than one file. You import it whole; you cannot take half of it.

**preset** — a named file that calls a bunch of modules. Presets are not a home-only idea;
every tree has them.

A directory with neither is a folder you reach through, and most directories are folders.

**`default.nix` is the scarce thing.** Writing one says *this is indivisible*. If the parts
can be taken separately it stays a folder — and if they usually travel together anyway, it
gets a preset. `dev/` is the example: you might want only IntelliJ and Java, or only nvim
and C, so it is a folder, with `presets/dev.nix` beside it for when you want the lot.

---

## Four rules

**One Line.** Adding or removing a program or a feature from a host or a user is one import
line, and nothing else moves.

**Like With Like.** A directory's entries are the same order of magnitude. An app does not
sit next to a feature next to a sixty-file subsystem.

**One Job.** No file does two things. A file that has grown long splits; it does not scroll.

**The Orphan Rule.** If something would be meaningless once another thing is gone, it
belongs inside that thing. *Delete X — is this now junk? Then it was always X's.*

The Orphan Rule decides the hard cases:

| Thing | Lives with | Because without it, it is junk |
|---|---|---|
| `inter`, `geist`, `material-symbols` | `desktop/glass/fonts/` | Faces chosen to render *that* bar |
| `templates/c`, `/cpp`, `/python` | each language | Only `newc` / `newcpp` / `newpy` read them |
| `direnv` | `dev/tools/` | There is no `.envrc` outside a project |
| `nautilus`, `loupe`, `celluloid`, `zathura` | the preset's `components/` | Parts Hyprland does not ship; a full DE brings its own |
| `tailnet-hosts` | `network/tailscale/` | Meaningless without the tailnet |
| `cf-reconcile` | `services/cloudflare/` | It exists to converge those tunnels |
| the printer's tunnel | `services/printing/web-ui.nix` | The tunnel exists because the web UI does |
| the `wayvnc` firewall hole | `desktop/glass/components/wayvnc/` | Open only for the phone display |

It is also what makes swapping a desktop cheap. Everything that dies with a desktop lives
inside it, so deleting the directory takes the file manager, the clipboard, the fonts and
the theming with it.

---

## The tree

```
NixOS/
├── flake.nix
├── DESIGN.md   NOTES.md
├── secrets/            common.yaml  <host>.yaml  age-key.enc
│
├── hosts/
│   ├── pod042/         configuration.nix  hardware/ = module  generated/
│   ├── home-server/    configuration.nix  hardware/ = module  generated/
│   ├── personal-server/ configuration.nix hardware/ = module  generated/
│   │                    policy/ = module   apps  backup
│   └── installer/      configuration.nix
│
├── users/
│   ├── neburion/       default  account  home  dirs
│   └── server-admin/   default  account  home
│
└── modules/
    ├── system/                    ← modules with no home half
    │   ├── core/       nix  locale  console  sudo  sops
    │   ├── boot/       limine  systemd-boot  grub
    │   ├── hardware/   audio  bluetooth  power  always-on  touchpad
    │   │               brightness  lid  logitech  nvidia
    │   ├── network/
    │   │   ├── wifi/       bell096.nix        one file per known network
    │   │   ├── tailscale/  = module
    │   │   └── networkmanager  ssh  avahi  syncthing
    │   ├── session/    sddm  portals  wayland-env  dconf
    │   ├── services/
    │   │   ├── printing/   canon/ = module   web-ui.nix
    │   │   ├── cloudflare/ tunnel  email  r2  reconcile
    │   │   ├── backup/     restic
    │   │   ├── paisa/      = module
    │   │   └── app-platform/ = module
    │   └── presets/    base  laptop  headless  graphical
    │                   tailnet  cloudflare
    │
    ├── home/
    │   ├── cli/
    │   │   ├── shell/   fish/ = module   bash/ = module
    │   │   ├── flatpak/ = module
    │   │   └── btop  tree  xxd  compression  fastfetch  superfile
    │   ├── dev/
    │   │   ├── languages/  c-cpp/ = module  python/ = module  nix/ = module
    │   │   ├── editors/    neovim/ = module   intellij
    │   │   ├── engines/    godot
    │   │   └── tools/      git  direnv  tokei  claude-code
    │   ├── office/      libre-office  obsidian  thunderbird  aerc
    │   ├── comms/       signal  vesktop
    │   ├── art/         aseprite  blender
    │   ├── browser/     zen-browser
    │   ├── music/       spotify
    │   ├── security/    keepassxc
    │   ├── gaming/
    │   │   ├── launchers/  heroic  prism-launcher  sober
    │   │   │               bb-launcher/ = module   steam/ = module
    │   │   ├── emulators/  shadps4
    │   │   └── games/      osu
    │   ├── desktop/
    │   │   ├── glass/
    │   │   │   ├── components/  nautilus loupe celluloid zathura
    │   │   │   │                pavucontrol wl-clipboard libnotify
    │   │   │   │                screenshot   wayvnc/ = module
    │   │   │   ├── fonts/       inter  geist  material-symbols
    │   │   │   ├── theming/     gtk/ = module  spotify  vesktop  zathura
    │   │   │   ├── wm/ = module     bar/ = module     launcher/ = module
    │   │   │   ├── osd/ = module    notifications/ = module
    │   │   │   ├── wallpaper/ = module    quickshell/ = module
    │   │   │   └── palette.nix  terminal.nix  cursor.nix
    │   │   └── clean/           same, plus themes/ = module
    │   └── presets/
    │       ├── glass.nix    clean.nix
    │       ├── dev.nix      cli.nix
    │       ├── art.nix      office.nix
    │       ├── comms.nix    gaming.nix
    │
    └── tools/
        ├── fleet/      rebuild  rebuild-all  trebuild  update
        │               nixflash  hooks  lib
        ├── installer/  = module
        └── presets/    fleet.nix
```

`= module` marks the directories that carry a `default.nix`. Everything else is a folder.

---

## Modules with both halves

A few capabilities need a NixOS module *and* a home-manager one. They are not split across
the two trees — they live where their owner lives, and the NixOS half is a file named
`system.nix` inside the module's own directory.

```
home/cli/shell/fish/                      system.nix    programs.fish.enable
home/cli/flatpak/                         system.nix    services.flatpak.enable
home/gaming/launchers/steam/              system.nix    programs.steam.enable
home/desktop/glass/wm/                    system.nix    programs.hyprland.enable
home/desktop/glass/components/wayvnc/     system.nix    the firewall hole
```

The host imports the `system.nix`; the user imports the rest.

**Under `modules/home/`, a file named `system.nix` is a NixOS module and everything else is
home-manager.** That is the only place the two kinds coexist, and the filename says which is
which — so a misfiling is visible, instead of turning up as a module-system error that names
neither file.

`programs.hyprland.enable` living in each preset's `wm/` also means the two desktops can run
different Hyprland versions without touching each other.

---

## Where does it go

| The thing | Goes to |
|---|---|
| A program you chose | `home/<what it is>/` — `office/`, `art/`, `gaming/launchers/`, … |
| A program the desktop provides | `home/desktop/<preset>/components/` |
| A font | `home/desktop/<preset>/fonts/` — one file per family |
| A language's compiler, LSP, debugger, scaffolder | `home/dev/languages/<lang>/` |
| Colours for a program | `home/desktop/<preset>/theming/` |
| A wifi network | `system/network/wifi/` — one file per network |
| Something the machine serves to others | `system/services/<name>/` |
| A physical fact of one machine | `hosts/<host>/hardware/` |
| A choice made for one machine | `hosts/<host>/policy/` |
| Something a tool wrote | `hosts/<host>/generated/` — never hand-edited |
| A script that operates the repo | `tools/fleet/` |
| A set that always travels together | a preset, in the nearest `presets/` |

A tunnel is not on that list on purpose: `cloudflare.declaredTunnels` is only ever set by
the service that needs the tunnel. No host declares one by hand.

---

## Recipes

**Add a program** — one file where it belongs, one import line in `users/<user>/home.nix`.
If it needs colours, a second file in the preset's `theming/`.

**Add a font** — one file in the preset's `fonts/`, one line in that preset.

**Add a wifi network** — one file in `system/network/wifi/`, imported by the hosts that
should know it. The installer imports them too, so a fresh boot is already online.

**Add a language** — a directory under `dev/languages/` with a `default.nix`, carrying its
own `templates/`.

**Add a desktop** — a directory under `home/desktop/` with the same slots, and a preset
beside `glass.nix`. Copy from an existing one; never import from it.

**Add a host** — copy the nearest `hosts/<host>/`, replace `hardware/`, add one line to
`flake.nix`. After first boot, commit the generated `hardware.nix` and add the tailnet
address. Do not set `networking.hostName`; the flake injects it.

**Retire a desktop** — delete its directory. Its file manager, clipboard, fonts and theming
go with it, because they were never anywhere else.

---

## Deliberate duplication

Two desktops carry two copies of the quickshell machinery and two complete Hyprland
configs. That is the design. Presets diverge on purpose, and a shared parent is exactly the
arrangement that lets editing one break the other — every shared layer this repo has had
grew back into that. A fix in one is not a fix in the other, and that is accepted.

It licenses nothing else. Two hosts needing the same service share the module.
