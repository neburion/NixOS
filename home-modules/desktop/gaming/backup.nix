{ pkgs, config, ... }:

let
  p7zip  = "${pkgs.p7zip}/bin/7z";
  rclone = "${pkgs.rclone}/bin/rclone";
  cp     = "${pkgs.coreutils}/bin/cp";
  rm     = "${pkgs.coreutils}/bin/rm";
  mkdir  = "${pkgs.coreutils}/bin/mkdir";
  date   = "${pkgs.coreutils}/bin/date";
  home   = config.home.homeDirectory;

  backupScript = pkgs.writeShellScript "backup-gaming" ''
    set -euo pipefail

    PASSWORD=$(cat ${home}/Docs/Passwords/backup-password)
    DATE=$(${date} +%Y-%m-%d)
    STAGING="${home}/backup-staging"
    ARCHIVE="${home}/backup_gaming_$DATE.7z"
    GDRIVE="gDrive:/Backups/Gaming"

    trap '${rm} -rf "$STAGING"; ${rm} -f "$ARCHIVE"' EXIT

    ${rm}    -rf "$STAGING"
    ${mkdir} -p  "$STAGING"/{Gaming,.config}

    ${cp} -rf \
      ${home}/Gaming/Gaming-Ob/              \
      ${home}/Gaming/Heroic/Wine\ Prefixes/  \
      "$STAGING"/Gaming/

    ${cp} -rf \
      ${home}/.config/vesktop/  \
      ${home}/.config/heroic/   \
      "$STAGING"/.config/

    ${p7zip} a -t7z "$ARCHIVE" "$STAGING/" -p"$PASSWORD" -mhe=on

    ${rclone} copy   "$ARCHIVE"    "$GDRIVE"
    ${rclone} delete --min-age 5d  "$GDRIVE"
  '';
in
{
  systemd.user.services.backup-gaming = {
    Unit = {
      Description = "Weekly gaming backup";
      After       = [ "network-online.target" ];
      Wants       = [ "network-online.target" ];
    };
    Service = {
      Type      = "oneshot";
      ExecStart = "${backupScript}";
    };
  };

  systemd.user.timers.backup-gaming = {
    Unit.Description = "Run gaming backup weekly";
    Timer = {
      OnCalendar = "weekly";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
