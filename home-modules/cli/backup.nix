{ pkgs, config, ... }:

let
  p7zip  = "${pkgs.p7zip}/bin/7z";
  rclone = "${pkgs.rclone}/bin/rclone";
  cp     = "${pkgs.coreutils}/bin/cp";
  rm     = "${pkgs.coreutils}/bin/rm";
  mkdir  = "${pkgs.coreutils}/bin/mkdir";
  date   = "${pkgs.coreutils}/bin/date";
  home   = config.home.homeDirectory;
  nixos  = "${home}/NixOS";

  backupScript = pkgs.writeShellScript "backup" ''
    set -euo pipefail

    # --- Config ---
    PASSWORD=$(cat ${home}/Docs/Passwords/backup-password)
    DATE=$(${date} +%Y-%m-%d)
    STAGING="${home}/backup-staging"
    ARCHIVE="${home}/backup_$DATE.7z"
    GDRIVE="gDrive:/Backups"
    HOMESERVER="pod153:/home/9s/Backups"

    trap '${rm} -rf "$STAGING"; ${rm} -f "$ARCHIVE"' EXIT

    # --- Stage files ---
    ${rm}    -rf "$STAGING"
    ${mkdir} -p  "$STAGING"/{nixos,.config}

    # --- Copy Home Files ---
    ${cp} -rf \
      ${home}/Docs/     \
      ${home}/Media/    \
      ${home}/Projects/ \
      ${home}/School/   \
      "$STAGING"/

    # --- Copy Config Files ---
    ${cp} -rf \
      ${nixos}/                  \
      ${home}/.config/zen/       \
      ${home}/.config/rclone/    \
      ${home}/.config/keepassxc/ \
      "$STAGING"/.config/

    # --- Compress & encrypt ---
    ${p7zip} a -t7z "$ARCHIVE" "$STAGING/" -p"$PASSWORD" -mhe=on

    # --- Upload & Delete Old Backups ---
    ${rclone} copy   "$ARCHIVE"    "$GDRIVE"
    ${rclone} delete --min-age 5d  "$GDRIVE"
    ${rclone} copy   "$ARCHIVE"    "$HOMESERVER"
    ${rclone} delete --min-age 20d "$HOMESERVER"
  '';
in
{
  systemd.user.services.backup = {
    Unit = {
      Description = "Daily backup";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${backupScript}";
    };
  };

  systemd.user.timers.backup = {
    Unit.Description = "Run backup daily";
    Timer = {
      OnCalendar = "daily";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
