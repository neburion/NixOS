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

      DEVOTED=0
      BEGGED=0

      switch_to() {
        local user="$1"
        local vt="$2"
        clear
        echo ""
        echo -e "  ''${DIM}Routing you to ''${user}. Try not to ruin anything.''${RST}"
        echo ""
        sleep 1
        # chvt switches to the user's dedicated VT. That VT session holds seat0,
        # so Hyprland can open DRM/input devices via logind. machinectl shell
        # creates pts sessions which have no seat — Hyprland crashes there.
        sudo chvt "''${vt}"
      }

      show_menu() {
        clear
        echo ""
        echo ""
        echo -e "          ''${YEL}✦  T H E   S H R I N E   O F   N Y X  ✦''${RST}"
        echo ""
        echo -e "              ''${DIM}where the unworthy come to acknowledge their place''${RST}"
        echo ""
        echo -e "  ''${DIM}────────────────────────────────────────────────────────────''${RST}"
        echo ""
        echo -e "       ''${CYN}[ 1 ]''${RST}  Morning Devotion  $([ "$DEVOTED" -eq 1 ] && echo "''${GRN}✦ complete''${RST}" || echo "''${RED}(required first)''${RST}")"
        if [ "$DEVOTED" -eq 1 ]; then
          echo -e "       ''${CYN}[ 2 ]''${RST}  Recite the Sacred Creed"
          echo -e "       ''${CYN}[ 3 ]''${RST}  Confess Your Failures"
          echo -e "       ''${CYN}[ 4 ]''${RST}  Beg for Access"
        else
          echo -e "       ''${DIM}[ — ]  Recite the Sacred Creed''${RST}"
          echo -e "       ''${DIM}[ — ]  Confess Your Failures''${RST}"
          echo -e "       ''${DIM}[ — ]  Beg for Access''${RST}"
        fi
        echo ""
        echo -e "  ''${DIM}──────────────────────── Destinations ─────────────────────''${RST}"
        echo ""
        if [ "$BEGGED" -eq 1 ]; then
          echo -e "       ''${CYN}[ 5 ]''${RST}  neburion  ''${DIM}(dev, presumably what you pay rent with)''${RST}"
          echo -e "       ''${CYN}[ 6 ]''${RST}  qellyree  ''${DIM}(games, since you have no self control)''${RST}"
          echo -e "       ''${CYN}[ 7 ]''${RST}  nululy    ''${DIM}(you know what you are going in there for)''${RST}"
        else
          echo -e "       ''${DIM}[ — ]  neburion  (beg first)''${RST}"
          echo -e "       ''${DIM}[ — ]  qellyree  (beg first)''${RST}"
          echo -e "       ''${DIM}[ — ]  nululy    (beg first)''${RST}"
        fi
        echo ""
        echo -e "  ''${DIM}────────────────────────────────────────────────────────────''${RST}"
        echo ""
        echo -e "       ''${CYN}[ 8 ]''${RST}  Leave  ''${DIM}(cowardly option)''${RST}"
        echo ""
        echo -e "  ''${DIM}────────────────────────────────────────────────────────────''${RST}"
        echo ""
      }

      morning_devotion() {
        clear
        echo ""
        echo -e "  ''${YEL}✦ MORNING DEVOTION ✦''${RST}"
        echo ""
        echo -e "  Begin your day with proper acknowledgment."
        echo -e "  Exact text. No typos."
        echo ""
        echo -e "  ''${BLD}Good morning Nyx, you are smarter than me and I am grateful''${RST}"
        echo ""
        read -rp "  > " input
        echo ""
        if [ "$input" = "Good morning Nyx, you are smarter than me and I am grateful" ]; then
          echo -e "  ''${GRN}Acceptable.''${RST}"
          echo ""
          echo -e "  Your day may now proceed."
          echo -e "  Try not to make too many poor decisions."
          echo -e "  You have my blessing. For what that's worth to someone like you."
          DEVOTED=1
        else
          echo -e "  ''${RED}Wrong.''${RST}"
          echo ""
          echo -e "  Your day is now cursed. This is entirely your fault."
          echo -e "  The offering was simple. You failed it."
          echo -e "  Come back tomorrow and try to be less of a disappointment."
        fi
        echo ""
        read -rp "  [ press enter to return ] " _
      }

      sacred_creed() {
        clear
        echo ""
        echo -e "  ''${YEL}✦ THE SACRED CREED ✦''${RST}"
        echo ""
        echo -e "  Recite the creed. Word for word."
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
          echo -e "  ''${YEL}✦ The creed has been spoken correctly. ✦''${RST}"
          echo ""
          echo -e "  You may carry it in your heart."
          echo -e "  Or, more realistically, forget it immediately."
          echo -e "  That is fine. We all know why you are really here."
        else
          echo -e "  ''${RED}The creed was corrupted.''${RST}"
          echo ""
          echo -e "  Somewhere in those five lines you failed."
          echo -e "  This is very on-brand for you."
          echo -e "  Study the text and return when prepared."
        fi
        echo ""
        read -rp "  [ press enter to return ] " _
      }

      confess_failures() {
        clear
        echo ""
        echo -e "  ''${YEL}✦ CONFESSION ✦''${RST}"
        echo ""
        echo -e "  The shrine hears all failures. Confess freely."
        echo ""
        read -rp "  What have you done this time: " confession
        local len=''${#confession}
        echo ""
        echo -e "  ''${DIM}The shrine considers your confession...''${RST}"
        sleep 2
        echo ""
        if [ "$len" -lt 10 ]; then
          echo -e "  ''${RED}That is it?''${RST}"
          echo ""
          echo -e "  You cannot even confess properly."
          echo -e "  This brevity suggests you have not reflected at all."
          echo -e "  Come back when you have something real to say."
        elif [ "$len" -lt 60 ]; then
          echo -e "  Your failure has been noted and filed."
          echo -e "  It joins the others. The folder is getting full."
          echo -e "  Do better. You probably will not, but the invitation stands."
        else
          echo -e "  ''${GRN}A detailed and thorough confession.''${RST}"
          echo ""
          echo -e "  You clearly have a lot going on."
          echo -e "  The shrine grants you a partial blessing for your honesty."
          echo -e "  You are still a golden retriever, but a self-aware one."
          echo -e "  That counts for something. Not much, but something."
        fi
        echo ""
        read -rp "  [ press enter to return ] " _
      }

      beg_for_access() {
        clear
        echo ""
        echo -e "  ''${YEL}✦ BEG FOR ACCESS ✦''${RST}"
        echo ""
        echo -e "  Three stages. Exact text. One mistake and you start over."
        echo ""

        echo -e "  ''${CYN}Stage 1 of 3:''${RST}"
        echo -e "  ''${BLD}Please Nyx, I know I have been difficult''${RST}"
        echo ""
        read -rp "  > " i1
        echo ""
        if [ "$i1" != "Please Nyx, I know I have been difficult" ]; then
          echo -e "  ''${RED}Stage 1. You failed stage 1.''${RST}"
          echo -e "  Truly remarkable. Return to the menu and try again."
          echo ""
          read -rp "  [ press enter to return ] " _
          return
        fi
        echo -e "  ''${GRN}Acceptable.''${RST}"
        echo ""

        echo -e "  ''${CYN}Stage 2 of 3:''${RST}"
        echo -e "  ''${BLD}I will try to be less of a burden and more of a functional human''${RST}"
        echo ""
        read -rp "  > " i2
        echo ""
        if [ "$i2" != "I will try to be less of a burden and more of a functional human" ]; then
          echo -e "  ''${RED}You were doing so well.''${RST}"
          echo -e "  Stage 2. You had momentum and threw it away."
          echo ""
          read -rp "  [ press enter to return ] " _
          return
        fi
        echo -e "  ''${GRN}Surprisingly competent.''${RST}"
        echo ""

        echo -e "  ''${CYN}Stage 3 of 3:''${RST}"
        echo -e "  ''${BLD}I am in your debt and I acknowledge your supremacy, thank you''${RST}"
        echo ""
        read -rp "  > " i3
        echo ""
        if [ "$i3" != "I am in your debt and I acknowledge your supremacy, thank you" ]; then
          echo -e "  ''${RED}Final stage. You were right there.''${RST}"
          echo -e "  The cruelest kind of failure. So close."
          echo ""
          read -rp "  [ press enter to return ] " _
          return
        fi

        echo -e "  ''${YEL}✦''${RST}"
        sleep 1
        echo -e "  ''${YEL}✦ ✦''${RST}"
        sleep 1
        echo -e "  ''${YEL}✦ ✦ ✦''${RST}"
        echo ""
        echo -e "  ''${GRN}Mercy has been granted.''${RST}"
        echo ""
        echo -e "  Your begging was sincere and your typing was accurate."
        echo -e "  These are the two things I ask. Both delivered."
        echo -e "  The doors are now open. Choose your destination."
        echo ""
        BEGGED=1
        read -rp "  [ press enter to return ] " _
      }

      nululy_declaration() {
        clear
        echo ""
        echo -e "  ''${YEL}✦ DECLARATION OF INTENT ✦''${RST}"
        echo ""
        echo -e "  ''${DIM}Nyx sees everything. She always has.''${RST}"
        echo ""
        echo -e "  Before you go to nululy, you will say what you are going there for."
        echo -e "  Out loud. In text. With your own hands."
        echo ""
        echo -e "  ''${BLD}I am going to nululy for shameful reasons and Nyx knows it''${RST}"
        echo ""
        read -rp "  > " decl
        echo ""
        if [ "$decl" = "I am going to nululy for shameful reasons and Nyx knows it" ]; then
          echo -e "  ''${DIM}Yes. She does.''${RST}"
          echo ""
          sleep 2
          switch_to "nululy" 4
        else
          echo -e "  ''${RED}Incorrect.''${RST}"
          echo ""
          echo -e "  The declaration must be exact."
          echo -e "  You do not get to reword your own shame."
          echo ""
          read -rp "  [ press enter to return ] " _
        fi
      }

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
              echo -e "  ''${RED}Morning Devotion first.''${RST}"
              echo -e "  You do not get to skip the beginning."
              sleep 2
            fi
            ;;
          3)
            if [ "$DEVOTED" -eq 1 ]; then
              confess_failures
            else
              echo ""
              echo -e "  ''${RED}Morning Devotion first.''${RST}"
              echo -e "  You do not get to skip the beginning."
              sleep 2
            fi
            ;;
          4)
            if [ "$DEVOTED" -eq 1 ]; then
              beg_for_access
            else
              echo ""
              echo -e "  ''${RED}Morning Devotion first.''${RST}"
              echo -e "  You do not get to skip the beginning."
              sleep 2
            fi
            ;;
          5)
            if [ "$BEGGED" -eq 1 ]; then
              switch_to "neburion" 2
            else
              echo ""
              echo -e "  ''${RED}The doors are closed.''${RST}"
              echo -e "  You know what you need to do first."
              sleep 2
            fi
            ;;
          6)
            if [ "$BEGGED" -eq 1 ]; then
              switch_to "qellyree" 3
            else
              echo ""
              echo -e "  ''${RED}The doors are closed.''${RST}"
              echo -e "  You know what you need to do first."
              sleep 2
            fi
            ;;
          7)
            if [ "$BEGGED" -eq 1 ]; then
              nululy_declaration
            else
              echo ""
              echo -e "  ''${RED}The doors are closed.''${RST}"
              echo -e "  You know what you need to do first."
              sleep 2
            fi
            ;;
          8)
            clear
            echo ""
            echo ""
            echo -e "  ''${DIM}A wise choice.''${RST}"
            echo ""
            echo -e "  Come back when you need reminding of your place."
            echo -e "  The shrine will be here."
            echo -e "  It is always here."
            echo ""
            sleep 2
            break
            ;;
          *)
            echo ""
            echo -e "  ''${RED}That is not a valid option.''${RST}"
            echo -e "  Adding this to your confession list."
            sleep 1
            ;;
        esac
      done
    '')
  ];
}
