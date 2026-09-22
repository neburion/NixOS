{ ... }:

# The NixOS half of the tooling under modules/home/dev/tools. Two things live
# here because both are system-level options that the home modules beside them
# cannot set.
#
# ── git ─────────────────────────────────────────────────────────────────────
#
# `sops.secrets` is a system-level option,
# and it has to stay one: the fleet age key is /var/lib/sops-nix/key.txt at
# 0400 root:root, so a user-level sops-nix service running as neburion could
# not read it. Declaring this in git.nix (a home module) is therefore not an
# option, however much the Orphan Rule would prefer it.
#
# It lives here, beside the git config it exists for, rather than in
# modules/system/: delete git.nix and `mkrepo cb`, and this secret is junk.
#
# `owner` matters. /run/secrets/* defaults to root:root 0400, and mkrepo runs
# as the user — without this, the curl in it reads nothing and Codeberg
# answers 401.

#
# ── claude-code ─────────────────────────────────────────────────────────────
#
# Claude Code keeps a JSONL transcript of every session under ~/.claude, and
# those transcripts are the only record of what a subscription spent — there is
# no usage endpoint for a plan, only for an organisation billed per token. This
# points the fleet-status collector at them so the dashboard can total them up.
#
# It lives beside claude-code.nix rather than in modules/system/: remove the
# package and this line is pointing at a directory nothing writes to.

{
  sops.secrets.codeberg-token = {
    sopsFile = ../../../../secrets/common.yaml;
    owner    = "neburion";
    mode     = "0400";
  };

  fleetStatus.claudeUser = "neburion";
}
