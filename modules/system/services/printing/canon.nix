{ pkgs, ... }:

let
  nixprinter = pkgs.writeShellApplication {
    name = "nixprinter";
    # grep/awk/seq/sleep are as load-bearing as lpadmin here. This used to be
    # `[ pkgs.cups ]` alone and worked, because it was only ever run by hand
    # from a login shell that had the rest on PATH. Started from udev the unit
    # gets writeShellApplication's PATH and nothing else, and the first run
    # after the printer was plugged in died on `awk: command not found`.
    runtimeInputs = with pkgs; [ cups gawk gnugrep coreutils ];
    text = ''
      # Find the USB URI from CUPS. Polled, not read once: this also runs from
      # a udev trigger the instant the device appears, and CUPS' USB backend
      # takes a few seconds to enumerate it. Failing on the first look would
      # mean the printer is plugged in and silently not registered.
      URI=""
      for _ in $(seq 1 30); do
        URI=$(lpinfo -v 2>/dev/null | grep -o 'usb://Canon/MF3010[^ ]*' || true)
        [[ -n "$URI" ]] && break
        sleep 2
      done

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

  # Plugging the MFP in is the whole user interaction. Without this, the
  # printer appears on the USB bus and CUPS still has no queue for it until
  # someone remembers to ssh in and run `nixprinter` by hand.
  #
  # 04a9:2759 is the MF3010. The rule fires on coldplug too, so a printer
  # already attached at boot registers the same way as one plugged in later.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="04a9", ATTR{idProduct}=="2759", TAG+="systemd", ENV{SYSTEMD_WANTS}+="canon-mf3010-register.service"
  '';

  systemd.services.canon-mf3010-register = {
    description = "Register the Canon MF3010 with CUPS when it is plugged in";
    after = [ "cups.service" ];
    requires = [ "cups.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${nixprinter}/bin/nixprinter";
      # lpadmin on an existing queue just rewrites it, so a replug or a second
      # udev event is a no-op rather than an error.
      SuccessExitStatus = [ 0 ];
    };
  };
}
