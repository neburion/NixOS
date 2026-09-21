#!/usr/bin/env python3
"""fleet-status server — hands out one file and knows nothing else.

The counterpart to collect.py. That one runs as root because reading another
user's systemd units and syncthing's API key needs it; this one runs as a
dynamic user with no privilege at all, and its entire job is to read a file
off disk and write it to a socket.

Splitting them is the point. A dashboard agent is a listener on every host in
the fleet, and the version of it that both collects and serves is a root
process parsing requests off the network. This one cannot be talked into
anything: there is no path parameter, no query string, no second file, and the
only verb is GET.

Reachable on the tailnet interface only; the firewall rule lives in the module
beside this file.
"""
import json
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

STATUS = Path(os.environ.get("FS_OUT", "/var/lib/fleet-status/status.json"))
HOST = os.environ.get("FS_BIND", "0.0.0.0")
PORT = int(os.environ.get("FS_PORT", "8081"))


class Handler(BaseHTTPRequestHandler):
    server_version = "fleet-status"
    # The default logs a line per request to stderr, and a dashboard polling
    # three hosts every few seconds would fill the journal with its own
    # heartbeat. Real failures still raise.
    def log_message(self, *a):
        pass

    def _send(self, body, code=200):
        raw = body if isinstance(body, bytes) else json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(raw)))
        # Every field in here is a measurement with a timestamp on it. A cached
        # copy is not a cheaper answer, it is a wrong one.
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(raw)

    def do_GET(self):
        # A fixed comparison rather than a route table: this server has exactly
        # one thing to say, and matching the path any other way is how a file
        # server grows out of something that was not one.
        if self.path.split("?")[0] not in ("/", "/status.json"):
            return self._send({"error": "not found"}, 404)
        try:
            return self._send(STATUS.read_bytes())
        except FileNotFoundError:
            # The first half-minute after boot, before the timer has fired
            # once. Distinct from a broken collector, which writes a file full
            # of per-section errors rather than no file at all.
            return self._send({"error": "no reading collected yet"}, 503)


if __name__ == "__main__":
    ThreadingHTTPServer((HOST, PORT), Handler).serve_forever()
