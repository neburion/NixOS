{ config, lib, pkgs, ... }:

# sops-nix wiring. Two secret files per host:
#   secrets/<hostname>.yaml — host-specific runtime credentials
#                             (e.g. cloudflared credentials for THIS host's tunnels)
#   secrets/common.yaml     — fleet-wide credentials any host may read
#                             (API tokens for reconcilers, tailscale auth key,
#                              restic passphrase, etc.)
#
# Per-secret module usage:
#   sops.secrets.cloudflared-home-server = {
#     sopsFile = ../../../secrets/home-server.yaml;   # default: hostSecrets
#     owner    = "cloudflared";
#     group    = "cloudflared";
#     mode     = "0400";
#   };
#   sops.secrets.tailscale-auth-key = {
#     sopsFile = ../../../secrets/common.yaml;
#     mode     = "0400";
#   };
# Consumers read `config.sops.secrets.<name>.path` → resolves to /run/secrets/<name>.
#
# Age private key MUST live at /var/lib/sops-nix/key.txt (mode 0400 root:root).
# nixinstall.sh installs it at first-install time from secrets/age-key.enc.
# For existing hosts that haven't had a key installed yet, decrypt on any dev
# machine and pipe via ssh:
#   openssl enc -d -aes-256-cbc -pbkdf2 -iter 600000 \
#     -in secrets/age-key.enc -pass stdin | \
#     ssh <host> 'sudo install -Dm400 /dev/stdin /var/lib/sops-nix/key.txt'

let
  hostSecrets   = ../../../secrets + "/${config.networking.hostName}.yaml";
  commonSecrets = ../../../secrets/common.yaml;
  hasHost       = builtins.pathExists hostSecrets;
  hasCommon     = builtins.pathExists commonSecrets;
in
{
  # `sops` CLI on every host so reconcilers (and manual `sops edit`) work
  # from any fleet machine, not just pod042.
  environment.systemPackages = [ pkgs.sops ];

  sops = lib.mkIf (hasHost || hasCommon) {
    # defaultSopsFile picks hostSecrets when present; common secrets always
    # need to specify `sopsFile = commonSecrets` explicitly so it's obvious
    # at the callsite which file a secret lives in.
    defaultSopsFile = if hasHost then hostSecrets else commonSecrets;
    age.keyFile     = "/var/lib/sops-nix/key.txt";
    # No SSH-key fallback — we want decryption to depend solely on the age
    # key installed at build/install time. Explicit is better than surprise.
    age.sshKeyPaths   = [ ];
    gnupg.sshKeyPaths = [ ];
  };
}
