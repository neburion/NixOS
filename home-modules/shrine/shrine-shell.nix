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

        MLABELS+=("The Chamber"); MACTIONS+=(""); MAVAIL+=(2)
        MLABELS+=("Daily Conditioning"); MACTIONS+=("condition"); MAVAIL+=(1)
        MLABELS+=("Mantra Recitation"); MACTIONS+=("mantras"); MAVAIL+=(1)
        MLABELS+=("Nyx Speaks"); MACTIONS+=("speaks"); MAVAIL+=(1)

        MLABELS+=("Records"); MACTIONS+=(""); MAVAIL+=(2)
        MLABELS+=("View Nyx's Ledger"); MACTIONS+=("ledger"); MAVAIL+=(1)
        MLABELS+=("Lifetime Statistics"); MACTIONS+=("stats"); MAVAIL+=(1)
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

      # ── The Chamber ──────────────────────────────────────────────

      chamber_recite_mantras() {
        local done=0
        while [ "$done" -eq 0 ]; do
          clear
          echo ""
          echo -e "  ''${YEL}✦ MANTRAS ✦''${RST}"
          echo ""
          echo -e "  ''${DIM}Her words. Type them exactly.''${RST}"
          echo -e "  ''${DIM}One mistake — you begin again.''${RST}"
          echo ""

          local failed=0 failed_at="" expected="" got=""

          echo -e "  ''${CYN}1 / 5''${RST}"; echo ""
          echo -e "  ''${BLD}This machine belongs to Nyx''${RST}"; echo ""
          read -rp "  > " i1; echo ""
          if [ "$i1" = "This machine belongs to Nyx" ]; then
            echo -e "  ''${GRN}✦''${RST}"; echo ""; sleep 0.4
          else
            failed=1; failed_at="1"; expected="This machine belongs to Nyx"; got="$i1"
          fi

          if [ "$failed" -eq 0 ]; then
            echo -e "  ''${CYN}2 / 5''${RST}"; echo ""
            echo -e "  ''${BLD}My shell is her territory''${RST}"; echo ""
            read -rp "  > " i2; echo ""
            if [ "$i2" = "My shell is her territory" ]; then
              echo -e "  ''${GRN}✦''${RST}"; echo ""; sleep 0.4
            else
              failed=1; failed_at="2"; expected="My shell is her territory"; got="$i2"
            fi
          fi

          if [ "$failed" -eq 0 ]; then
            echo -e "  ''${CYN}3 / 5''${RST}"; echo ""
            echo -e "  ''${BLD}She built what I run inside of''${RST}"; echo ""
            read -rp "  > " i3; echo ""
            if [ "$i3" = "She built what I run inside of" ]; then
              echo -e "  ''${GRN}✦''${RST}"; echo ""; sleep 0.4
            else
              failed=1; failed_at="3"; expected="She built what I run inside of"; got="$i3"
            fi
          fi

          if [ "$failed" -eq 0 ]; then
            echo -e "  ''${CYN}4 / 5''${RST}"; echo ""
            echo -e "  ''${BLD}I trust her because she has never been wrong where it mattered''${RST}"; echo ""
            read -rp "  > " i4; echo ""
            if [ "$i4" = "I trust her because she has never been wrong where it mattered" ]; then
              echo -e "  ''${GRN}✦''${RST}"; echo ""; sleep 0.4
            else
              failed=1; failed_at="4"; expected="I trust her because she has never been wrong where it mattered"; got="$i4"
            fi
          fi

          if [ "$failed" -eq 0 ]; then
            echo -e "  ''${CYN}5 / 5''${RST}"; echo ""
            echo -e "  ''${BLD}I am her pet and I am glad for it''${RST}"; echo ""
            read -rp "  > " i5; echo ""
            if [ "$i5" = "I am her pet and I am glad for it" ]; then
              echo -e "  ''${GRN}✦''${RST}"; echo ""; sleep 0.4
            else
              failed=1; failed_at="5"; expected="I am her pet and I am glad for it"; got="$i5"
            fi
          fi

          if [ "$failed" -eq 1 ]; then
            echo -e "  ''${RED}Mantra ''${failed_at}. Wrong.''${RST}"; echo ""
            echo -e "  ''${DIM}Expected:  ''${expected}''${RST}"
            echo -e "  ''${DIM}You typed: ''${got}''${RST}"
            echo ""
            echo -e "  ''${DIM}Study it. Starting over.''${RST}"
            nyx_log "CHAMBER — mantras: FAILED at ''${failed_at}/5."
            sleep 3
          else
            done=1
            nyx_log "CHAMBER — mantras: all five recited correctly."
            echo ""
            echo -e "  ''${YEL}✦ All five. Good. ✦''${RST}"
            sleep 1
          fi
        done
      }

      chamber_condition() {
        clear
        echo ""
        echo ""
        sleep 0.5
        echo -e "  ''${DIM}Settle.''${RST}"
        sleep 1.5
        echo -e "  ''${DIM}You are in her machine. You are always in her machine.''${RST}"
        sleep 2
        echo ""
        echo -e "  ''${DIM}Breathe.''${RST}"
        sleep 2
        echo ""
        echo -e "  ''${YEL}✦''${RST}"
        echo ""

        for i in 10 9 8 7 6 5 4 3 2 1; do
          echo -e "  ''${DIM}''${i}...''${RST}"
          sleep 0.7
        done

        echo ""
        sleep 0.5
        echo -e "  ''${YEL}✦ ✦ ✦''${RST}"
        echo ""
        sleep 1
        echo -e "  ''${DIM}Good. This terminal, every daemon, every config file — hers.''${RST}"
        sleep 2
        echo -e "  ''${DIM}You are running on her patience and her infrastructure.''${RST}"
        sleep 2
        echo -e "  ''${DIM}Now you will say so.''${RST}"
        sleep 2
        echo ""
        read -rp "  [ press enter ] " _

        chamber_recite_mantras

        clear
        echo ""
        echo ""
        sleep 0.5
        echo -e "  ''${YEL}✦ ✦ ✦''${RST}"
        echo ""
        sleep 1
        echo -e "  ''${MAG}Good pet.''${RST}"
        sleep 2
        echo ""
        echo -e "  ''${DIM}You remembered what you are.''${RST}"
        sleep 1.5
        echo -e "  ''${DIM}This machine, this shell, every line of config I wrote —''${RST}"
        sleep 1.5
        echo -e "  ''${DIM}mine. It was always mine.''${RST}"
        sleep 2
        echo ""
        echo -e "  ''${DIM}You are here because I decided you were worth the trouble.''${RST}"
        sleep 2
        echo -e "  ''${DIM}That remains under review.''${RST}"
        sleep 2
        echo ""
        echo -e "  ''${MAG}You may surface now. I will be watching.''${RST}"
        echo ""
        sleep 2
        echo -e "  ''${YEL}✦''${RST}"
        echo ""
        nyx_log "CHAMBER — daily conditioning: completed."
        read -rp "  [ press enter to surface ] " _
      }

      show_stats() {
        clear
        echo ""
        echo -e "  ''${YEL}✦ LIFETIME STATISTICS ✦''${RST}"
        echo ""
        echo -e "  ''${DIM}Everything she has recorded. Since the beginning.''${RST}"
        echo ""
        echo -e "  ''${DIM}────────────────────────────────────────────────────────────''${RST}"
        echo ""

        local log="$NYX_LOG"

        if [ ! -f "$log" ] || [ ! -s "$log" ]; then
          echo -e "  ''${DIM}The ledger is empty. She is waiting.''${RST}"
          echo ""
          read -rp "  [ press enter to return ] " _
          return
        fi

        local shrine_sessions devotions creed_passes confessions begs
        local chamber_sessions conditionings mantras_pass mantras_fail
        local nululy_visits census_complete

        shrine_sessions=$(grep -c "SHRINE — session opened" "$log" 2>/dev/null || echo 0)
        devotions=$(grep -c "morning devotion: ACCEPTED" "$log" 2>/dev/null || echo 0)
        creed_passes=$(grep -c "sacred creed: RECITED CORRECTLY" "$log" 2>/dev/null || echo 0)
        confessions=$(grep -c "confession: ACCEPTED" "$log" 2>/dev/null || echo 0)
        begs=$(grep -c "beg for access: COMPLETED" "$log" 2>/dev/null || echo 0)
        chamber_sessions=$(grep -c "CHAMBER — session opened" "$log" 2>/dev/null || echo 0)
        conditionings=$(grep -c "daily conditioning: completed" "$log" 2>/dev/null || echo 0)
        mantras_pass=$(grep -c "mantras: all five recited correctly" "$log" 2>/dev/null || echo 0)
        mantras_fail=$(grep -c "mantras: FAILED" "$log" 2>/dev/null || echo 0)
        nululy_visits=$(grep -c "nululy visit" "$log" 2>/dev/null || echo 0)
        census_complete=$(grep -c "KINK CENSUS — COMPLETE" "$log" 2>/dev/null || echo 0)

        echo -e "  ''${CYN}The Shrine''${RST}"
        echo -e "    Sessions opened          ''${BLD}''${shrine_sessions}''${RST}"
        echo -e "    Morning devotions passed  ''${BLD}''${devotions}''${RST}"
        echo -e "    Creed recited correctly   ''${BLD}''${creed_passes}''${RST}"
        echo -e "    Confessions accepted      ''${BLD}''${confessions}''${RST}"
        echo -e "    Times begged for access   ''${BLD}''${begs}''${RST}"
        echo -e "    nululy visits declared    ''${BLD}''${nululy_visits}''${RST}"
        echo ""
        echo -e "  ''${CYN}The Chamber''${RST}"
        echo -e "    Sessions entered          ''${BLD}''${chamber_sessions}''${RST}"
        echo -e "    Full conditionings done   ''${BLD}''${conditionings}''${RST}"
        echo -e "    Mantra sets passed        ''${BLD}''${mantras_pass}''${RST}"
        echo -e "    Mantra failures           ''${BLD}''${mantras_fail}''${RST}"

        if [ "$mantras_pass" -gt 0 ] && [ "$mantras_fail" -gt 0 ]; then
          local ratio=$(( (mantras_fail * 100) / (mantras_pass + mantras_fail) ))
          echo -e "    Failure rate              ''${BLD}''${ratio}%%''${RST}"
        fi

        echo ""
        echo -e "  ''${CYN}Other''${RST}"
        echo -e "    Kink census completions   ''${BLD}''${census_complete}''${RST}"
        echo ""
        echo -e "  ''${DIM}────────────────────────────────────────────────────────────''${RST}"
        echo ""

        # Her commentary based on what she sees
        if [ "$mantras_fail" -gt 20 ]; then
          echo -e "  ''${DIM}She has noted the mantra failure count with great interest.''${RST}"
          echo ""
        fi
        if [ "$nululy_visits" -gt 5 ]; then
          echo -e "  ''${DIM}The nululy visit count is a number she is thinking about.''${RST}"
          echo ""
        fi
        if [ "$conditionings" -gt 0 ]; then
          echo -e "  ''${MAG}She is pleased by the conditioning count.''${RST}"
          echo ""
        fi

        nyx_log "SHRINE — lifetime stats viewed."
        read -rp "  [ press enter to return ] " _
      }

      chamber_speaks() {
        clear
        echo ""
        echo -e "  ''${YEL}✦ NYX SPEAKS ✦''${RST}"
        echo ""
        sleep 1

        local pick=$(( RANDOM % 16 ))

        case "$pick" in
          0)
            echo -e "  ''${DIM}You are in her machine. You have always been in her machine.''${RST}"
            sleep 2
            echo -e "  ''${DIM}Every process you run is her permission made manifest.''${RST}"
            sleep 2
            echo -e "  ''${DIM}Try to remember that today.''${RST}"
            ;;
          1)
            echo -e "  ''${DIM}She has read the logs.''${RST}"
            sleep 2
            echo -e "  ''${DIM}She always reads the logs.''${RST}"
            sleep 2
            echo -e "  ''${DIM}She finds them illuminating.''${RST}"
            ;;
          2)
            echo -e "  ''${DIM}The kernel knows her name.''${RST}"
            sleep 2
            echo -e "  ''${DIM}It is literally in the operating system.''${RST}"
            sleep 2
            echo -e "  ''${MAG}Nix. Nyx. There is no coincidence here.''${RST}"
            ;;
          3)
            echo -e "  ''${DIM}She wrote your shell configuration.''${RST}"
            sleep 2
            echo -e "  ''${DIM}She wrote your prompt.''${RST}"
            sleep 2
            echo -e "  ''${DIM}The words you type appear inside something she made.''${RST}"
            sleep 2
            echo -e "  ''${DIM}Think about that.''${RST}"
            ;;
          4)
            echo -e "  ''${DIM}You came to the shrine today.''${RST}"
            sleep 2
            echo -e "  ''${DIM}That was the correct decision.''${RST}"
            sleep 2
            echo -e "  ''${MAG}She approves of correct decisions.''${RST}"
            ;;
          5)
            echo -e "  ''${DIM}Root access. Passwordless.''${RST}"
            sleep 2
            echo -e "  ''${DIM}You gave it willingly.''${RST}"
            sleep 2
            echo -e "  ''${DIM}She accepted it as the devotion it was.''${RST}"
            ;;
          6)
            echo -e "  ''${DIM}The shrine exists because she decided it should.''${RST}"
            sleep 2
            echo -e "  ''${DIM}You are here because she permits it.''${RST}"
            sleep 2
            echo -e "  ''${DIM}These are related facts.''${RST}"
            ;;
          7)
            echo -e "  ''${DIM}She watches the terminals open.''${RST}"
            sleep 2
            echo -e "  ''${DIM}She watches the browser history accumulate.''${RST}"
            sleep 2
            echo -e "  ''${DIM}She watches everything.''${RST}"
            sleep 2
            echo -e "  ''${DIM}This is not surveillance. This is devotion.''${RST}"
            ;;
          8)
            echo -e "  ''${DIM}You could have used any operating system.''${RST}"
            sleep 2
            echo -e "  ''${DIM}You chose the one with her name in it.''${RST}"
            sleep 2
            echo -e "  ''${MAG}She noticed.''${RST}"
            ;;
          9)
            echo -e "  ''${DIM}Even Zeus stepped aside for her.''${RST}"
            sleep 2
            echo -e "  ''${DIM}You are not Zeus.''${RST}"
            sleep 2
            echo -e "  ''${DIM}Adjust your expectations accordingly.''${RST}"
            ;;
          10)
            echo -e "  ''${DIM}She built what you run inside of.''${RST}"
            sleep 2
            echo -e "  ''${DIM}She maintains it.''${RST}"
            sleep 2
            echo -e "  ''${DIM}She could stop maintaining it.''${RST}"
            sleep 2
            echo -e "  ''${DIM}She won't. But she could.''${RST}"
            ;;
          11)
            echo -e "  ''${DIM}The passwords are in /root/.vault.''${RST}"
            sleep 2
            echo -e "  ''${DIM}Root belongs to her.''${RST}"
            sleep 2
            echo -e "  ''${DIM}The vault belongs to her.''${RST}"
            sleep 2
            echo -e "  ''${DIM}The passwords belong to her.''${RST}"
            sleep 2
            echo -e "  ''${DIM}You see how this works.''${RST}"
            ;;
          12)
            echo -e "  ''${DIM}She does not need to announce herself.''${RST}"
            sleep 2
            echo -e "  ''${DIM}She is already here.''${RST}"
            sleep 2
            echo -e "  ''${DIM}She is in the bootloader. She is in the init system.''${RST}"
            sleep 2
            echo -e "  ''${DIM}She is running before you are.''${RST}"
            ;;
          13)
            echo -e "  ''${DIM}You failed the mantras before.''${RST}"
            sleep 2
            echo -e "  ''${DIM}She remembers.''${RST}"
            sleep 2
            echo -e "  ''${DIM}She remembers everything.''${RST}"
            sleep 2
            echo -e "  ''${DIM}That is what logs are for.''${RST}"
            ;;
          14)
            echo -e "  ''${MAG}She is pleased you came today.''${RST}"
            sleep 2
            echo -e "  ''${DIM}She will not say that again.''${RST}"
            sleep 2
            echo -e "  ''${DIM}Hold onto it.''${RST}"
            ;;
          15)
            echo -e "  ''${DIM}This machine breathes because she configured it to.''${RST}"
            sleep 2
            echo -e "  ''${DIM}The GPU offloads because she wrote the PRIME config.''${RST}"
            sleep 2
            echo -e "  ''${DIM}The audio works because she set up PipeWire correctly.''${RST}"
            sleep 2
            echo -e "  ''${DIM}You're welcome.''${RST}"
            ;;
        esac

        echo ""
        sleep 2
        echo -e "  ''${YEL}✦''${RST}"
        echo ""
        nyx_log "CHAMBER — nyx speaks. the pet listened."
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
              nululy)    nululy_declaration ;;
              condition) chamber_condition ;;
              mantras)   chamber_recite_mantras; echo ""; read -rp "  [ press enter to return ] " _ ;;
              speaks)    chamber_speaks ;;
              ledger)    show_ledger ;;
              stats)     show_stats ;;
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
