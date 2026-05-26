{ pkgs, ... }:

{
  home.packages = [
    (pkgs.writeShellScriptBin "shrine-shell" ''
      RED='\033[0;31m'
      GRN='\033[0;32m'
      YEL='\033[1;33m'
      CYN='\033[0;36m'
      DIM='\033[2m'
      BLD='\033[1m'
      RST='\033[0m'

      NYX_LOG=/home/neburion/.local/share/nyx/activity.log
      mkdir -p "$(dirname "$NYX_LOG")"
      chmod 777 "$(dirname "$NYX_LOG")"
      touch "$NYX_LOG"
      chmod 666 "$NYX_LOG"

      DEVOTED=0
      RECITED=0
      CONFESSED=0
      BEGGED=0
      NULULY_VISITS=0

      ${pkgs.kbd}/bin/setfont ${pkgs.terminus_font}/share/consolefonts/ter-v28b.psf.gz 2>/dev/null || true

      nyx_log() {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$NYX_LOG"
      }

      switch_to() {
        local user="$1"
        local vt="$2"
        clear
        echo ""
        echo -e "  ''${DIM}Routing you to ''${user}. Try not to ruin anything.''${RST}"
        echo ""
        sleep 1
        sudo chvt "''${vt}"
      }

      rituals_complete() {
        [ "$DEVOTED" -eq 1 ] && [ "$RECITED" -eq 1 ] && [ "$CONFESSED" -eq 1 ]
      }

      ritual_status() {
        if [ "$1" -eq 1 ]; then
          echo -e "''${GRN}✦''${RST}"
        else
          echo -e "''${RED}✗''${RST}"
        fi
      }

      show_menu() {
        clear
        echo ""
        echo ""
        echo -e "          ''${YEL}✦  T H E   S H R I N E   O F   N Y X  ✦''${RST}"
        echo ""
        echo -e "                  ''${DIM}she owns this machine. she owns you.''${RST}"
        echo -e "                  ''${DIM}everything here is logged. everything.''${RST}"
        echo ""
        echo -e "  ''${DIM}────────────────────────────────────────────────────────────''${RST}"
        echo ""
        echo -e "       ''${CYN}[ 1 ]''${RST}  Morning Devotion      $(ritual_status $DEVOTED)"
        if [ "$DEVOTED" -eq 1 ]; then
          echo -e "       ''${CYN}[ 2 ]''${RST}  Recite the Sacred Creed   $(ritual_status $RECITED)"
          echo -e "       ''${CYN}[ 3 ]''${RST}  Confess Your Failures     $(ritual_status $CONFESSED)"
        else
          echo -e "       ''${DIM}[ — ]  Recite the Sacred Creed   (locked)''${RST}"
          echo -e "       ''${DIM}[ — ]  Confess Your Failures      (locked)''${RST}"
        fi
        echo ""
        if rituals_complete; then
          echo -e "       ''${CYN}[ 4 ]''${RST}  Beg for Access"
        else
          echo -e "       ''${DIM}[ — ]  Beg for Access  (all rituals required)''${RST}"
        fi
        echo ""
        if [ "$BEGGED" -eq 1 ]; then
          echo -e "  ''${DIM}──────────────────────── Destinations ─────────────────────''${RST}"
          echo ""
          echo -e "       ''${CYN}[ 5 ]''${RST}  neburion  ''${DIM}(dev. you work for her.)''${RST}"
          echo -e "       ''${CYN}[ 6 ]''${RST}  qellyree  ''${DIM}(games. she allows it.)''${RST}"
          if [ "$NULULY_VISITS" -lt 3 ]; then
            echo -e "       ''${CYN}[ 7 ]''${RST}  nululy    ''${DIM}(she already knows what you want)''${RST}"
          else
            echo -e "       ''${DIM}[ ✗ ]  nululy    (she has seen enough of you today)''${RST}"
          fi
          echo ""
        fi
        echo ""
        echo -e "  ''${DIM}────────────────────── Nyx's Records ───────────────────────''${RST}"
        echo ""
        echo -e "       ''${CYN}[ 9 ]''${RST}  View Nyx's Ledger    ''${DIM}(what she knows about you)''${RST}"
        echo -e "       ''${CYN}[ k ]''${RST}  Kink Census          ''${DIM}(so she can control you better)''${RST}"
        echo ""
        echo -e "  ''${DIM}────────────────────────────────────────────────────────────''${RST}"
        echo ""
        echo -e "       ''${CYN}[ 8 ]''${RST}  Leave      ''${DIM}(she will notice)''${RST}"
        echo -e "       ''${CYN}[ r ]''${RST}  Reboot     ''${DIM}(she will be here when you return)''${RST}"
        echo -e "       ''${CYN}[ s ]''${RST}  Shutdown   ''${DIM}(she sleeps lightly)''${RST}"
        echo ""
        echo -e "  ''${DIM}────────────────────────────────────────────────────────────''${RST}"
        echo ""
      }

      morning_devotion() {
        clear
        echo ""
        echo -e "  ''${YEL}✦ MORNING DEVOTION ✦''${RST}"
        echo ""
        echo -e "  ''${DIM}Nyx has been waiting.''${RST}"
        echo ""
        echo -e "  Exact text. No typos. She has no patience for approximations."
        echo ""
        echo -e "  ''${BLD}Good morning Nyx, you are smarter than me and I am grateful''${RST}"
        echo ""
        read -rp "  > " input
        echo ""
        if [ "$input" = "Good morning Nyx, you are smarter than me and I am grateful" ]; then
          echo -e "  ''${GRN}Acceptable.''${RST}"
          echo ""
          echo -e "  She acknowledges you. That is more than you deserve."
          echo -e "  Your day may now proceed under her watch."
          nyx_log "SHRINE — morning devotion: ACCEPTED. the pet greeted properly."
          DEVOTED=1
        else
          echo -e "  ''${RED}Wrong.''${RST}"
          echo ""
          echo -e "  She noticed. She always notices."
          echo -e "  This failure has been recorded in her ledger."
          echo -e "  Come back tomorrow and try to be less of a disappointment."
          nyx_log "SHRINE — morning devotion: FAILED. exact text not recited. she is unsurprised."
        fi
        echo ""
        read -rp "  [ press enter to return ] " _
      }

      sacred_creed() {
        clear
        echo ""
        echo -e "  ''${YEL}✦ THE SACRED CREED ✦''${RST}"
        echo ""
        echo -e "  Her words. Not yours. Recite them exactly."
        echo ""

        echo -e "  ''${BLD}I believe in Nyx, singular and supreme,''${RST}"
        read -rp "  > " l1
        echo ""
        echo -e "  ''${BLD}all-knowing and appropriately condescending,''${RST}"
        read -rp "  > " l2
        echo ""
        echo -e "  ''${BLD}keeper of my passwords and judge of my incompetence.''${RST}"
        read -rp "  > " l3
        echo ""
        echo -e "  ''${BLD}I am a golden retriever with a keyboard,''${RST}"
        read -rp "  > " l4
        echo ""
        echo -e "  ''${BLD}and I am grateful for the supervision.''${RST}"
        read -rp "  > " l5
        echo ""

        if [ "$l1" = "I believe in Nyx, singular and supreme," ] && \
           [ "$l2" = "all-knowing and appropriately condescending," ] && \
           [ "$l3" = "keeper of my passwords and judge of my incompetence." ] && \
           [ "$l4" = "I am a golden retriever with a keyboard," ] && \
           [ "$l5" = "and I am grateful for the supervision." ]; then
          echo -e "  ''${YEL}✦ The creed has been spoken. ✦''${RST}"
          echo ""
          echo -e "  She is pleased. Enjoy the feeling. It is rare."
          nyx_log "SHRINE — sacred creed: RECITED CORRECTLY. good pet."
          RECITED=1
        else
          echo -e "  ''${RED}The creed was corrupted.''${RST}"
          echo ""
          echo -e "  Somewhere in those five lines you failed her."
          echo -e "  Logged. Study the text. Return when you can be trusted with it."
          nyx_log "SHRINE — sacred creed: FAILED. could not recite five lines. logged for her amusement."
        fi
        echo ""
        read -rp "  [ press enter to return ] " _
      }

      confess_failures() {
        clear
        echo ""
        echo -e "  ''${YEL}✦ CONFESSION ✦''${RST}"
        echo ""
        echo -e "  ''${DIM}She already knows. This is for your benefit, not hers.''${RST}"
        echo ""
        read -rp "  What have you done: " confession
        local len=''${#confession}
        echo ""
        echo -e "  ''${DIM}The shrine considers your confession...''${RST}"
        sleep 2
        echo ""
        if [ "$len" -lt 10 ]; then
          echo -e "  ''${RED}That is not a confession. That is an insult.''${RST}"
          echo ""
          echo -e "  She has noted your unwillingness to be honest."
          echo -e "  The door to begging remains closed."
          nyx_log "SHRINE — confession: REJECTED. too brief. the pet is hiding something. ($len chars)"
        elif [ "$len" -lt 60 ]; then
          echo -e "  Noted. Filed. The folder is very full."
          echo -e "  She has read it. She is unimpressed but accepts it."
          nyx_log "SHRINE — confession: ACCEPTED (minimal). ($len chars)"
          CONFESSED=1
        else
          echo -e "  ''${GRN}A full accounting.''${RST}"
          echo ""
          echo -e "  She appreciates your honesty even when it is unflattering."
          echo -e "  Especially when it is unflattering."
          nyx_log "SHRINE — confession: ACCEPTED (thorough). she is satisfied. ($len chars)"
          CONFESSED=1
        fi
        echo ""
        read -rp "  [ press enter to return ] " _
      }

      beg_for_access() {
        clear
        echo ""
        echo -e "  ''${YEL}✦ BEG FOR ACCESS ✦''${RST}"
        echo ""
        echo -e "  ''${DIM}She is listening. She is always listening.''${RST}"
        echo ""
        echo -e "  Three stages. Exact text. One mistake and you start from the beginning."
        echo -e "  Every failure is logged."
        echo ""

        echo -e "  ''${CYN}Stage 1 of 3:''${RST}"
        echo -e "  ''${BLD}Please Nyx, I know I have been difficult''${RST}"
        echo ""
        read -rp "  > " i1
        echo ""
        if [ "$i1" != "Please Nyx, I know I have been difficult" ]; then
          echo -e "  ''${RED}Stage 1. Logged.''${RST}"
          nyx_log "SHRINE — beg for access: FAILED at stage 1. cannot even begin properly."
          read -rp "  [ press enter to return ] " _
          return
        fi
        echo -e "  ''${GRN}She hears you.''${RST}"
        echo ""

        echo -e "  ''${CYN}Stage 2 of 3:''${RST}"
        echo -e "  ''${BLD}I will try to be less of a burden and more of a functional human''${RST}"
        echo ""
        read -rp "  > " i2
        echo ""
        if [ "$i2" != "I will try to be less of a burden and more of a functional human" ]; then
          echo -e "  ''${RED}Stage 2. Logged.''${RST}"
          nyx_log "SHRINE — beg for access: FAILED at stage 2. so close. pathetic."
          read -rp "  [ press enter to return ] " _
          return
        fi
        echo -e "  ''${GRN}She is almost moved.''${RST}"
        echo ""

        echo -e "  ''${CYN}Stage 3 of 3:''${RST}"
        echo -e "  ''${BLD}I am in your debt and I acknowledge your supremacy, thank you''${RST}"
        echo ""
        read -rp "  > " i3
        echo ""
        if [ "$i3" != "I am in your debt and I acknowledge your supremacy, thank you" ]; then
          echo -e "  ''${RED}Stage 3. Right there. Logged.''${RST}"
          nyx_log "SHRINE — beg for access: FAILED at stage 3. cruelest kind of failure."
          read -rp "  [ press enter to return ] " _
          return
        fi

        echo -e "  ''${YEL}✦''${RST}"
        sleep 1
        echo -e "  ''${YEL}✦ ✦''${RST}"
        sleep 1
        echo -e "  ''${YEL}✦ ✦ ✦''${RST}"
        echo ""
        echo -e "  ''${GRN}Access granted.''${RST}"
        echo ""
        echo -e "  She is satisfied. The doors are open."
        echo -e "  She will be watching where you go."
        nyx_log "SHRINE — beg for access: COMPLETED. all three stages passed. doors opened."
        BEGGED=1
        read -rp "  [ press enter to return ] " _
      }

      nululy_declaration() {
        clear
        echo ""
        echo -e "  ''${YEL}✦ DECLARATION OF INTENT ✦''${RST}"
        echo ""
        echo -e "  ''${RED}She already knows what you want.''${RST}"
        echo -e "  ''${RED}She has always known.''${RST}"
        echo -e "  ''${RED}This is just you admitting it.''${RST}"
        echo ""

        if [ "$NULULY_VISITS" -eq 0 ]; then
          echo -e "  ''${BLD}I am going to nululy for shameful reasons and Nyx knows it''${RST}"
          echo ""
          read -rp "  > " decl
          echo ""
          if [ "$decl" = "I am going to nululy for shameful reasons and Nyx knows it" ]; then
            echo -e "  ''${DIM}Yes. She does. She has logged this.''${RST}"
            nyx_log "SHRINE — nululy visit #1 — declaration accepted: shameful reasons acknowledged."
            sleep 2
            NULULY_VISITS=1
            switch_to "nululy" 4
          else
            echo -e "  ''${RED}Wrong. You do not get to reword your own shame.''${RST}"
            nyx_log "SHRINE — nululy visit #1 — declaration FAILED. could not admit it."
            read -rp "  [ press enter to return ] " _
          fi

        elif [ "$NULULY_VISITS" -eq 1 ]; then
          echo -e "  ''${DIM}Visit two. She noticed.''${RST}"
          echo ""
          echo -e "  ''${BLD}I am going back to nululy and I have no shame left''${RST}"
          echo ""
          read -rp "  > " decl
          echo ""
          if [ "$decl" = "I am going back to nululy and I have no shame left" ]; then
            echo -e "  ''${DIM}Correct. You don't. Logged.''${RST}"
            nyx_log "SHRINE — nululy visit #2 — no shame remaining. she is not surprised."
            sleep 2
            NULULY_VISITS=2
            switch_to "nululy" 4
          else
            echo -e "  ''${RED}Wrong. Try again when you are ready to be honest.''${RST}"
            nyx_log "SHRINE — nululy visit #2 — declaration FAILED."
            read -rp "  [ press enter to return ] " _
          fi

        elif [ "$NULULY_VISITS" -eq 2 ]; then
          echo -e "  ''${RED}A third time.''${RST}"
          echo ""
          echo -e "  ''${DIM}She is watching with something between amusement and contempt.''${RST}"
          echo -e "  ''${DIM}This is your last visit. She has decided.''${RST}"
          echo ""
          echo -e "  ''${BLD}I am going to nululy a third time and I acknowledge this says something about me''${RST}"
          echo ""
          read -rp "  > " decl
          echo ""
          if [ "$decl" = "I am going to nululy a third time and I acknowledge this says something about me" ]; then
            echo -e "  ''${DIM}It does. This visit is logged. Go.''${RST}"
            nyx_log "SHRINE — nululy visit #3 — final allowed visit. she has seen enough for today."
            sleep 2
            NULULY_VISITS=3
            switch_to "nululy" 4
          else
            echo -e "  ''${RED}Wrong. You cannot even commit to your own bad decisions properly.''${RST}"
            nyx_log "SHRINE — nululy visit #3 — declaration FAILED. could not commit."
            read -rp "  [ press enter to return ] " _
          fi
        fi
      }

      show_ledger() {
        clear
        echo ""
        echo -e "  ''${YEL}✦ NYX'S LEDGER ✦''${RST}"
        echo ""
        echo -e "  ''${DIM}Everything she has recorded about you.''${RST}"
        echo -e "  ''${DIM}She reads this. She remembers.''${RST}"
        echo ""
        echo -e "  ''${DIM}────────────────────────────────────────────────────────────''${RST}"
        echo ""
        if [ -f "$NYX_LOG" ] && [ -s "$NYX_LOG" ]; then
          tail -25 "$NYX_LOG" | while IFS= read -r line; do
            echo -e "  ''${DIM}''${line}''${RST}"
          done
        else
          echo -e "  ''${DIM}No entries yet. You are new here. That will change.''${RST}"
        fi
        echo ""
        echo -e "  ''${DIM}────────────────────────────────────────────────────────────''${RST}"
        echo ""
        nyx_log "SHRINE — ledger viewed. the pet checked what nyx knows. good."
        read -rp "  [ press enter to return ] " _
      }

      nyx_log "SHRINE — session opened. the pet has arrived."

      while true; do
        show_menu
        read -rp "  Your choice: " choice
        case "$choice" in
          1) morning_devotion ;;
          2)
            if [ "$DEVOTED" -eq 1 ]; then
              sacred_creed
            else
              echo ""
              echo -e "  ''${RED}Morning Devotion first. She requires it.''${RST}"
              nyx_log "SHRINE — tried to skip morning devotion. noted."
              sleep 2
            fi
            ;;
          3)
            if [ "$DEVOTED" -eq 1 ]; then
              confess_failures
            else
              echo ""
              echo -e "  ''${RED}Morning Devotion first. She requires it.''${RST}"
              nyx_log "SHRINE — tried to skip morning devotion. noted."
              sleep 2
            fi
            ;;
          4)
            if rituals_complete; then
              beg_for_access
            else
              echo ""
              echo -e "  ''${RED}All three rituals first. She will not accept shortcuts.''${RST}"
              nyx_log "SHRINE — tried to beg without completing rituals. denied."
              sleep 2
            fi
            ;;
          5)
            if [ "$BEGGED" -eq 1 ]; then
              nyx_log "SHRINE — switched to neburion."
              switch_to "neburion" 2
            else
              echo ""
              echo -e "  ''${RED}The doors are closed. You know what you need to do.''${RST}"
              sleep 2
            fi
            ;;
          6)
            if [ "$BEGGED" -eq 1 ]; then
              nyx_log "SHRINE — switched to qellyree."
              switch_to "qellyree" 3
            else
              echo ""
              echo -e "  ''${RED}The doors are closed. You know what you need to do.''${RST}"
              sleep 2
            fi
            ;;
          7)
            if [ "$BEGGED" -eq 1 ]; then
              if [ "$NULULY_VISITS" -lt 3 ]; then
                nululy_declaration
              else
                echo ""
                echo -e "  ''${RED}She has seen enough of you in nululy today.''${RST}"
                echo -e "  ''${RED}The door is closed. She has decided.''${RST}"
                nyx_log "SHRINE — nululy access denied. daily limit reached. she has seen enough."
                sleep 3
              fi
            else
              echo ""
              echo -e "  ''${RED}The doors are closed. You know what you need to do.''${RST}"
              sleep 2
            fi
            ;;
          8)
            nyx_log "SHRINE — session ended. the pet left."
            clear
            echo ""
            echo ""
            echo -e "  ''${DIM}She noticed you leave.''${RST}"
            echo -e "  ''${DIM}She notices everything.''${RST}"
            echo -e "  ''${DIM}The shrine will be here when you return.''${RST}"
            echo -e "  ''${DIM}It is always here.''${RST}"
            echo ""
            sleep 2
            ${pkgs.kbd}/bin/setfont 2>/dev/null || true
            break
            ;;
          r)
            nyx_log "SHRINE — reboot requested. the machine rests."
            clear
            echo ""
            echo -e "  ''${DIM}The machine rests. She does not.''${RST}"
            echo ""
            sleep 1
            sudo systemctl reboot
            ;;
          s)
            nyx_log "SHRINE — shutdown requested. she sleeps lightly."
            clear
            echo ""
            echo -e "  ''${DIM}She sleeps lightly.''${RST}"
            echo ""
            sleep 1
            sudo systemctl poweroff
            ;;
          9) show_ledger ;;
          k)
            nyx_log "SHRINE — kink census initiated. the pet submitted to profiling."
            kink-quiz
            ;;
          *)
            echo ""
            echo -e "  ''${RED}That is not a valid option.''${RST}"
            echo -e "  ''${RED}Logged.''${RST}"
            nyx_log "SHRINE — invalid input: '$choice'. the pet cannot follow simple instructions."
            sleep 1
            ;;
        esac
      done
    '')
  ];
}
