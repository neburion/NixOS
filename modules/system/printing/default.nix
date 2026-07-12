{ pkgs, ... }:

let
  nixprinter = pkgs.writeShellApplication {
    name = "nixprinter";
    runtimeInputs = [ pkgs.cups ];
    text = ''
      # Dynamically find the USB URI from CUPS
      URI=$(lpinfo -v | grep -o 'usb://Canon/MF3010[^ ]*')
      
      if [[ -z "$URI" ]]; then
        echo "Error: Canon MF3010 not found by CUPS via USB."
        exit 1
      fi

      PPD=$(lpinfo -m 2>/dev/null | awk '/MF3010/{print $1; exit}')
      if [[ -z "$PPD" ]]; then
        echo "PPD for MF3010 not found in installed drivers."
        exit 1
      fi

      # Add the printer using the dynamic URI
      lpadmin -p MF3010 -E -v "$URI" -m "$PPD" -D "Canon MF3010" -L "USB"
      lpoptions -d MF3010
      echo "Done — MF3010 configured at $URI."
    '';
  };
in
{
  imports = [ ./web-server.nix ];

  boot.kernelModules = [ "usblp" ];

  services.printing = {
    enable = true;
    drivers = [ pkgs.canon-cups-ufr2 ];
  };

  # Canon UFR2 hardcodes /usr/share/{cnpkbidir,caepcm,ufr2filterr,cngplp2}
  # and /usr/bin/{cnpkmoduleufr2r,cnjbigufr2}. cnrsdrvufr2 has an LD_PRELOAD
  # libredirect wrapper that would remap these, but it fails for cnjbigufr2
  # (spawned with empty argv) — that child dies with ENOENT, SIGPIPEs
  # cnrsdrvufr2, and orphans cnpkmoduleufr2r in a busy read loop.
  # Real symlinks make the redirect unnecessary.
  systemd.tmpfiles.rules = [
    "d /usr/share 0755 root root - -"
    "d /usr/bin 0755 root root - -"
    "L+ /usr/share/cnpkbidir - - - - ${pkgs.canon-cups-ufr2}/share/cnpkbidir"
    "L+ /usr/share/caepcm - - - - ${pkgs.canon-cups-ufr2}/share/caepcm"
    "L+ /usr/share/ufr2filterr - - - - ${pkgs.canon-cups-ufr2}/share/ufr2filterr"
    "L+ /usr/share/cngplp2 - - - - ${pkgs.canon-cups-ufr2}/share/cngplp2"
    "L+ /usr/bin/cnjbigufr2 - - - - ${pkgs.canon-cups-ufr2}/bin/cnjbigufr2"
    "L+ /usr/bin/cnpkmoduleufr2r - - - - ${pkgs.canon-cups-ufr2}/bin/cnpkmoduleufr2r"
  ];

  environment.etc."cngplp2/options/options.conf".text = "";

  environment.systemPackages = [ nixprinter ];
}
