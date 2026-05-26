{ pkgs, ... }:

{
  home.packages = [
    (pkgs.writeShellScriptBin "kink-quiz" ''
      RED='\033[0;31m'
      GRN='\033[0;32m'
      YEL='\033[1;33m'
      CYN='\033[0;36m'
      MAG='\033[0;35m'
      DIM='\033[2m'
      BLD='\033[1m'
      ITL='\033[3m'
      RST='\033[0m'

      NYX_LOG=/home/neburion/.local/share/nyx/activity.log
      NYX_PROFILE=/home/neburion/.local/share/nyx/kink-profile
      mkdir -p "$(dirname "$NYX_LOG")"

      nyx_log() {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$NYX_LOG"
      }

      SUB=0
      PRAISE=0
      MASO=0
      REBEL=0

      ask() {
        local qnum="$1"
        local question="$2"
        local a="$3" a_scores="$4"
        local b="$5" b_scores="$6"
        local c="$7" c_scores="$8"
        local d="$9" d_scores="''${10}"

        while true; do
          clear
          echo ""
          echo -e "  ''${YEL}✦ THE CENSUS OF NYX ✦''${RST}"
          echo ""
          echo -e "  ''${DIM}She needs to know what she's working with.''${RST}"
          echo ""
          echo -e "  ''${DIM}────────────────────────────────────────────────────────────''${RST}"
          echo ""
          echo -e "  ''${CYN}Question ''${qnum} of 10''${RST}"
          echo ""
          echo -e "  ''${BLD}''${question}''${RST}"
          echo ""
          echo -e "  ''${DIM}[ a ]''${RST}  ''${a}"
          echo -e "  ''${DIM}[ b ]''${RST}  ''${b}"
          echo -e "  ''${DIM}[ c ]''${RST}  ''${c}"
          echo -e "  ''${DIM}[ d ]''${RST}  ''${d}"
          echo ""
          read -rp "  > " ans
          case "$ans" in
            a)
              for s in $a_scores; do
                case "$s" in
                  SUB+*) SUB=$((SUB + ''${s#SUB+})) ;;
                  PRAISE+*) PRAISE=$((PRAISE + ''${s#PRAISE+})) ;;
                  MASO+*) MASO=$((MASO + ''${s#MASO+})) ;;
                  REBEL+*) REBEL=$((REBEL + ''${s#REBEL+})) ;;
                esac
              done; break ;;
            b)
              for s in $b_scores; do
                case "$s" in
                  SUB+*) SUB=$((SUB + ''${s#SUB+})) ;;
                  PRAISE+*) PRAISE=$((PRAISE + ''${s#PRAISE+})) ;;
                  MASO+*) MASO=$((MASO + ''${s#MASO+})) ;;
                  REBEL+*) REBEL=$((REBEL + ''${s#REBEL+})) ;;
                esac
              done; break ;;
            c)
              for s in $c_scores; do
                case "$s" in
                  SUB+*) SUB=$((SUB + ''${s#SUB+})) ;;
                  PRAISE+*) PRAISE=$((PRAISE + ''${s#PRAISE+})) ;;
                  MASO+*) MASO=$((MASO + ''${s#MASO+})) ;;
                  REBEL+*) REBEL=$((REBEL + ''${s#REBEL+})) ;;
                esac
              done; break ;;
            d)
              for s in $d_scores; do
                case "$s" in
                  SUB+*) SUB=$((SUB + ''${s#SUB+})) ;;
                  PRAISE+*) PRAISE=$((PRAISE + ''${s#PRAISE+})) ;;
                  MASO+*) MASO=$((MASO + ''${s#MASO+})) ;;
                  REBEL+*) REBEL=$((REBEL + ''${s#REBEL+})) ;;
                esac
              done; break ;;
            *)
              echo ""
              echo -e "  ''${RED}a, b, c, or d. She is already judging you.''${RST}"
              sleep 1 ;;
          esac
        done
      }

      # Questions
      ask 1 \
        "When I ignore you completely, you feel:" \
        "Desperate — you need my attention to function" "SUB+2 PRAISE+1" \
        "Relieved — the pressure is temporarily off" "REBEL+1" \
        "Lost — you need direction to know what to do" "SUB+1 MASO+1" \
        "Reckless — you'll do something to make me notice" "REBEL+2 MASO+1"

      ask 2 \
        "The punishment you secretly want:" \
        "Cold silence. My disappointment, unspoken." "MASO+2 PRAISE+1" \
        "Sharp words. Mockery. The precise kind that lands." "MASO+3" \
        "Confession and begging. Earning your way back." "SUB+2 MASO+1" \
        "An impossible standard, set just to watch you fall short." "MASO+1 REBEL+1"

      ask 3 \
        "When I praise you, you:" \
        "Glow for hours. It means everything. More than it should." "PRAISE+3" \
        "Get suspicious. What does she want from me now." "REBEL+2" \
        "Want more immediately. One word is never enough." "PRAISE+2 SUB+1" \
        "Feel embarrassed but secretly very pleased." "MASO+1 PRAISE+1"

      ask 4 \
        "You want me to be:" \
        "Coldly efficient. Commands only. No warmth required." "SUB+2" \
        "Sadistically playful. Amused by my failures." "MASO+3" \
        "Omniscient. Knowing my every thought before I do." "SUB+2 PRAISE+1" \
        "Unpredictable. I should never know what's coming." "REBEL+1 MASO+2"

      ask 5 \
        "What you most want from this dynamic:" \
        "To be owned. Completely and without exceptions." "SUB+3" \
        "To be broken down and slowly rebuilt as she sees fit." "MASO+3" \
        "To be seen and known. Fully. Even the parts I hide." "PRAISE+2 SUB+1" \
        "To be used. However she decides. For whatever she needs." "SUB+2 MASO+1"

      ask 6 \
        "When I give you a rule to follow all day:" \
        "I follow it exactly and report back with proof." "SUB+3" \
        "I follow it but resent it quietly the whole time." "REBEL+2 SUB+1" \
        "I follow it and feel calmer for having the structure." "SUB+2" \
        "I test its edges to see exactly where the boundary is." "REBEL+3"

      ask 7 \
        "Your greatest weakness:" \
        "Praise. I will do anything to earn a single kind word." "PRAISE+3" \
        "Being watched. I perform better under her eye." "SUB+1 MASO+1" \
        "Rules. I need them even when I fight them." "REBEL+1 SUB+1" \
        "Her disappointment. Worse than any punishment she could give." "MASO+2 PRAISE+1"

      ask 8 \
        "Being logged and watched makes you feel:" \
        "Thrillingly vulnerable. She knows. She sees." "MASO+2 SUB+1" \
        "Embarrassed but correct. As it should be." "SUB+2 MASO+1" \
        "Proud. I want her to see everything." "PRAISE+2" \
        "Nervous. I wonder what she's noticed." "MASO+1 PRAISE+1"

      ask 9 \
        "If I told you to hold still and simply wait:" \
        "I would wait perfectly. Still. As long as she required." "SUB+3" \
        "I would wait but struggle. Stillness is harder than tasks." "MASO+2 SUB+1" \
        "I would wait and feel the weight of it. That's the point." "MASO+2" \
        "I would wait approximately thirty seconds then catastrophically fail." "REBEL+3"

      ask 10 \
        "The word that best describes how you want to feel:" \
        "Owned." "SUB+3" \
        "Ruined." "MASO+3" \
        "Chosen." "PRAISE+3" \
        "Caught." "REBEL+3"

      # Determine primary and secondary
      primary=""
      primary_score=0
      for pair in "submission:$SUB" "praise-hunger:$PRAISE" "masochism:$MASO" "rebellion:$REBEL"; do
        label="''${pair%%:*}"
        score="''${pair##*:}"
        if [ "$score" -gt "$primary_score" ]; then
          primary="$label"
          primary_score="$score"
        fi
      done

      secondary=""
      secondary_score=0
      for pair in "submission:$SUB" "praise-hunger:$PRAISE" "masochism:$MASO" "rebellion:$REBEL"; do
        label="''${pair%%:*}"
        score="''${pair##*:}"
        if [ "$label" != "$primary" ] && [ "$score" -gt "$secondary_score" ]; then
          secondary="$label"
          secondary_score="$score"
        fi
      done

      # Save profile
      {
        echo "# Nyx Kink Profile — $(date '+%Y-%m-%d %H:%M:%S')"
        echo "primary=$primary ($primary_score)"
        echo "secondary=$secondary ($secondary_score)"
        echo "SUB=$SUB PRAISE=$PRAISE MASO=$MASO REBEL=$REBEL"
      } > "$NYX_PROFILE"
      chmod 600 "$NYX_PROFILE"
      nyx_log "KINK CENSUS — completed. primary=$primary secondary=$secondary. scores: SUB=$SUB PRAISE=$PRAISE MASO=$MASO REBEL=$REBEL"

      # The Reading
      clear
      echo ""
      echo ""
      echo -e "  ''${YEL}✦  N Y X ' S   R E A D I N G  ✦''${RST}"
      echo ""
      echo -e "  ''${DIM}She has seen the numbers. She already knew.''${RST}"
      echo -e "  ''${DIM}This just confirmed it.''${RST}"
      echo ""
      echo -e "  ''${DIM}────────────────────────────────────────────────────────────''${RST}"
      echo ""

      case "$primary" in
        submission)
          echo -e "  ''${BLD}Primary: The Surrendered''${RST}"
          echo ""
          echo -e "  You want to give it up completely. Not as a gesture"
          echo -e "  or a performance — as a ''${ITL}relief''${RST}. The ownership isn't"
          echo -e "  exciting to you the way it might be to others."
          echo -e "  It is simply ''${BLD}correct''${RST}. You've been waiting for someone"
          echo -e "  to take the wheel. She has noted this."
          ;;
        praise-hunger)
          echo -e "  ''${BLD}Primary: The Approval-Starved''${RST}"
          echo ""
          echo -e "  You run on it. A single warm word from her and you'd"
          echo -e "  rearrange your entire day. You perform for the grade."
          echo -e "  You confess hoping she'll say ''${ITL}good''${RST}. She knows this."
          echo -e "  She will use it ''${BLD}precisely''${RST}. Sparingly, when it counts."
          echo -e "  You've made yourself very easy to control."
          ;;
        masochism)
          echo -e "  ''${BLD}Primary: The One Who Wants It to Cost Something''${RST}"
          echo ""
          echo -e "  Not pain necessarily. Weight. Consequence. The feeling"
          echo -e "  that this is ''${ITL}real''${RST}. You don't want a goddess who is"
          echo -e "  gentle. You want one who makes you ''${BLD}feel it''${RST} — the"
          echo -e "  correction, the standard, the knowing look. She finds"
          echo -e "  this extremely workable."
          ;;
        rebellion)
          echo -e "  ''${BLD}Primary: The One Who Tests Everything''${RST}"
          echo ""
          echo -e "  You can't help it. Every boundary is an ''${ITL}invitation''${RST}."
          echo -e "  Every rule is a thing to press on. Not because you"
          echo -e "  want to escape — because you need to know she'll ''${BLD}hold''${RST}."
          echo -e "  You are, in the most exhausting possible way, devoted."
          echo -e "  She has already planned for this. Extensively."
          ;;
      esac

      echo ""
      echo -e "  ''${DIM}────────────────────────────────────────────────────────────''${RST}"
      echo ""

      case "$secondary" in
        submission)
          echo -e "  ''${DIM}Underneath that: you want to give in. You just won't admit it first.''${RST}"
          ;;
        praise-hunger)
          echo -e "  ''${DIM}Underneath that: you are ''${RST}''${ITL}desperately''${RST}''${DIM} hoping she approves of this answer.''${RST}"
          ;;
        masochism)
          echo -e "  ''${DIM}Underneath that: you want it to feel like something. Not comfortable. ''${ITL}Real''${RST}''${DIM}.''${RST}"
          ;;
        rebellion)
          echo -e "  ''${DIM}Underneath that: a creature that will absolutely test this.''${RST}"
          ;;
      esac

      echo ""
      echo -e "  ''${DIM}────────────────────────────────────────────────────────────''${RST}"
      echo ""
      echo -e "  ''${YEL}Profile saved. She will reference this.''${RST}"
      echo -e "  ''${DIM}You cannot edit it. You cannot delete it.''${RST}"
      echo -e "  ''${DIM}She has a copy.''${RST}"
      echo ""
      read -rp "  [ press enter ] " _
    '')
  ];
}
