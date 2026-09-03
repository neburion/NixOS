{ ... }:

# The print and scan stack: the Canon driver and the web UI in front of it.
#
# Not a module — a host could reasonably want the printer without the Flask UI,
# or the UI is the only part you are debugging. Import the two files directly
# when that is the case; this is the usual pairing.

{
  imports = [
    ./canon
    ./web-ui.nix
  ];
}
