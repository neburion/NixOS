{ ... }:

# What this host has that is worth keeping. Behavior module:
# modules/system/backup/restic.nix.
#
# `/var/lib` is the whole answer, because everything durable on this box is a
# StateDirectory underneath it: media.db and its cover cache, the Elden Ring
# ledger, and whatever the next app in apps-layout.nix asks for — a new app
# gets backed up the day it is deployed, without anyone remembering to add it
# here. Nothing else on the machine is worth a snapshot; the system itself is
# rebuilt from the flake, and the apps from their own repos.
#
# Declared as `root` rather than a service user on purpose. The state
# directories are 0750 and each is owned by its own app, so no single service
# user can read past its own — and a job per app would mean one repository per
# app, which is bookkeeping for nothing. A root job is filed under the hostname
# instead of under `root`; see the module header.
#
# This continues the repository the manual snapshot on 2026-08-25 created, so
# the first nightly run deduplicates against it rather than re-uploading 52 MB
# of cover art. Restore is `restic restore latest --target …` or `restic mount`
# for browsing; the passphrase and R2 credentials are in secrets/common.yaml.

{
  backup.paths.root = [ "/var/lib" ];
}
