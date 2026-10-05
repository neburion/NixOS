{ ... }:

# What this host has that is worth keeping. Behavior module:
# modules/system/backup/restic.nix.
#
# `/var/lib` is the whole answer, because everything durable on this box is a
# StateDirectory underneath it: media.db and its cover cache, and whatever the
# next app in policy/apps.nix asks for — a new app
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
  # Deactivated 2026-10-05, with R2 dropped as a destination. The bucket was
  # emptied the same day: this host's `/var/lib` repository (38 objects,
  # 115 MB) and pod042's `neburion` repository (4761 objects, 84.7 GB) are
  # both gone, as is the B2 copy downstream of the mirror.
  #
  # `backup.paths` is the only thing that writes to R2, so leaving root
  # undeclared removes this host's job without editing the module. Nothing
  # else here uploads: the mirror server below serves clients, and no client
  # declares paths any more.
  #
  # That means /var/lib is currently unbacked — media.db, the dashboard's
  # state and whatever policy/apps.nix deploys next. Deliberate, pending a
  # replacement backup system.
  #
  #   backup.paths.root = [ "/var/lib" ];

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
  # Deactivated 2026-10-05 alongside the R2 job above, and not by choice: the
  # fan-out unit takes its passphrase from `sops.secrets.restic-passphrase`,
  # which restic.nix only declares when some host declares `backup.paths`. With
  # the last path gone that secret is gone, and the unit stops evaluating —
  # `while evaluating the option systemd.services.restic-fanout-b2`.
  #
  # Nothing is lost by it: fan-out copies from the mirror, the mirror is empty,
  # and the B2 bucket was emptied the same day (17 objects plus 21 hidden
  # versions, purged rather than left to the lifecycle rule below).
  #
  #   backup.fanout.b2 = {
  #     repository  = "s3:s3.us-east-005.backblazeb2.com/neburion-fleet-backup";
  #     credentials = {
  #       AWS_ACCESS_KEY_ID     = "b2-key-id";
  #       AWS_SECRET_ACCESS_KEY = "b2-application-key";
  #     };
  #   };
}
