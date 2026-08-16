{ ... }:

# Static tailnet peer name → IP mapping.
#
# We deliberately don't use Tailscale's MagicDNS (see tailscale.nix's
# --accept-dns=false) because enabling it hijacks the OS resolver
# and breaks external DNS unless the tailnet admin has configured
# global nameservers via the CF dashboard (which we don't want to touch).
#
# Since Tailscale assigns each device a stable IP that persists across
# reboots and reinstalls, hardcoding here is safe and fully declarative.
# Update this file whenever a new host joins the fleet.
#
# Consumer: /etc/hosts entries. Everything that resolves a bare hostname
# (SSH, ping, rebuild <host>, curl <host>, etc.) will find the tailnet IP.

{
  networking.hosts = {
    "100.82.222.16" = [ "pod042" ];
    "100.93.96.98"  = [ "home-server" ];
    # personal-server: fill in after its first boot joins the tailnet.
    # `tailscale status | grep personal-server` on any fleet host, then
    # commit the line — until then `rebuild personal-server` can't resolve it.
    # "100.x.y.z"   = [ "personal-server" ];
  };
}
