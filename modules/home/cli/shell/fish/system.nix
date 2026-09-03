{ ... }:

# The NixOS half of fish. Required when a user's login shell is pkgs.fish —
# NixOS refuses a shell that is not enabled at system level.
#
# It lives here, beside the fish config it exists for, rather than in
# modules/system/: delete fish and this line is meaningless. The host imports
# this one file; the user imports ../fish for the rest.

{
  programs.fish.enable = true;
}
