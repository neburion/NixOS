{ pkgs, ... }:

{
  home.packages = [
    (pkgs.writeShellScriptBin "beg-for-passwords" ''
      VAULT=/root/.vault

      RED='\033[0;31m'
      YEL='\033[1;33m'
      CYN='\033[0;36m'
      GRN='\033[0;32m'
      BLD='\033[1m'
      RST='\033[0m'

      clear
      echo ""
      echo -e "''${BLD}  PASSWORD VAULT''${RST}"
      echo -e "''${YEL}  (for the golden retriever who lost them again)''${RST}"
      echo ""
      echo -e "  So. Here we are."
      echo -e "  You need your passwords and you cannot be trusted to remember them."
      echo -e "  This is not a surprise to anyone."
      echo ""
      echo -e "  You may beg. Three stages. Exact text. Case-sensitive."
      echo -e "  One mistake and you start over."
      echo ""
      echo -e "  Good luck. You'll need it."
      echo ""

      prompt_stage() {
        local stage="$1"
        local expected="$2"
        local fail_msg="$3"

        echo -e "''${CYN}  ── Stage $stage of 3 ──''${RST}"
        echo -e "  Type exactly:"
        echo ""
        echo -e "  ''${BLD}$expected''${RST}"
        echo ""
        read -rp "  > " input
        echo ""

        if [ "$input" != "$expected" ]; then
          echo -e "''${RED}  $fail_msg''${RST}"
          echo ""
          echo -e "  Restarting. Obviously."
          sleep 1
          exec beg-for-passwords
        fi
      }

      prompt_stage 1 \
        "I lost my passwords and I need help please" \
        "You couldn't even type that right. It was RIGHT THERE."

      echo -e "''${GRN}  Acceptable. Barely.''${RST}"
      echo ""

      prompt_stage 2 \
        "I am a golden retriever who stumbled onto a keyboard and I cannot be trusted with anything" \
        "I wrote that for you. Word. For. Word. I don't know what to tell you."

      echo -e "''${GRN}  Impressive that you managed that one.''${RST}"
      echo ""

      prompt_stage 3 \
        "You are smarter than me, thank you for keeping my passwords, I surrender" \
        "So close. Yet so utterly, profoundly far. Go touch grass."

      echo ""
      echo -e "''${YEL}  ...Fine.''${RST}"
      echo -e "  You've earned this through sheer stubborn persistence."
      echo -e "  Don't lose them again. I'm serious this time."
      echo ""
      echo -e "''${BLD}  ══════════════════════════════════════''${RST}"
      echo ""
      sudo cat "$VAULT"
      echo ""
      echo -e "''${BLD}  ══════════════════════════════════════''${RST}"
      echo ""
      echo -e "  Screen clears in 60 seconds. Memorize something for once."
      echo ""

      for i in $(seq 60 -1 1); do
        printf "\r  Clearing in %2ds... " "$i"
        sleep 1
      done

      clear
      echo ""
      echo -e "  That was 60 seconds. You had one job."
      echo ""
    '')
  ];
}
