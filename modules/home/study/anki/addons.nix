{ pkgs }:

# Anki addons, as a plain list for ./default.nix to wrap the program in.
#
# A separate file because this is the half that changes: adding or dropping an
# addon rebuilds Anki's wrapper and touches nothing else about the program.
# Not a module and no option behind it — the list is the interface.
#
# What `pkgs.ankiAddons` offers, in full:
#
#   adjust-sound-volume            image-occlusion-enhanced
#   ajt-card-management            local-audio-yomichan
#   anki-connect                   passfail2
#   anki-quizlet-importer-extended puppy-reinforcement
#   fsrs4anki-helper               recolor
#   review-heatmap                 reviewer-refocus-card
#   yomichan-forvo-server
#
# Anything outside that set has to be installed from Anki's own addon browser,
# which writes into ~/.local/share/Anki2/addons21 and is invisible to Nix —
# it will survive rebuilds, but it is not described here.
#
# FSRS is not on the list because it is not an addon any more: it has been the
# built-in scheduler since 23.10, and fsrs4anki-helper is only extra commands
# layered on top of it.
#
# Empty on purpose.

with pkgs.ankiAddons; [
]
