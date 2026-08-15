{ ... }:

# sshd + fleet-wide client config. programs.ssh.extraConfig applies to every
# outbound SSH from this host — so once every fleet member imports this
# module, `ssh <host>` uses the right admin user + skips the interactive
# host-key prompt on first connect. The rebuild wrapper leans on this
# (it passes bare `<host>` to `nixos-rebuild --target-host`).

{
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = true;
      PermitRootLogin        = "no";
    };
  };

  # Fleet-wide client config. Add a Host block per admin user; the flake
  # hostname (used in `rebuild <host>`) matches the tailnet MagicDNS name,
  # so no separate hostname mapping is needed.
  programs.ssh.extraConfig = ''
    Host home-server
      User home-admin

    Host *
      StrictHostKeyChecking accept-new
  '';
}

