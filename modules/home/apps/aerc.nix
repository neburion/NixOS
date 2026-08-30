{ pkgs, ... }:

# aerc — TUI mail client, running alongside Thunderbird (apps/thunderbird.nix).
# Both point at the same Posteo mailbox over IMAP; nothing is migrated, so
# dropping either one is a single import line.
#
# Unlike Thunderbird, aerc *can* fetch its own credential, so the account is
# fully declarative here. See `posteoPass` below for where the password comes
# from — it is never written into the flake or the nix store.
#
# Colours: the styleset addresses terminal palette indices (0-15), not hex.
# Ghostty already carries the active palette (terminal/ghostty-glass.nix), so
# aerc inherits it for free — including the 0.92 background opacity, because
# the styleset never sets an explicit background. That also means this module
# stays preset-agnostic: it looks right under clean and simple too, with no
# theme hook and no duplicated palette.

let
  # Credential lookup, in preference order:
  #   1. /run/secrets/posteo-password — sops-nix. Inactive today: there is no
  #      secrets/pod042.yaml, and declaring a secret against a missing file is
  #      an eval error, so the sops side is deliberately not wired up. To
  #      switch over, `sops secrets/pod042.yaml`, add a `posteo-password` key,
  #      then declare it with `owner = "neburion"; mode = "0400";`. This script
  #      needs no change — it already prefers that path.
  #   2. ~/.config/aerc/posteo.pass — plain file, mode 0600, outside the repo.
  #
  # Referenced as `passwordCommand`, so aerc runs it on demand and the secret
  # never lands in ~/.config/aerc/accounts.conf (which is a world-readable
  # /nix/store symlink — see `unsafe-accounts-conf` below).
  posteoPass = pkgs.writeShellScript "aerc-posteo-pass" ''
    set -eu

    sops_path=/run/secrets/posteo-password
    file_path="''${XDG_CONFIG_HOME:-$HOME/.config}/aerc/posteo.pass"

    if [ -r "$sops_path" ]; then
      exec cat "$sops_path"
    elif [ -r "$file_path" ]; then
      exec cat "$file_path"
    fi

    echo "aerc: no Posteo password available." >&2
    echo "  Write the Posteo app password to $file_path and chmod 600 it," >&2
    echo "  or add a posteo-password key to secrets/pod042.yaml." >&2
    exit 1
  '';

  # Ghostty's 16 colours, by index. Named so the styleset below reads as
  # intent rather than as arithmetic.
  base = "0";      # #191B1E — surface
  red = "1";
  green = "2";
  yellow = "3";
  blue = "4";
  magenta = "5";
  cyan = "6";
  fg = "7";        # #C8CBCF — body text
  muted = "8";     # #3B3E44 — borders, chrome
  brightFg = "15"; # #E8EAEC — emphasis
in
{
  accounts.email.accounts.posteo = {
    primary = true;
    address = "paperkite@posteo.com";
    userName = "paperkite@posteo.com";
    realName = "neburion";
    passwordCommand = [ "${posteoPass}" ];

    imap = {
      host = "posteo.de";
      port = 993;
      tls.enable = true;
    };

    smtp = {
      host = "posteo.de";
      port = 465;
      tls.enable = true;
    };

    folders = {
      inbox = "INBOX";
      sent = "Sent";
      drafts = "Drafts";
      trash = "Trash";
    };

    # Reply-as for the azuresalt.app catch-all. aerc's `aliases` takes
    # fnmatch wildcards in the address portion specifically so a catch-all
    # domain needs no per-address setup: replying to mail that arrived at
    # hi@azuresalt.app sets From to hi@azuresalt.app, and the display name
    # comes from the alias rather than the matched address.
    #
    # Deliberately commented out, because enabling it today would break
    # those replies rather than fix them. Outgoing mail still goes through
    # Posteo, and Posteo enforces that From matches the authenticated
    # account — an azuresalt.app sender is rejected, not rewritten. Right
    # now such a reply goes out as paperkite@posteo.com: the wrong address,
    # but it does send.
    #
    # Uncomment the day outgoing points at an SMTP host that accepts an
    # arbitrary sender on the domain. Nothing else in this file changes.
    #
    # aliases = [ ''"neburion" <*@azuresalt.app>'' ];

    # The above is not quite enough on its own, because of how aerc picks the
    # From address on reply (commands/msg/reply.go, chooseFromAddr): it builds
    # a set from the message's From, To and Cc, and if the account's own
    # `from` is anywhere in that set it wins outright — aliases are only
    # consulted otherwise. Cloudflare forwards without touching To, so mail to
    # hi@azuresalt.app normally arrives with To: hi@azuresalt.app and the
    # wildcard matches. But anything that also lands the Posteo address in
    # To/Cc silently reverts the reply to paperkite@posteo.com.
    #
    # Cloudflare stamps the address the mail was actually routed for into
    # X-Original-To, and aerc reads exactly one such header, named by
    # `original-to-header`, folding it into the same set. That makes the match
    # depend on Cloudflare's own record of the routing rather than on To
    # surviving intact.
    #
    # Live already, and inert: chooseFromAddr returns early when there are no
    # aliases, so this does nothing until the line above is uncommented.
    # home-manager has no option for it, hence extraAccounts.
    aerc.extraAccounts."original-to-header" = "X-Original-To";

    aerc.enable = true;
  };

  programs.aerc = {
    enable = true;

    extraConfig = {
      general = {
        # accounts.conf is a symlink into /nix/store, so it is 0444 and aerc's
        # permission check would refuse to start. Safe here precisely because
        # `passwordCommand` keeps the credential out of that file.
        unsafe-accounts-conf = true;
      };

      ui = {
        styleset-name = "glass";
        sort = "-r date";
        threading-enabled = true;
        dirlist-tree = true;
        sidebar-width = 22;
        mouse-enabled = true;
        empty-message = "(empty)";

        timestamp-format = "2006-01-02 15:04";
        this-day-time-format = "15:04";
        this-week-time-format = "Mon 15:04";

        index-columns = "flags:4,name<20,subject<*,date>=";
        column-date = "{{.DateAutoFormat .Date.Local}}";
        column-name = "{{index (.From | names) 0}}";
        column-flags = "{{.Flags | join \"\"}}";
        column-subject = "{{.ThreadPrefix}}{{.Subject}}";

        border-char-vertical = "│";
        border-char-horizontal = "─";
      };

      viewer = {
        pager = "less -Rc";
        alternatives = "text/plain,text/html";
      };

      compose = {
        editor = "nvim";

        # Put the headers in the editor buffer instead of behind aerc's
        # prompts, so composing from an arbitrary local part is just typing
        # over the From line. This is the "write from anything@" half; the
        # `aliases` wildcard above is the "reply from whatever it arrived
        # at" half.
        edit-headers = true;
      };

      # `html` and `colorize` ship inside the aerc package under
      # libexec/aerc/filters and are on aerc's own PATH; the nixpkgs build
      # already wraps `html` with w3m, so no extra packages are needed.
      filters = {
        "text/plain" = "colorize";
        "text/calendar" = "calendar";
        "message/delivery-status" = "colorize";
        "message/rfc822" = "colorize";
        "text/html" = "! html";
        ".headers" = "colorize";
      };

      openers = {
        "text/html" = "xdg-open";
        "application/pdf" = "zathura";
      };
    };

    stylesets.glass = ''
      # Reset to the terminal's own colours, then tint only what carries
      # meaning. Nothing sets a background, so ghostty's translucency and blur
      # reach all the way through.
      *.default = true
      *.normal  = true

      *.selected.bg   = ${muted}
      *.selected.fg   = ${brightFg}
      *.selected.bold = true

      border.fg = ${muted}

      title.bg   = ${muted}
      title.fg   = ${brightFg}
      title.bold = true

      header.fg   = ${blue}
      header.bold = true

      statusline_default.fg = ${fg}
      statusline_default.bg = ${base}

      msglist_default.fg  = ${fg}
      msglist_unread.fg   = ${brightFg}
      msglist_unread.bold = true
      msglist_read.dim    = true
      msglist_deleted.dim = true
      msglist_marked.bg   = ${cyan}
      msglist_marked.fg   = ${base}
      msglist_pill.bg     = ${muted}
      msglist_pill.fg     = ${brightFg}

      dirlist_default.fg  = ${fg}
      dirlist_unread.fg   = ${brightFg}
      dirlist_unread.bold = true

      part_mimetype.fg = ${muted}

      selector_chooser.bold = true
      selector_focused.bold = true
      selector_focused.bg   = ${muted}
      selector_focused.fg   = ${brightFg}

      completion_default.fg     = ${brightFg}
      completion_pill.bg        = ${muted}
      completion_description.fg = ${fg}
      completion_description.dim = true

      *error.fg    = ${red}
      *error.bold  = true
      *error.dim   = false
      *warning.fg  = ${yellow}
      *warning.dim = false
      *success.fg  = ${green}
      *success.dim = false

      [viewer]
      *.default = true
      *.normal  = true

      url.underline = true
      url.fg        = ${cyan}

      header.bold = true
      header.fg   = ${blue}

      signature.dim = true
      signature.fg  = ${muted}

      quote_1.fg  = ${cyan}
      quote_2.fg  = ${blue}
      quote_3.fg  = ${magenta}
      quote_3.dim = true
      quote_4.fg  = ${blue}
      quote_4.dim = true
      quote_x.fg  = ${magenta}
      quote_x.dim = true

      diff_meta.bold = true
      diff_chunk.fg  = ${cyan}
      diff_add.fg    = ${green}
      diff_del.fg    = ${red}
    '';
  };
}
