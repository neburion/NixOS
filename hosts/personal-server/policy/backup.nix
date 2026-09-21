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
# `/var/lib` stays the whole answer because the other machines' backups do not
# land there. This host is also the fleet's second backup destination, and the
# restic REST server keeps its repositories at /var/backup/restic — outside
# this path on purpose. Inside it, tonight's R2 upload would carry every other
# machine's backup history, and would carry more of it every night.
#
# This continues the repository the manual snapshot on 2026-08-25 created, so
# the first nightly run deduplicates against it rather than re-uploading 52 MB
# of cover art. Restore is `restic restore latest --target …` or `restic mount`
# for browsing; the passphrase and R2 credentials are in secrets/common.yaml.

{
  backup.paths.root = [ "/var/lib" ];

  # Backblaze, fed by copying from the mirrored repositories this host already
  # holds — see services/backup/fanout.nix. It exists because everything else
  # off-site is Cloudflare: R2, the tunnels, the DNS and the mail are one
  # account, and losing it would take the only off-site backup at the same
  # moment it took the domain.
  #
  # The key behind these two secrets is restricted to this one bucket and holds
  # six capabilities — list, read, write and delete files, and the two list-
  # buckets rights an S3 client needs to find it. It cannot create a bucket,
  # delete the bucket, or mint another key; that was checked by asking it to,
  # and being refused.
  #
  # The bucket carries a lifecycle rule deleting hidden versions after a day.
  # B2 keeps every version of a file forever by default, so without it restic's
  # prune would hide objects that go on being billed — a repository that
  # shrinks on paper and never on the invoice.
  backup.fanout.b2 = {
    repository  = "s3:s3.us-east-005.backblazeb2.com/neburion-fleet-backup";
    credentials = {
      AWS_ACCESS_KEY_ID     = "b2-key-id";
      AWS_SECRET_ACCESS_KEY = "b2-application-key";
    };
  };
}
