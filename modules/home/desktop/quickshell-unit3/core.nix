{ ... }:

# Reuse the qs binary + systemd user service from the main quickshell core.
# The service's X-Restart-Triggers fingerprint filters config.xdg.configFile
# entries starting with "quickshell/" — our files match, so the shell
# reloads whenever any Unit-3 QML changes.

{
  imports = [ ../quickshell/package.nix ];
}
