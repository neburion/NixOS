{ pkgs, lib, ... }:

# Network-wide DNS ad blocker (AdGuard Home) + LAN DHCP server.
#
# Setup constraint: Bell HH3000 doesn't forward client DNS through its
# "Modem→DNS" setting (well-documented community finding), so pointing
# the router at us doesn't achieve network-wide blocking. The working
# pattern for HH3000 is: turn OFF Bell's DHCP, run DHCP here, advertise
# ourselves as DNS via DHCP option 6. Clients then query AdGuard the
# "correct" way — DHCP-issued DNS server.
#
# Fully declarative — mutableSettings = false. Whitelisting a domain means
# editing this file (add to user_rules) and running `rebuild`, not clicking
# in the web UI. That's intentional: laptop-loss doesn't erase state. The
# DHCP LEASE TABLE (which device has which IP) is by nature runtime state
# and lives under /var/lib/AdGuardHome; that's fine, it's operational data
# not configuration.
#
# Admin UI:  http://home-server.local:3000   user: home-admin  pw: 1234
# LAN-only trust boundary (same as the print/scan UI); if this ever leaves
# the LAN, swap the bcrypt hash below.

let
  # bcrypt of "1234", generated with `htpasswd -bnBC 10 "" 1234`.
  # Trivial LAN-only password matching users/home-admin/account.nix.
  adminBcrypt = "$2y$10$bIF2h2vOAoMC2DD9BT3HxurL3aYKMgFTxQv9NJAv7tB.YZ/Q77vQ6";
in
{
  services.adguardhome = {
    enable = true;
    mutableSettings = false;
    openFirewall = true;
    host = "0.0.0.0";
    port = 3000;

    settings = {
      # Web UI login.
      users = [
        { name = "home-admin"; password = adminBcrypt; }
      ];

      http = {
        address = "0.0.0.0:3000";
      };

      dns = {
        bind_hosts = [ "0.0.0.0" ];
        port = 53;

        # DNS-over-HTTPS upstream (Quad9). The ISP can't see or hijack the
        # actual lookups this way, even though ISP DNS is still what the
        # router falls back to if AdGuard is unreachable.
        upstream_dns = [
          "https://dns.quad9.net/dns-query"
        ];

        # Plain-IP resolvers used only to bootstrap the DoH endpoint's own
        # hostname. Quad9's two anycast IPs.
        bootstrap_dns = [
          "9.9.9.9"
          "149.112.112.112"
        ];

        cache_size = 4194304;
        cache_ttl_min = 60;
        cache_ttl_max = 86400;

        filtering_enabled = true;
        protection_enabled = true;
        blocking_mode = "default";

        # No rate limiting on the LAN — a single family device can easily
        # burst past the default 20 qps during a page load.
        ratelimit = 0;

        querylog_enabled = true;
        statistics_interval = "24h";

        safebrowsing_enabled = true;
        parental_enabled = false;
      };

      # Two well-maintained blocklists. AdGuard's own list covers ads and
      # trackers; OISD Big adds a broader "known bad" set (phishing,
      # crypto miners, coin drainers, aggressive telemetry).
      filters = [
        { name = "AdGuard DNS filter"; url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt"; enabled = true; id = 1; }
        { name = "OISD Big";           url = "https://big.oisd.nl";                                                enabled = true; id = 2; }
      ];

      # Per-domain whitelist / manual rules. Edit this list and `rebuild`
      # when family reports "site X is broken". Syntax is standard
      # AdGuard filtering rules:
      #   @@||example.com^          — allow example.com and all subdomains
      #   ||annoying-ad-host.com^   — extra block
      user_rules = [
      ];

      # DHCP server: disabled. We attempted the community-standard "turn
      # off Bell DHCP, let AdGuard hand out leases" pattern (see
      # https://discourse.pi-hole.net/t/bell-home-hub-3000-setup-problems/1012),
      # but hit a Bell HH3000 quirk where a device with a static IP and
      # no active DHCP lease gets its outbound-to-WAN traffic blocked
      # (ARP INCOMPLETE / silent drops). Documented in [[project-bell-hh3000]].
      #
      # Falling back to: Bell keeps DHCP, AdGuard is DNS-only. Devices
      # that want ad blocking need to point their DNS at this box
      # manually (see admin UI clients page, or per-device wifi settings).
      # Not network-wide, but doesn't fight Bell.
      dhcp = { enabled = false; };

      schema_version = 27;
    };
  };

  # Auto-restart on any failure with a short backoff — one of the two
  # resilience legs (the other is the Quad9 secondary the router uses
  # as a fallback if this service is completely down).
  systemd.services.adguardhome.serviceConfig = {
    Restart = lib.mkForce "always";
    RestartSec = lib.mkForce 5;
  };

  # openFirewall above only opens the admin UI port (3000). Open :53 (DNS)
  # and :67 (DHCP server) explicitly. DHCP uses UDP only.
  networking.firewall.allowedTCPPorts = [ 53 ];
  networking.firewall.allowedUDPPorts = [ 53 67 ];
}
