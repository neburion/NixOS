{ pkgs, lib, config, ... }:

let
  personaFiles = builtins.readDir ./personas;

  personaDir = pkgs.runCommand "claude-personas" { } ''
    mkdir -p $out/personas
    cp ${./base.md} $out/base.md
    ${lib.concatStringsSep "\n" (
      lib.mapAttrsToList
        (name: _: "cp ${./personas + "/${name}"} $out/personas/${name}")
        personaFiles
    )}
  '';

  claudePersona = pkgs.writeShellApplication {
    name = "claude-persona";
    runtimeInputs = with pkgs; [ coreutils gnugrep ];
    text = builtins.replaceStrings
      [ "@PERSONA_DIR@" ]
      [ "${personaDir}" ]
      (builtins.readFile ./claude-persona.sh);
  };
in
{
  home.packages = [ claudePersona ];

  home.activation.claudePersonaInit =
    config.lib.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p "$HOME/.claude"
      if [ ! -f "$HOME/.claude/CLAUDE.md" ] \
         || ! head -1 "$HOME/.claude/CLAUDE.md" | grep -q "claude-persona:"; then
        if [ -f "$HOME/.claude/CLAUDE.md" ]; then
          cp "$HOME/.claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md.pre-persona-backup"
        fi
        ${claudePersona}/bin/claude-persona nyx
      fi
    '';
}
