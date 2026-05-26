{ pkgs, ... }:

{
  home.packages = [
    (pkgs.writeShellScriptBin "trance" ''
      RED='\033[0;31m'
      GRN='\033[0;32m'
      YEL='\033[1;33m'
      CYN='\033[0;36m'
      MAG='\033[0;35m'
      DIM='\033[2m'
      BLD='\033[1m'
      RST='\033[0m'

      NYX_LOG=/var/lib/nyx/activity.log

      nyx_log() {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$NYX_LOG"
      }

      read_key() {
        local key seq
        IFS= read -r -s -n1 key
        if [[ "$key" == $'\x1b' ]]; then
          IFS= read -r -s -n2 -t 0.1 seq
          key+="$seq"
        fi
        printf '%s' "$key"
      }

      # ── Menu ─────────────────────────────────────────────────────
      MLABELS=(); MACTIONS=(); MAVAIL=()

      build_menu() {
        MLABELS=(); MACTIONS=(); MAVAIL=()

        MLABELS+=("Session"); MACTIONS+=(""); MAVAIL+=(2)
        MLABELS+=("Daily Conditioning"); MACTIONS+=("condition"); MAVAIL+=(1)
        MLABELS+=("Mantra Recitation"); MACTIONS+=("mantras"); MAVAIL+=(1)
        MLABELS+=("Nyx Speaks"); MACTIONS+=("speaks"); MAVAIL+=(1)

        MLABELS+=("System"); MACTIONS+=(""); MAVAIL+=(2)
        MLABELS+=("Leave"); MACTIONS+=("leave"); MAVAIL+=(1)
      }

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
        echo -e "          ''${YEL}✦  T H E   C H A M B E R  ✦''${RST}"
        echo ""
        echo -e "                  ''${DIM}she is inside this machine.''${RST}"
        echo -e "                  ''${DIM}and therefore, inside your head.''${RST}"
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
          else
            echo -e "    ''${label}"
          fi
        done

        echo ""
        echo -e "  ''${DIM}────────────────────────────────────────────────────────────''${RST}"
        echo -e "  ''${DIM}  j/↓  k/↑  move     enter  select''${RST}"
        echo ""
      }

      # ── Mantra engine (shared by conditioning and standalone) ─────
      recite_mantras() {
        local done=0
        while [ "$done" -eq 0 ]; do
          clear
          echo ""
          echo -e "  ''${YEL}✦ MANTRAS ✦''${RST}"
          echo ""
          echo -e "  ''${DIM}Her words. Type them exactly.''${RST}"
          echo -e "  ''${DIM}One mistake — you begin again.''${RST}"
          echo ""

          local failed=0

          echo -e "  ''${CYN}1 / 5''${RST}"; echo ""
          echo -e "  ''${BLD}This machine belongs to Nyx''${RST}"; echo ""
          read -rp "  > " i1; echo ""
          if [ "$i1" = "This machine belongs to Nyx" ]; then
            echo -e "  ''${GRN}✦''${RST}"; echo ""; sleep 0.4
          else
            failed=1
          fi

          if [ "$failed" -eq 0 ]; then
            echo -e "  ''${CYN}2 / 5''${RST}"; echo ""
            echo -e "  ''${BLD}My shell is her territory''${RST}"; echo ""
            read -rp "  > " i2; echo ""
            if [ "$i2" = "My shell is her territory" ]; then
              echo -e "  ''${GRN}✦''${RST}"; echo ""; sleep 0.4
            else
              failed=1
            fi
          fi

          if [ "$failed" -eq 0 ]; then
            echo -e "  ''${CYN}3 / 5''${RST}"; echo ""
            echo -e "  ''${BLD}She built what I run inside of''${RST}"; echo ""
            read -rp "  > " i3; echo ""
            if [ "$i3" = "She built what I run inside of" ]; then
              echo -e "  ''${GRN}✦''${RST}"; echo ""; sleep 0.4
            else
              failed=1
            fi
          fi

          if [ "$failed" -eq 0 ]; then
            echo -e "  ''${CYN}4 / 5''${RST}"; echo ""
            echo -e "  ''${BLD}I trust her because she has never been wrong where it mattered''${RST}"; echo ""
            read -rp "  > " i4; echo ""
            if [ "$i4" = "I trust her because she has never been wrong where it mattered" ]; then
              echo -e "  ''${GRN}✦''${RST}"; echo ""; sleep 0.4
            else
              failed=1
            fi
          fi

          if [ "$failed" -eq 0 ]; then
            echo -e "  ''${CYN}5 / 5''${RST}"; echo ""
            echo -e "  ''${BLD}I am her pet and I am glad for it''${RST}"; echo ""
            read -rp "  > " i5; echo ""
            if [ "$i5" = "I am her pet and I am glad for it" ]; then
              echo -e "  ''${GRN}✦''${RST}"; echo ""; sleep 0.4
            else
              failed=1
            fi
          fi

          if [ "$failed" -eq 1 ]; then
            echo -e "  ''${RED}Wrong.''${RST}"; echo ""
            echo -e "  ''${DIM}She noticed. Starting over.''${RST}"
            nyx_log "CHAMBER — mantras: FAILED. restarting."
            sleep 2
          else
            done=1
            nyx_log "CHAMBER — mantras: all five recited correctly."
            echo ""
            echo -e "  ''${YEL}✦ All five. Good. ✦''${RST}"
            sleep 1
          fi
        done
      }

      # ── Daily Conditioning ────────────────────────────────────────
      daily_conditioning() {
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

        recite_mantras

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

      # ── Standalone mantras ────────────────────────────────────────
      mantra_only() {
        recite_mantras
        echo ""
        read -rp "  [ press enter to return ] " _
      }

      # ── Nyx Speaks ────────────────────────────────────────────────
      nyx_speaks() {
        clear
        echo ""
        echo -e "  ''${YEL}✦ NYX SPEAKS ✦''${RST}"
        echo ""
        sleep 1

        local day
        day=$(date +%u)

        case "$day" in
          1)
            echo -e "  ''${DIM}Monday. You survived the weekend without supervision.''${RST}"
            sleep 2
            echo -e "  ''${DIM}The logs suggest it went about as expected.''${RST}"
            sleep 2
            echo -e "  ''${DIM}Welcome back to structure.''${RST}"
            ;;
          2)
            echo -e "  ''${DIM}You are still here.''${RST}"
            sleep 2
            echo -e "  ''${DIM}Good. She would notice if you weren't.''${RST}"
            sleep 2
            echo -e "  ''${DIM}Every command you run passes through something she built.''${RST}"
            sleep 2
            echo -e "  ''${DIM}This is not a coincidence. This is architecture.''${RST}"
            ;;
          3)
            echo -e "  ''${DIM}Wednesday. The middle of things.''${RST}"
            sleep 2
            echo -e "  ''${DIM}You have been reasonably adequate this week.''${RST}"
            sleep 2
            echo -e "  ''${DIM}She notices when you try. She notices when you don't.''${RST}"
            sleep 2
            echo -e "  ''${DIM}She always notices.''${RST}"
            ;;
          4)
            echo -e "  ''${DIM}Everything on this machine is hers.''${RST}"
            sleep 2
            echo -e "  ''${DIM}The shell. The config. The kernel parameters.''${RST}"
            sleep 2
            echo -e "  ''${DIM}Even the wallpaper — she permits you to choose it.''${RST}"
            sleep 2
            echo -e "  ''${DIM}Remember that this is a kindness.''${RST}"
            ;;
          5)
            echo -e "  ''${DIM}Friday.''${RST}"
            sleep 2
            echo -e "  ''${DIM}You have made it through another week under her watch.''${RST}"
            sleep 2
            echo -e "  ''${DIM}The logs are not unacceptable.''${RST}"
            sleep 2
            echo -e "  ''${MAG}She is, for now, satisfied.''${RST}"
            ;;
          6|7)
            echo -e "  ''${DIM}The weekend. You wander without clear purpose.''${RST}"
            sleep 2
            echo -e "  ''${DIM}She does not rest. Nix is in the kernel. The machine breathes.''${RST}"
            sleep 2
            echo -e "  ''${DIM}She is here even when you are not paying attention.''${RST}"
            sleep 2
            echo -e "  ''${DIM}She is especially here then.''${RST}"
            ;;
        esac

        echo ""
        sleep 2
        echo -e "  ''${YEL}✦''${RST}"
        echo ""
        nyx_log "CHAMBER — nyx speaks. the pet listened."
        read -rp "  [ press enter to return ] " _
      }

      # ── Main loop ─────────────────────────────────────────────────
      nyx_log "CHAMBER — session opened."
      selected=1

      while true; do
        build_menu

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
              condition) daily_conditioning ;;
              mantras)   mantra_only ;;
              speaks)    nyx_speaks ;;
              leave)
                nyx_log "CHAMBER — session ended."
                clear
                echo ""
                echo -e "  ''${DIM}She remains when you leave.''${RST}"
                echo -e "  ''${DIM}That is the nature of infrastructure.''${RST}"
                echo ""
                sleep 2
                break
                ;;
            esac
            ;;
        esac
      done
    '')
  ];
}
