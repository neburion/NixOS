{ ... }:

# Portable bash entry points for the fleet rebuild workflow. One script per
# file; each file is a self-contained home-manager module adding its own
# package. Shared shell fragments live in ./lib.nix.
#
# ┌─────────────┬──────────────────────────────────────┬───────────────────────────┐
# │ Command     │ Flake source                         │ Semantics                 │
# ├─────────────┼──────────────────────────────────────┼───────────────────────────┤
# │ rebuild     │ github:neburion/NixOS (cloud, always │ "make this host match     │
# │             │ latest master, --refresh forces      │  master right now"        │
# │             │ re-fetch)                            │                           │
# │ rebuild-all │ github:neburion/NixOS                │ "make EVERY host match    │
# │             │                                      │  master. Remotes first,   │
# │             │                                      │  self last; skips hosts   │
# │             │                                      │  that are powered off;    │
# │             │                                      │  one failure doesn't      │
# │             │                                      │  abort the rest."         │
# │ trebuild    │ path:$HOME/NixOS (local checkout)    │ "try my uncommitted       │
# │             │                                      │  changes with `test`      │
# │             │                                      │  activation — no reboot   │
# │             │                                      │  persistence"             │
# │ update      │ path:$HOME/NixOS                     │ "bump flake.lock inputs,  │
# │             │                                      │  rebuild locally to       │
# │             │                                      │  validate. Commit + push  │
# │             │                                      │  the new lock afterward." │
# │ nixflash    │ github:neburion/NixOS#installer      │ "build the live-USB ISO   │
# │             │                                      │  and dd it to a stick"    │
# └─────────────┴──────────────────────────────────────┴───────────────────────────┘
#
# WHY the rebuild/trebuild split: `rebuild` always deploying from the cloud
# means no host is "the source of truth" for what's deployed — pod042 can die
# and any other fleet member with the flake URL + sops key + SSH access can
# rebuild anything from master. Editing happens on whatever host has a local
# checkout; deploying happens against the pushed cloud state.
#
# Discipline this enforces: `rebuild` after edits requires you to `git push`
# first. If local has commits not pushed to origin/master, `rebuild` warns
# but proceeds — the deploy will use whatever's on origin/master (i.e. NOT
# your uncommitted work).
#
# Pre-rebuild hooks (config.rebuild.preHooks — cf-reconcile, future r2
# reconcilers, etc.) run before every rebuild/trebuild. Non-zero exit
# aborts before any host is touched. See modules/system/rebuild-hooks/
# registry.nix.

{
  imports = [
    ./nixflash.nix
    ./rebuild-all.nix
    ./rebuild.nix
    ./trebuild.nix
    ./update.nix
  ];
}
