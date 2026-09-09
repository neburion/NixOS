{ ... }:

# The NixOS half of the git tooling. `sops.secrets` is a system-level option,
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

{
  sops.secrets.codeberg-token = {
    sopsFile = ../../../../secrets/common.yaml;
    owner    = "neburion";
    mode     = "0400";
  };
}
