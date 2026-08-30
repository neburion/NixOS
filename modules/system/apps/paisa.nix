{ config, pkgs, ... }:

# Paisa — expense and net-worth tracking over a plain-text hledger journal.
#
# Not an app.json project, so it does not go through apps/platform.nix: there
# is no repo of ours to deploy, only a nixpkgs binary and a state directory.
# What it borrows from the platform is the shape — own user, own StateDirectory,
# password by LoadCredential, tunnel declared here rather than in the host.
#
# ── Why a journal and not a database ────────────────────────────────────────
#
# The data is one text file, /var/lib/paisa/main.journal, in hledger format:
#
#     2026-08-30 * Groceries
#         Expenses:Food:Groceries    42.50 CAD
#         Assets:Checking
#
# Two front ends read it and neither owns it. Paisa gives the dashboards and a
# CodeMirror editor at /editor, which is what makes this reachable from a phone.
# `hledger` on this host gives the query engine — `hledger bal`, `-M` for month
# columns, `--budget`, `roi` — for the questions a fixed dashboard cannot ask.
# paisa.db beside it is a derived index; delete it and the next start rebuilds
# it from the journal. The journal is the only file that matters, and it lands
# in /var/lib, which backup-layout.nix already snapshots wholesale.
#
# ── Why the unit cannot reach the internet ──────────────────────────────────
#
# Paisa is written for the Indian market and fetches price and tax data from
# Indian endpoints. Most of it is opt-in — a quote is fetched per commodity you
# declare under `commodities:`, and this config declares none — but one call is
# unconditional: `paisa update` asks india.finbodhi.com for the Cost Inflation
# Index on every run, whether or not anything in the journal could use it.
#
# Every one of those is a download of public reference data; no transaction,
# account name or balance is part of any request. But "the config currently
# declares no commodities" is a property of a file that a web editor on a
# public hostname can rewrite, which is a weak guarantee for financial data.
# IPAddressDeny turns it into a kernel-enforced one. The allow-list is exactly
# the two things that must reach the port:
#
#   localhost       cloudflared dials 127.0.0.1 from inside this host, which
#                   is how the public URL works — see cloudflare-tunnel.nix
#   100.64.0.0/10   the tailnet, so the box is usable without the tunnel
#
# The CII fetch then fails with `network is unreachable` and `paisa update`
# exits 0 anyway — verified, it is non-fatal — so the only cost is one ERROR
# line in the journal at each start. Note this is egress *and* ingress: adding
# a price provider later means editing this list, deliberately, in a commit.
#
# ── The password ────────────────────────────────────────────────────────────
#
# Paisa's own auth, not just Cloudflare Access. Every /api/ route answers 401
# without it — verified against the binary, including /api/editor/*, so the
# journal is not readable by an unauthenticated request even though the SPA
# shell at / is.
#
# The wire format is a header, `X-Auth: <username>:<sha256(password)>`, which
# the server hashes once more and compares to what the config stores. Hence
# the double hash below, and hence the name of the config field: it holds
# sha256(sha256(password)), never the password.
#
#     printf %s "$pw" | sha256sum | sha256sum   (hex of the first feeds the second)
#
# Kept out of the store on purpose. The plaintext arrives via LoadCredential at
# unit start and the hash is computed into paisa.yaml at runtime, so neither
# form is world-readable under /nix/store. restartUnits on the secret matters
# for the same reason it does in platform.nix — the config is written once per
# start, so rotating the sops value without a restart leaves the old password
# live while the deploy prints a perfectly normal "Done."

let
  port = 8779;
  hostname = "paisa.azuresalt.app";
  username = "neburion";

  stateDir = "/var/lib/paisa";

  # Seeded once, then his. The editor at /editor can rewrite this file — that
  # is the point of having it — so the unit must not stamp it back on every
  # start or a budget added from a phone would vanish at the next reboot.
  # Only user_accounts is re-asserted below, because that one field answers to
  # sops rather than to the UI.
  seedConfig = pkgs.writeText "paisa.yaml" ''
    journal_path: 'main.journal'
    db_path: 'paisa.db'
    ledger_cli: hledger
    default_currency: CAD
    locale: en-CA
    display_precision: 2
    # Calendar year: Canada's personal tax year, not Paisa's April default.
    financial_year_starting_month: 1
    week_starting_day: 1
    # Accounts may be invented as you type them. Turning this on later makes
    # hledger reject anything not declared in the journal first — worth doing
    # once the account tree has settled, and annoying before then.
    strict: no
  '';

  # A first transaction so the dashboards render something other than an error,
  # and a worked example of the format in the file he is about to type into.
  seedJournal = pkgs.writeText "main.journal" ''
    ; This file is your ledger. Every transaction lives here, in plain text.
    ;
    ; Shape of an entry:
    ;
    ;   date * description
    ;       Account:It:Went:To        amount CAD
    ;       Account:It:Came:From
    ;
    ; The amounts have to cancel out — money leaves one account and lands in
    ; another. Leave the last line's amount blank and hledger fills it in.
    ;
    ;   2026-08-30 * Groceries
    ;       Expenses:Food:Groceries    42.50 CAD
    ;       Assets:Checking
    ;
    ;   2026-08-30 * Paycheque
    ;       Assets:Checking          2000.00 CAD
    ;       Income:Salary
    ;
    ; Account names are yours to invent; the colons make the tree that Paisa
    ; groups its charts by. Expenses:, Income:, Assets:, Liabilities: and
    ; Equity: are the five roots double-entry expects at the top.

    2026-08-30 * Opening balance
        Assets:Checking             0.00 CAD
        Equity:Opening-Balances
  '';

  # Runs as the paisa user with the credential already loaded. Seeds what is
  # missing, re-asserts the password, rebuilds the derived index.
  prestart = pkgs.writeShellApplication {
    name = "paisa-prestart";
    runtimeInputs = [ pkgs.coreutils pkgs.yq-go pkgs.paisa pkgs.hledger ];
    text = ''
      cfg="${stateDir}/paisa.yaml"
      journal="${stateDir}/main.journal"

      [ -e "$journal" ] || install -m 0640 ${seedJournal} "$journal"
      [ -e "$cfg" ]     || install -m 0640 ${seedConfig}  "$cfg"

      # `head -c 64` is the documented incantation, but it closes the pipe
      # early and this script runs under pipefail, so sha256sum dies of SIGPIPE
      # and takes the unit's start with it. cut reads to EOF instead.
      sha() { sha256sum | cut -d' ' -f1; }

      pw=$(cat "$CREDENTIALS_DIRECTORY/password")
      once=$(printf '%s' "$pw" | sha)
      twice=$(printf '%s' "$once" | sha)

      yq -i ".user_accounts = [{\"username\": \"${username}\", \"password\": \"sha256:$twice\"}]" "$cfg"

      # Rebuild paisa.db from the journal. Logs one failed Cost Inflation Index
      # fetch — see the header — and exits 0 regardless.
      paisa update --config "$cfg"
    '';
  };
in
{
  users.users.paisa = {
    isSystemUser = true;
    group = "paisa";
  };
  users.groups.paisa = { };

  sops.secrets.paisa-password = {
    sopsFile = ../../../secrets + "/${config.networking.hostName}.yaml";
    mode = "0400";
    restartUnits = [ "paisa.service" ];
  };

  systemd.services.paisa = {
    description = "Paisa — expense tracking over an hledger journal";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];

    # `ledger_cli: hledger` makes Paisa shell out to `hledger` by bare name.
    # The parse that matters happens in ExecStartPre, which gets hledger from
    # its own runtimeInputs, and a serve with no hledger on PATH answered every
    # endpoint identically when tested — so this is insurance for the in-process
    # paths (/api/sync, saving from the editor), not a demonstrated requirement.
    #
    # Set as `path` rather than an Environment= entry: the latter emits a second
    # PATH= line, and systemd takes the last one, so it replaces the default
    # PATH instead of extending it.
    path = [ pkgs.hledger ];

    serviceConfig = {
      ExecStartPre = "${prestart}/bin/paisa-prestart";
      ExecStart = "${pkgs.paisa}/bin/paisa serve --port ${toString port} --config ${stateDir}/paisa.yaml";
      Restart = "on-failure";
      RestartSec = "5s";

      User = "paisa";
      Group = "paisa";
      StateDirectory = "paisa";
      StateDirectoryMode = "0750";

      # Read as root before the User= drop, so the plaintext never enters the
      # process environment table.
      LoadCredential = "password:${config.sops.secrets.paisa-password.path}";

      # See the header. Loopback for cloudflared, the tailnet for direct use,
      # nothing else in either direction.
      IPAddressDeny = "any";
      IPAddressAllow = [ "localhost" "100.64.0.0/10" ];

      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      PrivateDevices = true;
      NoNewPrivileges = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" ];
      RestrictNamespaces = true;
      LockPersonality = true;
      SystemCallArchitectures = "native";
    };
  };

  # Same rule the platform applies to its apps: the port is open on the tailnet
  # only, and the public URL is cloudflared reaching 127.0.0.1 from inside.
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ port ];

  cloudflare.declaredTunnels.${hostname} = {
    service = "http://localhost:${toString port}";
  };

  # The other half of the pair. `hledger -f /var/lib/paisa/main.journal bal -M`
  # from a shell here answers what the dashboards cannot; hledger-ui is the
  # same data as a TUI. Both need to read the state directory, so: sudo -u paisa.
  environment.systemPackages = [ pkgs.hledger pkgs.hledger-ui ];
}
