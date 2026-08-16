{ ... }:

# PLACEHOLDER — this is not a description of any real machine.
#
# nixinstall.sh overwrites this file with `nixos-generate-config
# --show-hardware-config` output before it runs nixos-install, so a fresh
# install never sees this content and the failing assertion below never
# fires during installation.
#
# Why the assertion exists at all: this repo COMMITS hardware-configuration.nix
# (hosts/home-server/ and hosts/pod042/ both carry a real one), while `rebuild`
# deploys from github:neburion/NixOS rather than the local tree. So if the
# generated file is left sitting on the installed machine and never copied back
# into the repo, `rebuild personal-server` would happily deploy a system that
# declares no root filesystem. The assertion turns that into a loud build-time
# error instead of a broken boot.
#
# After the first install, on personal-server:
#   cat /etc/nixos/hosts/personal-server/hardware-configuration.nix
# paste over this file, commit, push. Then `rebuild personal-server` works.
#
# The assertion is only forced when something builds this host's toplevel, so
# cf-reconcile's `nix eval` over every host's declaredTunnels is unaffected.

{
  assertions = [
    {
      assertion = false;
      message = ''
        hosts/personal-server/hardware-configuration.nix is still the placeholder.

        Replace it with the output of `nixos-generate-config --show-hardware-config`
        taken from the installed machine, then commit and push before rebuilding.
      '';
    }
  ];

  boot.initrd.availableKernelModules = [ ];
  boot.initrd.kernelModules          = [ ];
  boot.kernelModules                 = [ ];
  boot.extraModulePackages           = [ ];
}
