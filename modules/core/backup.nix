{ pkgs, ... }:

let
  p7zip   = "${pkgs.p7zip}/bin/7z";
  rclone  = "${pkgs.rclone}/bin/rclone";
  cp      = "${pkgs.coreutils}/bin/cp";
  rm      = "${pkgs.coreutils}/bin/rm";
  mkdir   = "${pkgs.coreutils}/bin/mkdir";
  date    = "${pkgs.coreutils}/bin/date";

  backupScript = pkgs.writeShellScript "backup-system" ''
    set -euo pipefail

    PASSWORD=$(cat /home/neburion/Docs/Passwords/backup-password)
    DATE=$(${date} +%Y-%m-%d)
    STAGING="/tmp/backup-staging"
    ARCHIVE="/tmp/backup_$DATE.7z"
    GDRIVE="gDrive:/Backups"
    HOMESERVER="pod153:/home/9s/Backups"

    trap '${rm} -rf "$STAGING"; ${rm} -f "$ARCHIVE"' EXIT

    ${rm}    -rf "$STAGING"
    ${mkdir} -p  "$STAGING"/{neburion/{docs,projects,media,school,nixos,config},qellyree/{gaming,config}}

    # --- neburion: work & dev ---
    ${cp} -rf /home/neburion/Docs/     "$STAGING"/neburion/docs/
    ${cp} -rf /home/neburion/Media/    "$STAGING"/neburion/media/
    ${cp} -rf /home/neburion/Projects/ "$STAGING"/neburion/projects/
    ${cp} -rf /home/neburion/School/   "$STAGING"/neburion/school/
    ${cp} -rf /home/neburion/NixOS/    "$STAGING"/neburion/nixos/
    ${cp} -rf /home/neburion/.config/zen/        "$STAGING"/neburion/config/ || true
    ${cp} -rf /home/neburion/.config/rclone/     "$STAGING"/neburion/config/ || true
    ${cp} -rf /home/neburion/.config/keepassxc/  "$STAGING"/neburion/config/ || true

    # --- qellyree: gaming ---
    ${cp} -rf /home/qellyree/Gaming/             "$STAGING"/qellyree/gaming/ || true
    ${cp} -rf /home/qellyree/.config/vesktop/    "$STAGING"/qellyree/config/ || true
    ${cp} -rf /home/qellyree/.config/heroic/     "$STAGING"/qellyree/config/ || true

    # --- Compress & encrypt ---
    ${p7zip} a -t7z "$ARCHIVE" "$STAGING/" -p"$PASSWORD" -mhe=on

    # --- Upload ---
    RCLONE="${rclone} --config /home/neburion/.config/rclone/rclone.conf"
    $RCLONE copy   "$ARCHIVE"    "$GDRIVE"
    $RCLONE delete --min-age 5d  "$GDRIVE"
    $RCLONE copy   "$ARCHIVE"    "$HOMESERVER"
    $RCLONE delete --min-age 20d "$HOMESERVER"
  '';
in
{
  environment.systemPackages = with pkgs; [ rclone p7zip ];

  systemd.services.backup-system = {
    description = "Daily system backup";
    after       = [ "network-online.target" ];
    wants       = [ "network-online.target" ];
    serviceConfig = {
      Type      = "oneshot";
      ExecStart = "${backupScript}";
    };
  };

  systemd.timers.backup-system = {
    description     = "Run system backup daily";
    wantedBy        = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };
  };
}
