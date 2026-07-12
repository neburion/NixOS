{ pkgs, ... }:

let
  pythonEnv = pkgs.python3.withPackages (p: [ p.flask ]);

  serverPy = pkgs.writeText "print-server.py" ''
    from flask import Flask, request
    import subprocess, tempfile, os

    app = Flask(__name__)
    app.config['MAX_CONTENT_LENGTH'] = 50 * 1024 * 1024

    ALLOWED = {'.pdf', '.jpg', '.jpeg', '.png', '.gif', '.tiff', '.bmp'}

    PAGE = lambda msg=''': f"""<!DOCTYPE html>
    <html><head><meta charset="utf-8"><title>Print</title>
    <style>
      body {{ font-family: sans-serif; max-width: 480px; margin: 3rem auto; padding: 0 1rem; }}
      h2 {{ margin-bottom: 1.5rem; }}
      input[type=file] {{ display: block; margin-bottom: 1rem; }}
      button {{ padding: .4rem 1.2rem; cursor: pointer; }}
      .ok {{ color: green; margin-top: 1rem; }}
      .err {{ color: red; margin-top: 1rem; }}
    </style>
    </head><body>
    <h2>Print a document</h2>
    <form method=post enctype=multipart/form-data action=/print>
      <input type=file name=file accept=".pdf,.jpg,.jpeg,.png,.gif,.tiff,.bmp">
      <button>Send to printer</button>
    </form>
    {msg}
    </body></html>"""

    @app.get('/')
    def index():
        return PAGE()

    @app.post('/print')
    def print_file():
        f = request.files.get('file')
        if not f or not f.filename:
            return PAGE('<p class=err>No file selected.</p>')
        ext = os.path.splitext(f.filename)[1].lower()
        if ext not in ALLOWED:
            return PAGE(f'<p class=err>Unsupported format: {ext!r} — use PDF or an image.</p>')
        with tempfile.NamedTemporaryFile(suffix=ext, delete=False) as tmp:
            f.save(tmp.name)
            path = tmp.name
        try:
            r = subprocess.run(['lp', path], capture_output=True, text=True)
            if r.returncode == 0:
                return PAGE('<p class=ok>Sent to printer.</p>')
            return PAGE(f'<p class=err>Print error: {r.stderr.strip()}</p>')
        finally:
            os.unlink(path)

    if __name__ == '__main__':
        app.run(host='0.0.0.0', port=8080)
  '';

  printServer = pkgs.writeShellApplication {
    name = "print-server";
    runtimeInputs = [ pythonEnv pkgs.cups ];
    text = "exec python3 ${serverPy}";
  };

  nixprinter = pkgs.writeShellApplication {
    name = "nixprinter";
    runtimeInputs = [ pkgs.cups ];
    text = ''
      URI="cnusbufr2:/dev/usb/lp0"

      if [[ ! -c /dev/usb/lp0 ]]; then
        echo "Error: /dev/usb/lp0 not found. Is the printer powered on and usblp loaded?"
        exit 1
      fi

      PPD=$(lpinfo -m 2>/dev/null | awk '/MF3010/{print $1; exit}')
      if [[ -z "$PPD" ]]; then
        echo "PPD for MF3010 not found in installed drivers."
        exit 1
      fi

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

  # Canon UFR2 libraries hardcode /usr/share/{cnpkbidir,caepcm,ufr2filterr}.
  # CUPS strips LD_PRELOAD from filter processes, so NIX_REDIRECTS won't work.
  # Create real symlinks instead so the paths resolve unconditionally.
  systemd.tmpfiles.rules = [
    "d /usr/share 0755 root root - -"
    "L+ /usr/share/cnpkbidir - - - - ${pkgs.canon-cups-ufr2}/share/cnpkbidir"
    "L+ /usr/share/caepcm - - - - ${pkgs.canon-cups-ufr2}/share/caepcm"
    "L+ /usr/share/ufr2filterr - - - - ${pkgs.canon-cups-ufr2}/share/ufr2filterr"
  ];

  users.users.print-server = {
    isSystemUser = true;
    group = "print-server";
    extraGroups = [ "lp" ];
  };
  users.groups.print-server = {};

  systemd.services.print-server = {
    description = "Web print server for Canon MF3010";
    wantedBy = [ "multi-user.target" ];
    after = [ "cups.service" "network.target" ];
    requires = [ "cups.service" ];
    serviceConfig = {
      ExecStart = "${printServer}/bin/print-server";
      Restart = "on-failure";
      RestartSec = "5s";
      User = "print-server";
      Group = "print-server";
    };
  };

  environment.systemPackages = [ nixprinter ];

  networking.firewall.allowedTCPPorts = [ 8080 ];
}
