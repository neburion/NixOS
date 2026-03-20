{ pkgs, ... }:

let
  p7zip  = "${pkgs.p7zip}/bin/7z";
  rclone = "${pkgs.rclone}/bin/rclone";
  cp     = "${pkgs.coreutils}/bin/cp";
  rm     = "${pkgs.coreutils}/bin/rm";
  mkdir  = "${pkgs.coreutils}/bin/mkdir";
  date   = "${pkgs.coreutils}/bin/date";
  home   = "/home/neburion";
  nixos  = "/etc/nixos";
in
{
  systemd.services.backup = {
    description = "Daily backup";
    script = ''
      set -euo pipefail
      STAGING="${home}/backup-staging"
      ARCHIVE=""
      trap '${rm} -rf "$STAGING"; ${rm} -f "$ARCHIVE"' EXIT

      # --- Config ---
      PASSWORD=$(cat ${home}/Docs/Passwords/backup-password)
      DATE=$(${date} +%Y-%m-%d)
      STAGING="${home}/backup-staging"
      ARCHIVE="${home}/backup_$DATE.7z"
      GDRIVE="gDrive:/Backups"
      HOMESERVER="pod153:/home/9s/Backups"

      # --- Stage files ---
      ${rm}    -rf "$STAGING"
      ${mkdir} -p  "$STAGING"/{Gaming,nixos,.config}

      # --- Copy Home Files ---
      ${cp} -rf \
        ${home}/Docs/     \
        ${home}/Media/    \
        ${home}/Projects/ \
        ${home}/School/   \
        "$STAGING"/

      # --- Copy Gaming Files ---
      ${cp} -rf \
        ${home}/Gaming/Gaming-Ob/                \
        ${home}'/Gaming/Heroic/Wine Prefixes/'   \
        "$STAGING"/Gaming/

      # --- Copy NixOS Config Files ---
      ${cp} -rf \
        ${nixos}/configuration.nix \
        ${nixos}/flake.nix         \
        ${nixos}/home.nix          \
        ${nixos}/modules/          \
        ${nixos}/home-modules/     \
        "$STAGING"/nixos/

      # --- Copy Config Files ---
      ${cp} -rf \
        ${home}/.config/zen/       \
        ${home}/.config/rclone/    \
        ${home}/.config/keepassxc/ \
        ${home}/.config/heroic/    \
        "$STAGING"/.config/

      # --- Compress & encrypt ---
      ${p7zip} a -t7z "$ARCHIVE" "$STAGING/" -p"$PASSWORD" -mhe=on

      # --- Upload & Delete Old Backups ---
      ${rclone} copy   "$ARCHIVE"    "$GDRIVE"
      ${rclone} delete --min-age 5d  "$GDRIVE"
      ${rclone} copy   "$ARCHIVE"    "$HOMESERVER"
      ${rclone} delete --min-age 20d "$HOMESERVER"
    '';
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      User = "neburion";
      Type = "oneshot";
    };
  };
  systemd.timers.backup = {
    description = "Run backup daily";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };
  };
}
