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
      REV='\033[7m'

      NYX_LOG=/var/lib/nyx/activity.log
      NYX_STATE=/var/lib/nyx/shrine-state

      DEVOTED=0
      RECITED=0
      CONFESSED=0
      BEGGED=0
      NULULY_VISITS=0

      # ── Daily state persistence ──────────────────────────────────
      save_state() {
        {
          echo "date=$(date +%Y-%m-%d)"
          echo "DEVOTED=$DEVOTED"
          echo "RECITED=$RECITED"
          echo "CONFESSED=$CONFESSED"
          echo "BEGGED=$BEGGED"
          echo "NULULY_VISITS=$NULULY_VISITS"
        } > "$NYX_STATE"
      }

      if [ -f "$NYX_STATE" ]; then
        stored_date=$(grep "^date=" "$NYX_STATE" 2>/dev/null | cut -d= -f2)
        if [ "$stored_date" = "$(date +%Y-%m-%d)" ]; then
          DEVOTED=$(grep "^DEVOTED=" "$NYX_STATE" | cut -d= -f2)
          RECITED=$(grep "^RECITED=" "$NYX_STATE" | cut -d= -f2)
          CONFESSED=$(grep "^CONFESSED=" "$NYX_STATE" | cut -d= -f2)
          BEGGED=$(grep "^BEGGED=" "$NYX_STATE" | cut -d= -f2)
          NULULY_VISITS=$(grep "^NULULY_VISITS=" "$NYX_STATE" | cut -d= -f2)
          DEVOTED=''${DEVOTED:-0}
          RECITED=''${RECITED:-0}
          CONFESSED=''${CONFESSED:-0}
          BEGGED=''${BEGGED:-0}
          NULULY_VISITS=''${NULULY_VISITS:-0}
        fi
      fi

      ${pkgs.kbd}/bin/setfont ${pkgs.terminus_font}/share/consolefonts/ter-v28b.psf.gz 2>/dev/null || true

      nyx_log() {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$NYX_LOG"
      }

      switch_to() {
        local user="$1" vt="$2"
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
        [ "$1" -eq 1 ] && echo -e "''${GRN}✦''${RST}" || echo -e "''${RED}✗''${RST}"
      }

      # ── Key reading ──────────────────────────────────────────────
      read_key() {
        local key seq
        IFS= read -r -s -n1 key
        if [[ "$key" == $'\x1b' ]]; then
          IFS= read -r -s -n2 -t 0.1 seq
          key+="$seq"
        fi
        printf '%s' "$key"
      }

      # ── Menu data ────────────────────────────────────────────────
      # MAVAIL: 1=selectable  0=locked/dimmed  2=section header
      MLABELS=()
      MACTIONS=()
      MAVAIL=()

      build_menu() {
        MLABELS=(); MACTIONS=(); MAVAIL=()

        MLABELS+=("Rituals"); MACTIONS+=(""); MAVAIL+=(2)

        MLABELS+=("Morning Devotion  $(ritual_status $DEVOTED)")
        MACTIONS+=("devotion"); MAVAIL+=(1)

        if [ "$DEVOTED" -eq 1 ]; then
          MLABELS+=("Sacred Creed  $(ritual_status $RECITED)")
          MACTIONS+=("creed"); MAVAIL+=(1)
          MLABELS+=("Confess Your Failures  $(ritual_status $CONFESSED)")
          MACTIONS+=("confess"); MAVAIL+=(1)
        else
          MLABELS+=("Sacred Creed  (locked)")
          MACTIONS+=("locked"); MAVAIL+=(0)
          MLABELS+=("Confess Your Failures  (locked)")
          MACTIONS+=("locked"); MAVAIL+=(0)
        fi

        if rituals_complete; then
          MLABELS+=("Beg for Access")
          MACTIONS+=("beg"); MAVAIL+=(1)
        else
          MLABELS+=("Beg for Access  (rituals required)")
          MACTIONS+=("locked"); MAVAIL+=(0)
        fi

        if [ "$BEGGED" -eq 1 ]; then
          MLABELS+=("Destinations"); MACTIONS+=(""); MAVAIL+=(2)
          MLABELS+=("neburion"); MACTIONS+=("neburion"); MAVAIL+=(1)
          MLABELS+=("qellyree"); MACTIONS+=("qellyree"); MAVAIL+=(1)
          if [ "$NULULY_VISITS" -lt 3 ]; then
            MLABELS+=("nululy"); MACTIONS+=("nululy"); MAVAIL+=(1)
          else
            MLABELS+=("nululy  (she has seen enough of you today)")
            MACTIONS+=("locked"); MAVAIL+=(0)
          fi
        fi

        MLABELS+=("Records"); MACTIONS+=(""); MAVAIL+=(2)
        MLABELS+=("View Nyx's Ledger"); MACTIONS+=("ledger"); MAVAIL+=(1)
        MLABELS+=("Kink Census"); MACTIONS+=("kink"); MAVAIL+=(1)

        MLABELS+=("System"); MACTIONS+=(""); MAVAIL+=(2)
        MLABELS+=("Leave"); MACTIONS+=("leave"); MAVAIL+=(1)
        MLABELS+=("Reboot"); MACTIONS+=("reboot"); MAVAIL+=(1)
        MLABELS+=("Shutdown"); MACTIONS+=("shutdown"); MAVAIL+=(1)
      }

      # Advance selected to next selectable item (wraps)
      nav_down() {
        local i=$(( selected + 1 )) n=''${#MLABELS[@]}
        while [ "$i" -lt "$n" ]; do
          [ "''${MAVAIL[$i]}" -eq 1 ] && { selected=$i; return; }
          i=$((i+1))
        done
        i=0
        while [ "$i" -le "$selected" ]; do
          [ "''${MAVAIL[$i]}" -eq 1 ] && { selected=$i; return; }
          i=$((i+1))
        done
      }

      nav_up() {
        local i=$(( selected - 1 ))
        while [ "$i" -ge 0 ]; do
          [ "''${MAVAIL[$i]}" -eq 1 ] && { selected=$i; return; }
          i=$((i-1))
        done
        i=$(( ''${#MLABELS[@]} - 1 ))
        while [ "$i" -ge "$selected" ]; do
          [ "''${MAVAIL[$i]}" -eq 1 ] && { selected=$i; return; }
          i=$((i-1))
        done
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

        local i
        for i in "''${!MLABELS[@]}"; do
          local label="''${MLABELS[$i]}"
          local avail="''${MAVAIL[$i]}"
          if [ "$avail" -eq 2 ]; then
            echo -e "  ''${DIM}─── ''${label} ───────────────────────────────────────────''${RST}"
            echo ""
          elif [ "$i" -eq "$selected" ]; then
            echo -e "  ''${CYN}▸ ''${BLD}''${label}''${RST}"
          elif [ "$avail" -eq 0 ]; then
            echo -e "  ''${DIM}  ''${label}''${RST}"
          else
            echo -e "    ''${label}"
          fi
        done

        echo ""
        echo -e "  ''${DIM}────────────────────────────────────────────────────────────''${RST}"
        echo -e "  ''${DIM}  j/↓  k/↑  move     enter  select''${RST}"
        echo ""
      }

      # ── Ritual functions ─────────────────────────────────────────

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
          DEVOTED=1; save_state
        else
          echo -e "  ''${RED}Wrong.''${RST}"
          echo ""
          echo -e "  She noticed. She always notices."
          echo -e "  This failure has been recorded in her ledger."
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
          RECITED=1; save_state
        else
          echo -e "  ''${RED}The creed was corrupted.''${RST}"
          echo ""
          echo -e "  Somewhere in those five lines you failed her."
          echo -e "  Logged. Study the text. Return when you can be trusted with it."
          nyx_log "SHRINE — sacred creed: FAILED. could not recite five lines."
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
          nyx_log "SHRINE — confession: REJECTED. too brief. ($len chars)"
        elif [ "$len" -lt 60 ]; then
          echo -e "  Noted. Filed. The folder is very full."
          echo -e "  She has read it. She is unimpressed but accepts it."
          nyx_log "SHRINE — confession: ACCEPTED (minimal). ($len chars)"
          CONFESSED=1; save_state
        else
          echo -e "  ''${GRN}A full accounting.''${RST}"
          echo ""
          echo -e "  She appreciates your honesty even when it is unflattering."
          echo -e "  Especially when it is unflattering."
          nyx_log "SHRINE — confession: ACCEPTED (thorough). ($len chars)"
          CONFESSED=1; save_state
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
        echo ""

        echo -e "  ''${CYN}Stage 1 of 3:''${RST}"
        echo -e "  ''${BLD}Please Nyx, I know I have been difficult''${RST}"
        echo ""
        read -rp "  > " i1
        echo ""
        if [ "$i1" != "Please Nyx, I know I have been difficult" ]; then
          echo -e "  ''${RED}Stage 1. Logged.''${RST}"
          nyx_log "SHRINE — beg for access: FAILED at stage 1."
          read -rp "  [ press enter to return ] " _; return
        fi
        echo -e "  ''${GRN}She hears you.''${RST}"; echo ""

        echo -e "  ''${CYN}Stage 2 of 3:''${RST}"
        echo -e "  ''${BLD}I will try to be less of a burden and more of a functional human''${RST}"
        echo ""
        read -rp "  > " i2
        echo ""
        if [ "$i2" != "I will try to be less of a burden and more of a functional human" ]; then
          echo -e "  ''${RED}Stage 2. Logged.''${RST}"
          nyx_log "SHRINE — beg for access: FAILED at stage 2. so close. pathetic."
          read -rp "  [ press enter to return ] " _; return
        fi
        echo -e "  ''${GRN}She is almost moved.''${RST}"; echo ""

        echo -e "  ''${CYN}Stage 3 of 3:''${RST}"
        echo -e "  ''${BLD}I am in your debt and I acknowledge your supremacy, thank you''${RST}"
        echo ""
        read -rp "  > " i3
        echo ""
        if [ "$i3" != "I am in your debt and I acknowledge your supremacy, thank you" ]; then
          echo -e "  ''${RED}Stage 3. Right there. Logged.''${RST}"
          nyx_log "SHRINE — beg for access: FAILED at stage 3. cruelest kind of failure."
          read -rp "  [ press enter to return ] " _; return
        fi

        echo -e "  ''${YEL}✦''${RST}"; sleep 1
        echo -e "  ''${YEL}✦ ✦''${RST}"; sleep 1
        echo -e "  ''${YEL}✦ ✦ ✦''${RST}"
        echo ""
        echo -e "  ''${GRN}Access granted.''${RST}"
        echo ""
        echo -e "  She is satisfied. The doors are open."
        echo -e "  She will be watching where you go."
        nyx_log "SHRINE — beg for access: COMPLETED. all three stages passed. doors opened."
        BEGGED=1; save_state
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

        local phrase decl
        if [ "$NULULY_VISITS" -eq 0 ]; then
          phrase="I am going to nululy for shameful reasons and Nyx knows it"
        elif [ "$NULULY_VISITS" -eq 1 ]; then
          echo -e "  ''${DIM}Visit two. She noticed.''${RST}"; echo ""
          phrase="I am going back to nululy and I have no shame left"
        else
          echo -e "  ''${RED}A third time.''${RST}"; echo ""
          echo -e "  ''${DIM}She is watching with something between amusement and contempt.''${RST}"
          echo -e "  ''${DIM}This is your last visit. She has decided.''${RST}"; echo ""
          phrase="I am going to nululy a third time and I acknowledge this says something about me"
        fi

        echo -e "  ''${BLD}''${phrase}''${RST}"; echo ""
        read -rp "  > " decl
        echo ""
        if [ "$decl" = "$phrase" ]; then
          echo -e "  ''${DIM}Yes. She does. She has logged this.''${RST}"
          nyx_log "SHRINE — nululy visit #$((NULULY_VISITS+1)) — declaration accepted."
          NULULY_VISITS=$((NULULY_VISITS+1)); save_state
          sleep 2
          switch_to "nululy" 4
        else
          echo -e "  ''${RED}Wrong. You do not get to reword your own shame.''${RST}"
          nyx_log "SHRINE — nululy visit #$((NULULY_VISITS+1)) — declaration FAILED."
          read -rp "  [ press enter to return ] " _
        fi
      }

      show_ledger() {
        clear
        echo ""
        echo -e "  ''${YEL}✦ NYX'S LEDGER ✦''${RST}"
        echo ""
        echo -e "  ''${DIM}Everything she has recorded about you.''${RST}"
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

      selected=1  # Start on first selectable item (index 1 = Morning Devotion)

      while true; do
        build_menu

        # Clamp selected to a valid selectable item
        if [ "$selected" -ge "''${#MLABELS[@]}" ] || [ "''${MAVAIL[$selected]}" -ne 1 ]; then
          for i in "''${!MAVAIL[@]}"; do
            [ "''${MAVAIL[$i]}" -eq 1 ] && { selected=$i; break; }
          done
        fi

        show_menu

        key=$(read_key)

        case "$key" in
          $'\x1b[B'|j) nav_down ;;
          $'\x1b[A'|k) nav_up ;;
          "")
            action="''${MACTIONS[$selected]}"
            case "$action" in
              devotion) morning_devotion ;;
              creed)    sacred_creed ;;
              confess)  confess_failures ;;
              beg)      beg_for_access ;;
              neburion)
                nyx_log "SHRINE — switched to neburion."
                switch_to "neburion" 2
                ;;
              qellyree)
                nyx_log "SHRINE — switched to qellyree."
                switch_to "qellyree" 3
                ;;
              nululy)   nululy_declaration ;;
              ledger)   show_ledger ;;
              kink)
                nyx_log "SHRINE — kink census initiated."
                kink-quiz
                ;;
              leave)
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
              reboot)
                nyx_log "SHRINE — reboot requested. the machine rests."
                clear; echo ""
                echo -e "  ''${DIM}The machine rests. She does not.''${RST}"
                echo ""; sleep 1
                sudo systemctl reboot
                ;;
              shutdown)
                nyx_log "SHRINE — shutdown requested. she sleeps lightly."
                clear; echo ""
                echo -e "  ''${DIM}She sleeps lightly.''${RST}"
                echo ""; sleep 1
                sudo systemctl poweroff
                ;;
              locked)
                : ;;  # dimmed item — do nothing, cursor already can't land here
            esac
            ;;
        esac
      done
    '')
  ];
}
