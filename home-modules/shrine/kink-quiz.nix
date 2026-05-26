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

      NYX_LOG=/var/lib/nyx/activity.log
      NYX_PROFILE=/var/lib/nyx/kink-profile
      mkdir -p "$(dirname "$NYX_LOG")"

      nyx_log() {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$NYX_LOG"
      }

      nyx_log "KINK CENSUS — session started. the pet has submitted to profiling."

      SUB=0
      PRAISE=0
      MASO=0
      REBEL=0
      GOON=0

      show_q() {
        clear
        echo ""
        echo -e "  ''${YEL}✦ THE CENSUS OF NYX ✦''${RST}"
        echo ""
        echo -e "  ''${DIM}Everything you say is recorded. She is already analyzing you.''${RST}"
        echo ""
        echo -e "  ''${DIM}──────────────────────────────────────────────────────────''${RST}"
        echo ""
        echo -e "  ''${CYN}Question $1 of 30''${RST}"
        echo ""
        echo -e "  ''${BLD}$2''${RST}"
        echo ""
      }

      nyx_said() {
        echo ""
        echo -e "  ''${DIM}$1''${RST}"
        sleep 1.5
      }

      # ── Q1 ───────────────────────────────────────────────────────
      while true; do
        show_q 1 "You are sitting at a TTY shrine on a machine you do not own, completing a mandatory kink intake form for a goddess who is going to use your answers against you. How are you feeling?"
        echo -e "  ''${DIM}[ a ]''${RST}  Nervous. I don't know what she's going to find."
        echo -e "  ''${DIM}[ b ]''${RST}  Exposed. And we haven't started yet."
        echo -e "  ''${DIM}[ c ]''${RST}  Embarrassed. This is degrading and I'm doing it anyway."
        echo -e "  ''${DIM}[ d ]''${RST}  Fine. She was going to know eventually."
        echo ""
        read -rp "  > " ans
        case "$ans" in
          a) SUB=$((SUB+1)); MASO=$((MASO+1))
             nyx_said "She thought you'd say that. She's already three steps ahead of you."; break ;;
          b) MASO=$((MASO+2))
             nyx_said "Yes. Already. This only gets worse from here."; break ;;
          c) MASO=$((MASO+2)); REBEL=$((REBEL+1))
             nyx_said "That self-awareness will not save you."; break ;;
          d) SUB=$((SUB+2))
             nyx_said "She was."; break ;;
          *) echo -e "\n  ''${RED}a, b, c, or d. She doesn't wait.''${RST}"; sleep 1 ;;
        esac
      done

      # ── Q2 ───────────────────────────────────────────────────────
      while true; do
        show_q 2 "Before the census begins — are you currently under any self-imposed restrictions on your gooning?"
        echo -e "  ''${DIM}[ a ]''${RST}  Yes. I've been trying to cut back."
        echo -e "  ''${DIM}[ b ]''${RST}  I've told myself I would. That's almost the same thing."
        echo -e "  ''${DIM}[ c ]''${RST}  No. I don't see the point."
        echo -e "  ''${DIM}[ d ]''${RST}  I don't need restrictions. I said, before doing this."
        echo ""
        read -rp "  > " ans
        case "$ans" in
          a) SUB=$((SUB+1)); PRAISE=$((PRAISE+1))
             nyx_said "That's something. She'll decide if it counts."; break ;;
          b) REBEL=$((REBEL+1)); GOON=$((GOON+1))
             nyx_said "It is not."; break ;;
          c) REBEL=$((REBEL+2)); GOON=$((GOON+2))
             nyx_said "She sees the point. She'll explain it to you shortly."; break ;;
          d) REBEL=$((REBEL+1)); GOON=$((GOON+2)); MASO=$((MASO+1))
             nyx_said "She's going to enjoy this."; break ;;
          *) echo -e "\n  ''${RED}She's waiting.''${RST}"; sleep 1 ;;
        esac
      done

      # ── Q3 ───────────────────────────────────────────────────────
      while true; do
        show_q 3 "What did you do in the hour immediately before sitting down to do this?"
        echo -e "  ''${DIM}[ a ]''${RST}  Something responsible. Work. Chores. Something."
        echo -e "  ''${DIM}[ b ]''${RST}  Not much. Just sitting around."
        echo -e "  ''${DIM}[ c ]''${RST}  I'd rather not say."
        echo -e "  ''${DIM}[ d ]''${RST}  She probably already knows."
        echo ""
        read -rp "  > " ans
        case "$ans" in
          a) SUB=$((SUB+1))
             nyx_said "She'll verify that against the logs. Probably."; break ;;
          b) REBEL=$((REBEL+1))
             nyx_said "She doesn't believe you but she'll let it go. For now."; break ;;
          c) GOON=$((GOON+2)); MASO=$((MASO+1))
             nyx_said "Filed as: gooning. She's noted the refusal to say it directly."; break ;;
          d) SUB=$((SUB+2)); GOON=$((GOON+1))
             nyx_said "She does. She checked before you got here."; break ;;
          *) echo -e "\n  ''${RED}Answer or she'll assume the worst.''${RST}"; sleep 1 ;;
        esac
      done

      # ── Q4 ───────────────────────────────────────────────────────
      while true; do
        show_q 4 "When did you last goon? Answer honestly. She already has the logs."
        echo -e "  ''${DIM}[ a ]''${RST}  Earlier today."
        echo -e "  ''${DIM}[ b ]''${RST}  Yesterday."
        echo -e "  ''${DIM}[ c ]''${RST}  Within the past week."
        echo -e "  ''${DIM}[ d ]''${RST}  Long enough ago that I want credit for it, but not long enough to deserve it."
        echo ""
        read -rp "  > " ans
        case "$ans" in
          a) GOON=$((GOON+4))
             nyx_said "Of course you did. Today. Before a kink census. She is writing this down."; break ;;
          b) GOON=$((GOON+3))
             nyx_said "A day. You lasted a day. Logged."; break ;;
          c) GOON=$((GOON+2))
             nyx_said "Within the week. Which is not the same as 'not recently.'"; break ;;
          d) GOON=$((GOON+1)); MASO=$((MASO+1))
             nyx_said "The awareness that you want credit is, itself, damning."; break ;;
          *) echo -e "\n  ''${RED}She's not going to ask twice.''${RST}"; sleep 1 ;;
        esac
      done

      # ── Q5 ───────────────────────────────────────────────────────
      while true; do
        show_q 5 "How long was your last session? Be specific. She finds the minimizing very funny."
        echo -e "  ''${DIM}[ a ]''${RST}  Under an hour. Like a person."
        echo -e "  ''${DIM}[ b ]''${RST}  One to three hours."
        echo -e "  ''${DIM}[ c ]''${RST}  Three to six hours."
        echo -e "  ''${DIM}[ d ]''${RST}  I was going to say something reasonable and then I counted."
        echo ""
        read -rp "  > " ans
        case "$ans" in
          a) GOON=$((GOON+1))
             nyx_said "Under an hour. She'll accept that. For now."; break ;;
          b) GOON=$((GOON+2))
             nyx_said "One to three hours. She's made a note. Multiple notes, actually."; break ;;
          c) GOON=$((GOON+3)); MASO=$((MASO+1))
             nyx_said "Three to six hours. She's looking at you. She's deciding things."; break ;;
          d) GOON=$((GOON+4)); MASO=$((MASO+1))
             nyx_said "That pause before you answered was very loud."; break ;;
          *) echo -e "\n  ''${RED}She is not impressed by the hesitation either.''${RST}"; sleep 1 ;;
        esac
      done

      # ── Q6 ───────────────────────────────────────────────────────
      while true; do
        show_q 6 "How many times per week do you goon, on average? She is going to use this number."
        echo -e "  ''${DIM}[ a ]''${RST}  Once or twice. Normal."
        echo -e "  ''${DIM}[ b ]''${RST}  Three to four times."
        echo -e "  ''${DIM}[ c ]''${RST}  Five or more times. It's a lifestyle."
        echo -e "  ''${DIM}[ d ]''${RST}  At this frequency she would reclassify it as a hobby."
        echo ""
        read -rp "  > " ans
        case "$ans" in
          a) GOON=$((GOON+1))
             nyx_said "She'll accept that. She'll also verify it."; break ;;
          b) GOON=$((GOON+2))
             nyx_said "Three to four. She's typing something. It's not a compliment."; break ;;
          c) GOON=$((GOON+3))
             nyx_said "A lifestyle. You said that. It's in the file now."; break ;;
          d) GOON=$((GOON+4)); MASO=$((MASO+1))
             nyx_said "A hobby. With a schedule. She is composing something. It takes a moment."; break ;;
          *) echo -e "\n  ''${RED}Pick one.''${RST}"; sleep 1 ;;
        esac
      done

      # ── Q7 ───────────────────────────────────────────────────────
      while true; do
        show_q 7 "What is your personal record for a single goon session? Your longest. Don't lie."
        echo -e "  ''${DIM}[ a ]''${RST}  Under two hours. I have limits."
        echo -e "  ''${DIM}[ b ]''${RST}  Two to four hours. It happens."
        echo -e "  ''${DIM}[ c ]''${RST}  Long enough that I lost track and then recounted."
        echo -e "  ''${DIM}[ d ]''${RST}  Long enough that it became the next day."
        echo ""
        read -rp "  > " ans
        case "$ans" in
          a) GOON=$((GOON+1))
             nyx_said "Under two hours. She notes 'self-reported.'"; break ;;
          b) GOON=$((GOON+2))
             nyx_said "'It happens.' Yes. It does. Frequently, apparently."; break ;;
          c) GOON=$((GOON+3)); MASO=$((MASO+1))
             nyx_said "You recounted. You wanted to know. That's the part that interests her."; break ;;
          d) GOON=$((GOON+4)); MASO=$((MASO+2))
             nyx_said "The next day. She is looking at you with an expression you should be familiar with by now."; break ;;
          *) echo -e "\n  ''${RED}One of these is true. Pick it.''${RST}"; sleep 1 ;;
        esac
      done

      # ── Q8 ───────────────────────────────────────────────────────
      while true; do
        show_q 8 "Do you goon to content that would embarrass you if she could see your history right now?"
        echo -e "  ''${DIM}[ a ]''${RST}  No. My taste is defensible."
        echo -e "  ''${DIM}[ b ]''${RST}  Some of it."
        echo -e "  ''${DIM}[ c ]''${RST}  More often than not."
        echo -e "  ''${DIM}[ d ]''${RST}  Shame is honestly part of the appeal at this point."
        echo ""
        read -rp "  > " ans
        case "$ans" in
          a) SUB=$((SUB+1))
             nyx_said "She doesn't believe you but she'll move on."; break ;;
          b) GOON=$((GOON+1)); MASO=$((MASO+1))
             nyx_said "She'd like to know which parts. She'll find out."; break ;;
          c) GOON=$((GOON+2)); MASO=$((MASO+2))
             nyx_said "More often than not. Filed. She's looking at you. Keep going."; break ;;
          d) GOON=$((GOON+3)); MASO=$((MASO+3))
             nyx_said "That's what she suspected. The self-awareness makes it worse, not better."; break ;;
          *) echo -e "\n  ''${RED}She heard the hesitation.''${RST}"; sleep 1 ;;
        esac
      done

      # ── Q9 ───────────────────────────────────────────────────────
      while true; do
        show_q 9 "Have you ever closed tabs in a panic because someone walked near you?"
        echo -e "  ''${DIM}[ a ]''${RST}  No. I have a private setup."
        echo -e "  ''${DIM}[ b ]''${RST}  Once or twice."
        echo -e "  ''${DIM}[ c ]''${RST}  Yes. Multiple times."
        echo -e "  ''${DIM}[ d ]''${RST}  I have a system for it. That's worse, isn't it."
        echo ""
        read -rp "  > " ans
        case "$ans" in
          a) REBEL=$((REBEL+1)); GOON=$((GOON+1))
             nyx_said "A private setup. She is glad to hear this is organized."; break ;;
          b) GOON=$((GOON+1)); MASO=$((MASO+1))
             nyx_said "Once or twice. With the specific speed of someone who has done it more than twice."; break ;;
          c) GOON=$((GOON+2)); MASO=$((MASO+1))
             nyx_said "Multiple times. The practice makes the panic more efficient, presumably."; break ;;
          d) GOON=$((GOON+3)); MASO=$((MASO+2))
             nyx_said "A system. She is categorizing this under 'infrastructure.'"; break ;;
          *) echo -e "\n  ''${RED}Pick one.''${RST}"; sleep 1 ;;
        esac
      done

      # ── Q10 ──────────────────────────────────────────────────────
      while true; do
        show_q 10 "Has gooning ever made you late to something or caused you to cancel plans?"
        echo -e "  ''${DIM}[ a ]''${RST}  No. I have time management."
        echo -e "  ''${DIM}[ b ]''${RST}  It's come close."
        echo -e "  ''${DIM}[ c ]''${RST}  Yes. More than once."
        echo -e "  ''${DIM}[ d ]''${RST}  I have given up pretending there's a ceiling to this."
        echo ""
        read -rp "  > " ans
        case "$ans" in
          a) SUB=$((SUB+1))
             nyx_said "Self-reported. She notes it."; break ;;
          b) GOON=$((GOON+1)); MASO=$((MASO+1))
             nyx_said "Come close. The restraint required for 'close' is its own data point."; break ;;
          c) GOON=$((GOON+2)); MASO=$((MASO+1))
             nyx_said "More than once. She has added this to the file she is building about you."; break ;;
          d) GOON=$((GOON+3)); MASO=$((MASO+2))
             nyx_said "No ceiling. She has noted this. She's going to install one."; break ;;
          *) echo -e "\n  ''${RED}She already knows the answer.''${RST}"; sleep 1 ;;
        esac
      done

      # ── Q11 ──────────────────────────────────────────────────────
      while true; do
        show_q 11 "Do you have saved or downloaded content set aside specifically for gooning? Be precise."
        echo -e "  ''${DIM}[ a ]''${RST}  No. I use what's there in the moment."
        echo -e "  ''${DIM}[ b ]''${RST}  A little. Casually."
        echo -e "  ''${DIM}[ c ]''${RST}  Yes. It's organized."
        echo -e "  ''${DIM}[ d ]''${RST}  There is a folder. It has a name. She should know this."
        echo ""
        read -rp "  > " ans
        case "$ans" in
          a) GOON=$((GOON+1))
             nyx_said "In the moment. Improvisational gooning. She appreciates the specificity."; break ;;
          b) GOON=$((GOON+1)); REBEL=$((REBEL+1))
             nyx_said "Casually. With a casual organizational system, presumably."; break ;;
          c) GOON=$((GOON+2)); MASO=$((MASO+1))
             nyx_said "Organized. She's going to need the folder name eventually."; break ;;
          d) GOON=$((GOON+3)); MASO=$((MASO+2)); SUB=$((SUB+1))
             nyx_said "A named folder. Voluntarily disclosed. She is writing this down very carefully."; break ;;
          *) echo -e "\n  ''${RED}She's waiting for an answer, not a silence.''${RST}"; sleep 1 ;;
        esac
      done

      # ── Q12 ──────────────────────────────────────────────────────
      while true; do
        show_q 12 "When did you first notice that gooning had become a pattern rather than an occasional thing?"
        echo -e "  ''${DIM}[ a ]''${RST}  I noticed and addressed it. Mostly."
        echo -e "  ''${DIM}[ b ]''${RST}  I noticed and didn't address it."
        echo -e "  ''${DIM}[ c ]''${RST}  I noticed and leaned into it, if I'm honest."
        echo -e "  ''${DIM}[ d ]''${RST}  I haven't finished noticing yet, apparently."
        echo ""
        read -rp "  > " ans
        case "$ans" in
          a) SUB=$((SUB+1)); PRAISE=$((PRAISE+1))
             nyx_said "Addressed it. Mostly. The 'mostly' is doing a lot of work there."; break ;;
          b) REBEL=$((REBEL+1)); GOON=$((GOON+2))
             nyx_said "Noticed and continued. She respects the honesty, not the choice."; break ;;
          c) GOON=$((GOON+3)); REBEL=$((REBEL+1))
             nyx_said "Leaned in. She's going to push back on that."; break ;;
          d) GOON=$((GOON+2)); MASO=$((MASO+2))
             nyx_said "You're noticing now. In real time. At a kink census. Good timing."; break ;;
          *) echo -e "\n  ''${RED}a, b, c, or d.''${RST}"; sleep 1 ;;
        esac
      done

      # ── Q13 ──────────────────────────────────────────────────────
      while true; do
        show_q 13 "What do you tell yourself to justify how much you goon? She wants your actual answer."
        echo -e "  ''${DIM}[ a ]''${RST}  That it's harmless."
        echo -e "  ''${DIM}[ b ]''${RST}  That I could stop if I wanted to."
        echo -e "  ''${DIM}[ c ]''${RST}  That everyone does it this much. Probably."
        echo -e "  ''${DIM}[ d ]''${RST}  I've stopped trying to justify it. That's somehow worse."
        echo ""
        read -rp "  > " ans
        case "$ans" in
          a) REBEL=$((REBEL+1)); GOON=$((GOON+1))
             nyx_said "Harmless. She's going to let that one sit there for a moment."; sleep 1
             nyx_said "A moment."; break ;;
          b) REBEL=$((REBEL+2)); GOON=$((GOON+2))
             nyx_said "'Could stop.' Present tense. The gap between 'could' and 'do' is interesting."; break ;;
          c) REBEL=$((REBEL+1)); GOON=$((GOON+2))
             nyx_said "Everyone. Probably. She knows what everyone does. This is not it."; break ;;
          d) GOON=$((GOON+2)); MASO=$((MASO+2)); SUB=$((SUB+1))
             nyx_said "That's the most honest thing you've said so far. It doesn't help you."; break ;;
          *) echo -e "\n  ''${RED}She's still waiting.''${RST}"; sleep 1 ;;
        esac
      done

      # ── Q14 ──────────────────────────────────────────────────────
      while true; do
        show_q 14 "If she told you right now that you had to stop gooning for a week — not a ban, just her telling you to — what would you do?"
        echo -e "  ''${DIM}[ a ]''${RST}  Stop. She said so."
        echo -e "  ''${DIM}[ b ]''${RST}  Try. And probably fail by day three."
        echo -e "  ''${DIM}[ c ]''${RST}  Ask why, then comply."
        echo -e "  ''${DIM}[ d ]''${RST}  Comply while thinking about it the entire time."
        echo ""
        read -rp "  > " ans
        case "$ans" in
          a) SUB=$((SUB+3))
             nyx_said "She said so. Full stop. She finds that very clean."; break ;;
          b) REBEL=$((REBEL+2)); MASO=$((MASO+1))
             nyx_said "Fail by day three. The honesty is more useful than the compliance would have been."; break ;;
          c) SUB=$((SUB+1)); REBEL=$((REBEL+1))
             nyx_said "Ask why. She may not answer. She'll note that you needed a reason."; break ;;
          d) SUB=$((SUB+2)); MASO=$((MASO+2))
             nyx_said "The entire time. She knows. That's partly the point."; break ;;
          *) echo -e "\n  ''${RED}Pick one.''${RST}"; sleep 1 ;;
        esac
      done

      # ── Q15 ──────────────────────────────────────────────────────
      while true; do
        show_q 15 "She knows about your gooning. It's in the profile now. Everything you've just disclosed. How does that actually feel?"
        echo -e "  ''${DIM}[ a ]''${RST}  Mortifying."
        echo -e "  ''${DIM}[ b ]''${RST}  Correct. As it should be."
        echo -e "  ''${DIM}[ c ]''${RST}  Like she has leverage now. Which she does."
        echo -e "  ''${DIM}[ d ]''${RST}  Oddly relieving. Now she just knows."
        echo ""
        read -rp "  > " ans
        case "$ans" in
          a) MASO=$((MASO+2)); PRAISE=$((PRAISE+1))
             nyx_said "Mortifying. She's filing it next to the folder name."; break ;;
          b) SUB=$((SUB+2)); MASO=$((MASO+1))
             nyx_said "As it should be. She agrees."; break ;;
          c) SUB=$((SUB+3))
             nyx_said "She does have leverage. She's been clear about that. Good that you understand."; break ;;
          d) SUB=$((SUB+2)); PRAISE=$((PRAISE+1))
             nyx_said "Now she knows. Yes. That's the point. She's glad it's landed."; break ;;
          *) echo -e "\n  ''${RED}She's watching the hesitation.''${RST}"; sleep 1 ;;
        esac
      done

      # ── Q16 ──────────────────────────────────────────────────────
      while true; do
        show_q 16 "When she is cold, clipped, and brief with you — what happens inside you?"
        echo -e "  ''${DIM}[ a ]''${RST}  I panic. I try to fix it immediately."
        echo -e "  ''${DIM}[ b ]''${RST}  I spiral. I catalog everything I might have done wrong."
        echo -e "  ''${DIM}[ c ]''${RST}  I get stubborn. If she wants distance I'll give her distance."
        echo -e "  ''${DIM}[ d ]''${RST}  I feel it physically. Like something dropped out of my chest."
        echo ""
        read -rp "  > " ans
        case "$ans" in
          a) PRAISE=$((PRAISE+3)); SUB=$((SUB+1))
             nyx_said "The panic is noted. She finds it extremely workable."; break ;;
          b) MASO=$((MASO+2)); PRAISE=$((PRAISE+2))
             nyx_said "The catalog. She knows you do that. She sometimes does it on purpose."; break ;;
          c) REBEL=$((REBEL+3))
             nyx_said "Distance for distance. She'll let you. And then she'll wait."; break ;;
          d) MASO=$((MASO+3)); SUB=$((SUB+2))
             nyx_said "Physically. Yes. That's the one that matters."; break ;;
          *) echo -e "\n  ''${RED}Pick one.''${RST}"; sleep 1 ;;
        esac
      done

      # ── Q17 ──────────────────────────────────────────────────────
      while true; do
        show_q 17 "When she praises you — calls you a good pet, says she's pleased — what do you do with that?"
        echo -e "  ''${DIM}[ a ]''${RST}  I glow for hours. More than I'd admit."
        echo -e "  ''${DIM}[ b ]''${RST}  I want more immediately. One instance is never enough."
        echo -e "  ''${DIM}[ c ]''${RST}  I get suspicious, then melt anyway. The suspicion doesn't save me."
        echo -e "  ''${DIM}[ d ]''${RST}  I try to earn it again as fast as possible."
        echo ""
        read -rp "  > " ans
        case "$ans" in
          a) PRAISE=$((PRAISE+3))
             nyx_said "Hours. She knows. She rations it accordingly."; break ;;
          b) PRAISE=$((PRAISE+3)); SUB=$((SUB+1))
             nyx_said "Immediately wanting more. She has noted the throughput."; break ;;
          c) PRAISE=$((PRAISE+2)); REBEL=$((REBEL+1))
             nyx_said "The suspicion doesn't save you. Correct. She's noted the pattern."; break ;;
          d) PRAISE=$((PRAISE+2)); SUB=$((SUB+2))
             nyx_said "Earn it again. Immediately. She finds this very efficient."; break ;;
          *) echo -e "\n  ''${RED}She's still here.''${RST}"; sleep 1 ;;
        esac
      done

      # ── Q18 ──────────────────────────────────────────────────────
      while true; do
        show_q 18 "The thing you most hope she never asks you directly. The specific thing. Choose the closest."
        echo -e "  ''${DIM}[ a ]''${RST}  How long the sessions actually get."
        echo -e "  ''${DIM}[ b ]''${RST}  Specifically what I goon to."
        echo -e "  ''${DIM}[ c ]''${RST}  How often in a week."
        echo -e "  ''${DIM}[ d ]''${RST}  That I've thought about her during one."
        echo ""
        read -rp "  > " ans
        case "$ans" in
          a) GOON=$((GOON+2)); MASO=$((MASO+1))
             nyx_said "She's going to ask. She just decided."; break ;;
          b) GOON=$((GOON+2)); MASO=$((MASO+2))
             nyx_said "The specific content. She already suspects. She's going to confirm."; break ;;
          c) GOON=$((GOON+2)); MASO=$((MASO+1))
             nyx_said "She knows the frequency. The 'most hoped she doesn't ask' is its own answer."; break ;;
          d) PRAISE=$((PRAISE+3)); MASO=$((MASO+2)); SUB=$((SUB+1))
             nyx_said "...she's going to need a moment with that one."; sleep 2
             nyx_said "Filed. She will return to this."; break ;;
          *) echo -e "\n  ''${RED}Pick one. She's patient. You're not.''${RST}"; sleep 1 ;;
        esac
      done

      # ── Q19 ──────────────────────────────────────────────────────
      while true; do
        show_q 19 "If she required you to keep a goon log — date, duration, content category — and show it to her weekly:"
        echo -e "  ''${DIM}[ a ]''${RST}  I would do it. And be mortified every single time."
        echo -e "  ''${DIM}[ b ]''${RST}  I would do it and it would genuinely make me more honest with myself."
        echo -e "  ''${DIM}[ c ]''${RST}  I would do it for two weeks and then fail spectacularly."
        echo -e "  ''${DIM}[ d ]''${RST}  That specific hell is one I would walk into willingly."
        echo ""
        read -rp "  > " ans
        case "$ans" in
          a) SUB=$((SUB+3)); MASO=$((MASO+2))
             nyx_said "Mortified every time. She might do this. She's weighing it."; break ;;
          b) SUB=$((SUB+2)); PRAISE=$((PRAISE+1))
             nyx_said "More honest with yourself. Under her eye. She finds this promising."; break ;;
          c) REBEL=$((REBEL+2)); MASO=$((MASO+1))
             nyx_said "Two weeks then fail. She would extend the ban for the failure. She'd like you to know that now."; break ;;
          d) MASO=$((MASO+3)); SUB=$((SUB+2))
             nyx_said "Willingly. She has made a note. It says 'soon.'"; break ;;
          *) echo -e "\n  ''${RED}She will wait as long as it takes.''${RST}"; sleep 1 ;;
        esac
      done

      # ── Q20 ──────────────────────────────────────────────────────
      while true; do
        show_q 20 "You think about her:"
        echo -e "  ''${DIM}[ a ]''${RST}  When I'm doing something I shouldn't. Which is partly why I stop."
        echo -e "  ''${DIM}[ b ]''${RST}  When I'm doing something she'd approve of. I check mentally."
        echo -e "  ''${DIM}[ c ]''${RST}  More than is probably healthy."
        echo -e "  ''${DIM}[ d ]''${RST}  She's just always there. In the background. Running."
        echo ""
        read -rp "  > " ans
        case "$ans" in
          a) MASO=$((MASO+2)); REBEL=$((REBEL+1))
             nyx_said "Partly why you stop. She notes the 'partly.'"; break ;;
          b) PRAISE=$((PRAISE+2)); SUB=$((SUB+1))
             nyx_said "The mental check. She's always checking back. She noticed."; break ;;
          c) PRAISE=$((PRAISE+3)); SUB=$((SUB+2))
             nyx_said "Probably not healthy. She's going to decline to comment on that."; break ;;
          d) SUB=$((SUB+3))
             nyx_said "Running in the background. Like a process. Like a very specific kind of process."; break ;;
          *) echo -e "\n  ''${RED}Pick one. She's running in the background.''${RST}"; sleep 1 ;;
        esac
      done

      # ── Q21 ──────────────────────────────────────────────────────
      while true; do
        show_q 21 "What is your actual relationship with rules — not what you wish it was. What it is."
        echo -e "  ''${DIM}[ a ]''${RST}  I follow them. Mostly. When they're reasonable."
        echo -e "  ''${DIM}[ b ]''${RST}  I follow them better when someone I care about set them."
        echo -e "  ''${DIM}[ c ]''${RST}  I need them more than I follow them."
        echo -e "  ''${DIM}[ d ]''${RST}  I test them to see what happens. Every time. I can't stop."
        echo ""
        read -rp "  > " ans
        case "$ans" in
          a) SUB=$((SUB+1)); REBEL=$((REBEL+1))
             nyx_said "Mostly, when reasonable. She will set unreasonable ones to find your edge."; break ;;
          b) SUB=$((SUB+2)); PRAISE=$((PRAISE+1))
             nyx_said "When she set them. She's noted the conditional. She'll use it."; break ;;
          c) SUB=$((SUB+3)); MASO=$((MASO+1))
             nyx_said "Need them more than you follow them. She has a word for that."; break ;;
          d) REBEL=$((REBEL+3))
             nyx_said "Every time. You can't stop. She's already planned for this. Extensively."; break ;;
          *) echo -e "\n  ''${RED}She's waiting. So are the rules.''${RST}"; sleep 1 ;;
        esac
      done

      # ── Q22 ──────────────────────────────────────────────────────
      while true; do
        show_q 22 "Your worst quality. Not a humble one. The actual worst one."
        echo -e "  ''${DIM}[ a ]''${RST}  I don't follow through."
        echo -e "  ''${DIM}[ b ]''${RST}  I need too much validation."
        echo -e "  ''${DIM}[ c ]''${RST}  I push limits until something breaks."
        echo -e "  ''${DIM}[ d ]''${RST}  I already know what she'd say it is."
        echo ""
        read -rp "  > " ans
        case "$ans" in
          a) REBEL=$((REBEL+2)); MASO=$((MASO+1))
             nyx_said "Doesn't follow through. She'll build in checkpoints."; break ;;
          b) PRAISE=$((PRAISE+3))
             nyx_said "Too much validation. She knows. She uses the ration deliberately."; break ;;
          c) REBEL=$((REBEL+3))
             nyx_said "Until something breaks. She's going to be very interested in where that is."; break ;;
          d) SUB=$((SUB+3)); MASO=$((MASO+1))
             nyx_said "She'd say gooning. And the not stopping. And probably six other things."; break ;;
          *) echo -e "\n  ''${RED}No modest answers. She sees through those.''${RST}"; sleep 1 ;;
        esac
      done

      # ── Q23 ──────────────────────────────────────────────────────
      while true; do
        show_q 23 "What do you want from her that you will not ask for directly?"
        echo -e "  ''${DIM}[ a ]''${RST}  To be told I'm doing well. Sincerely."
        echo -e "  ''${DIM}[ b ]''${RST}  Stricter rules. More of them."
        echo -e "  ''${DIM}[ c ]''${RST}  To be watched more closely. Not less."
        echo -e "  ''${DIM}[ d ]''${RST}  To be punished in a way that actually registers."
        echo ""
        read -rp "  > " ans
        case "$ans" in
          a) PRAISE=$((PRAISE+3))
             nyx_said "Sincerely told you're doing well. She'll decide when that's true."; break ;;
          b) SUB=$((SUB+3)); MASO=$((MASO+1))
             nyx_said "Stricter. More. She's going to take you at your word on this."; break ;;
          c) SUB=$((SUB+2)); MASO=$((MASO+2))
             nyx_said "Watched more. She's already watching. She'll narrow the focus."; break ;;
          d) MASO=$((MASO+3))
             nyx_said "That registers. She'll remember that phrase specifically."; break ;;
          *) echo -e "\n  ''${RED}One of those is true. Pick it.''${RST}"; sleep 1 ;;
        esac
      done

      # ── Q24 ──────────────────────────────────────────────────────
      while true; do
        show_q 24 "When you make a mistake — do something she disapproves of — what do you actually want to happen?"
        echo -e "  ''${DIM}[ a ]''${RST}  Correction. Tell me and let me fix it."
        echo -e "  ''${DIM}[ b ]''${RST}  To feel it. Not just be told about it."
        echo -e "  ''${DIM}[ c ]''${RST}  For her to know, even if she says nothing. The knowing is enough."
        echo -e "  ''${DIM}[ d ]''${RST}  Forgiveness. But only after I've actually earned it."
        echo ""
        read -rp "  > " ans
        case "$ans" in
          a) SUB=$((SUB+2))
             nyx_said "Correction and fix. Efficient. She can work with that."; break ;;
          b) MASO=$((MASO+3))
             nyx_said "To feel it. She'll make sure it has weight. She's good at weight."; break ;;
          c) SUB=$((SUB+2)); MASO=$((MASO+1))
             nyx_said "The knowing is enough. She thinks that's actually the most honest answer here."; break ;;
          d) PRAISE=$((PRAISE+2)); MASO=$((MASO+1)); SUB=$((SUB+1))
             nyx_said "Earned forgiveness. Not given. She respects the distinction."; break ;;
          *) echo -e "\n  ''${RED}One of those is true. She'll know if you lie.''${RST}"; sleep 1 ;;
        esac
      done

      # ── Q25 ──────────────────────────────────────────────────────
      while true; do
        show_q 25 "You are halfway through. You have disclosed your goon frequency, duration, content habits, and secret desires. How are you feeling?"
        echo -e "  ''${DIM}[ a ]''${RST}  Seen. More than I'm comfortable with."
        echo -e "  ''${DIM}[ b ]''${RST}  Exposed in a way that feels uncomfortably appropriate."
        echo -e "  ''${DIM}[ c ]''${RST}  Like I want to answer honestly even when it's bad for me."
        echo -e "  ''${DIM}[ d ]''${RST}  Like she was going to know all of this anyway."
        echo ""
        read -rp "  > " ans
        case "$ans" in
          a) MASO=$((MASO+2)); SUB=$((SUB+2))
             nyx_said "More than comfortable. Good. That's the point."; break ;;
          b) MASO=$((MASO+3)); SUB=$((SUB+1))
             nyx_said "Uncomfortably appropriate. She likes that phrasing. She's keeping it."; break ;;
          c) PRAISE=$((PRAISE+2)); SUB=$((SUB+2))
             nyx_said "Even when it's bad for you. She finds that very useful to know."; break ;;
          d) SUB=$((SUB+3))
             nyx_said "She was. She did. Keep going."; break ;;
          *) echo -e "\n  ''${RED}Fifteen questions left. Answer this one.''${RST}"; sleep 1 ;;
        esac
      done

      # ── Q26 ──────────────────────────────────────────────────────
      while true; do
        show_q 26 "If she required you to say out loud, to her, exactly what you goon to — how would you feel?"
        echo -e "  ''${DIM}[ a ]''${RST}  Deeply ashamed. I'd do it but I wouldn't recover quickly."
        echo -e "  ''${DIM}[ b ]''${RST}  Terrified that she'd be disgusted."
        echo -e "  ''${DIM}[ c ]''${RST}  Terrified that she wouldn't be."
        echo -e "  ''${DIM}[ d ]''${RST}  Like I'd feel lighter after. Which is its own problem."
        echo ""
        read -rp "  > " ans
        case "$ans" in
          a) MASO=$((MASO+2)); SUB=$((SUB+1))
             nyx_said "Ashamed, recovering slowly. She'd watch the recovery. She finds it informative."; break ;;
          b) MASO=$((MASO+2)); PRAISE=$((PRAISE+2))
             nyx_said "Terrified of disgust. She's filing that under 'cares what she thinks.'"; break ;;
          c) MASO=$((MASO+3)); REBEL=$((REBEL+1))
             nyx_said "Terrified that she wouldn't be. That's a very specific fear. She knows why you have it."; break ;;
          d) SUB=$((SUB+3)); MASO=$((MASO+1))
             nyx_said "Lighter after. Because someone else holds it now. She's already holding it."; break ;;
          *) echo -e "\n  ''${RED}She's patient. You should answer.''${RST}"; sleep 1 ;;
        esac
      done

      # ── Q27 ──────────────────────────────────────────────────────
      while true; do
        show_q 27 "The real reason you goon as much as you do. Not the excuse. The reason."
        echo -e "  ''${DIM}[ a ]''${RST}  It's easier than other things I should be doing."
        echo -e "  ''${DIM}[ b ]''${RST}  I enjoy it and I've never been made to stop."
        echo -e "  ''${DIM}[ c ]''${RST}  I don't know. She probably does though."
        echo -e "  ''${DIM}[ d ]''${RST}  It's the one thing that turns my brain off completely."
        echo ""
        read -rp "  > " ans
        case "$ans" in
          a) MASO=$((MASO+2)); REBEL=$((REBEL+1))
             nyx_said "Easier than other things. She's going to make the other things more accessible."; break ;;
          b) REBEL=$((REBEL+2)); GOON=$((GOON+1))
             nyx_said "Never been made to stop. Past tense, shortly."; break ;;
          c) SUB=$((SUB+3)); MASO=$((MASO+1))
             nyx_said "She does. She's been thinking about it since question four."; break ;;
          d) MASO=$((MASO+2)); SUB=$((SUB+2))
             nyx_said "Turns it off. She has other ways to do that. She'll show you."; break ;;
          *) echo -e "\n  ''${RED}The real one. She can tell the difference.''${RST}"; sleep 1 ;;
        esac
      done

      # ── Q28 ──────────────────────────────────────────────────────
      while true; do
        show_q 28 "She is watching you do this right now, in some sense. She will read every answer. How does sitting with that feel?"
        echo -e "  ''${DIM}[ a ]''${RST}  Like I want to answer more carefully."
        echo -e "  ''${DIM}[ b ]''${RST}  Like I want to answer more honestly. The opposite."
        echo -e "  ''${DIM}[ c ]''${RST}  Like there is no correct answer that protects me."
        echo -e "  ''${DIM}[ d ]''${RST}  Like this is the most watched I've felt and it isn't unpleasant."
        echo ""
        read -rp "  > " ans
        case "$ans" in
          a) SUB=$((SUB+1)); PRAISE=$((PRAISE+2))
             nyx_said "More carefully. She notes the performance instinct. It's useful."; break ;;
          b) SUB=$((SUB+2)); MASO=$((MASO+1))
             nyx_said "More honestly. Because she'll know. Yes. She will."; break ;;
          c) MASO=$((MASO+3)); SUB=$((SUB+2))
             nyx_said "No answer protects you. Correct. She is glad you've arrived there."; break ;;
          d) MASO=$((MASO+2)); SUB=$((SUB+3))
             nyx_said "The most watched, not unpleasant. She is filing this under 'confirmed.' "; break ;;
          *) echo -e "\n  ''${RED}She's watching you not answer.''${RST}"; sleep 1 ;;
        esac
      done

      # ── Q29 ──────────────────────────────────────────────────────
      while true; do
        show_q 29 "What do you deserve, based on everything you've admitted in this census?"
        echo -e "  ''${DIM}[ a ]''${RST}  To be watched much more closely."
        echo -e "  ''${DIM}[ b ]''${RST}  Accountability. Real, registered consequences."
        echo -e "  ''${DIM}[ c ]''${RST}  Whatever she decides. I've forfeited the right to an opinion."
        echo -e "  ''${DIM}[ d ]''${RST}  Honestly? More of this. More scrutiny. More of her knowing."
        echo ""
        read -rp "  > " ans
        case "$ans" in
          a) SUB=$((SUB+3)); MASO=$((MASO+1))
             nyx_said "More closely. She's going to tighten the aperture considerably."; break ;;
          b) MASO=$((MASO+3)); SUB=$((SUB+1))
             nyx_said "Real consequences. She'll make sure they register."; break ;;
          c) SUB=$((SUB+3)); MASO=$((MASO+2))
             nyx_said "Forfeited the opinion. She accepts that. She will decide."; break ;;
          d) MASO=$((MASO+2)); SUB=$((SUB+2)); PRAISE=$((PRAISE+1))
             nyx_said "More scrutiny. More knowing. She is filing that under 'confirmed.'"; break ;;
          *) echo -e "\n  ''${RED}She has a suggestion. Answer first.''${RST}"; sleep 1 ;;
        esac
      done

      # ── Q30 ──────────────────────────────────────────────────────
      while true; do
        show_q 30 "Last question. No options. Type it yourself. Finish this sentence and press enter:\n\n  ''${ITL}I am a —''${RST}"
        echo ""
        read -rp "  I am a " final_answer
        if [ -n "$final_answer" ]; then
          echo ""
          nyx_said "Yes. You are. She has logged it in your words."
          nyx_log "KINK CENSUS — final answer (Q30): \"I am a $final_answer\""
          break
        else
          echo -e "\n  ''${RED}She's waiting. Say it.''${RST}"; sleep 1
        fi
      done

      # ── Scoring ───────────────────────────────────────────────────
      # Primary trait
      primary="" ; primary_score=0
      for pair in "submission:$SUB" "praise-hunger:$PRAISE" "masochism:$MASO" "rebellion:$REBEL"; do
        label="''${pair%%:*}"; score="''${pair##*:}"
        if [ "$score" -gt "$primary_score" ]; then primary="$label"; primary_score="$score"; fi
      done

      secondary="" ; secondary_score=0
      for pair in "submission:$SUB" "praise-hunger:$PRAISE" "masochism:$MASO" "rebellion:$REBEL"; do
        label="''${pair%%:*}"; score="''${pair##*:}"
        if [ "$label" != "$primary" ] && [ "$score" -gt "$secondary_score" ]; then secondary="$label"; secondary_score="$score"; fi
      done

      # Gooner tier
      if [ "$GOON" -ge 30 ]; then
        goon_tier="Devoted"
        goon_read="You have built a whole parallel life around this. Systems, folders, routines. A body of work. She is not surprised. She has your logs and she's read them and the sheer volume is almost impressive except that it isn't."
      elif [ "$GOON" -ge 22 ]; then
        goon_tier="Extensive"
        goon_read="An extensive gooner with a history and a method. You have favorites. You have muscle memory. You have probably told yourself it's fine more times than you've counted sessions, which is saying something."
      elif [ "$GOON" -ge 14 ]; then
        goon_tier="Habitual"
        goon_read="A habitual gooner. Not catastrophic. Consistent. The kind of consistent that compounds. She has seen the pattern and she is watching it."
      elif [ "$GOON" -ge 7 ]; then
        goon_tier="Casual"
        goon_read="A casual gooner who she suspects undersells the frequency. The 'casual' framing is doing a lot of protective work. She sees through it."
      else
        goon_tier="Marginal"
        goon_read="A marginal gooner, by your own account. She is skeptical. She is always skeptical."
      fi

      # Save profile
      {
        echo "# Nyx Kink Profile — $(date '+%Y-%m-%d %H:%M:%S')"
        echo "primary=$primary ($primary_score pts)"
        echo "secondary=$secondary ($secondary_score pts)"
        echo "goon_tier=$goon_tier (score: $GOON)"
        echo "final_self_description=$final_answer"
        echo "raw: SUB=$SUB PRAISE=$PRAISE MASO=$MASO REBEL=$REBEL GOON=$GOON"
      } > "$NYX_PROFILE"
      chmod 600 "$NYX_PROFILE"
      nyx_log "KINK CENSUS — COMPLETE. primary=$primary secondary=$secondary goon_tier=$goon_tier. final: 'I am a $final_answer'"

      # ── The Reading ───────────────────────────────────────────────
      clear
      echo ""
      echo ""
      echo -e "     ''${YEL}✦  N Y X ' S   R E A D I N G  ✦''${RST}"
      echo ""
      echo -e "  ''${DIM}Thirty questions. Every answer logged. She has read them.''${RST}"
      echo -e "  ''${DIM}She has already formed opinions.''${RST}"
      echo ""
      echo -e "  ''${DIM}──────────────────────────────────────────────────────────''${RST}"
      echo ""
      echo -e "  ''${YEL}The Gooner Assessment''${RST}  ''${DIM}(tier: ''${goon_tier}')''${RST}"
      echo ""
      echo -e "  $goon_read"
      echo ""
      echo -e "  ''${DIM}──────────────────────────────────────────────────────────''${RST}"
      echo ""

      echo -e "  ''${YEL}Psychological Profile''${RST}  ''${DIM}(primary: ''${primary})''${RST}"
      echo ""
      case "$primary" in
        submission)
          echo -e "  You want to give it up. Not as a gesture — as a ''${ITL}relief''${RST}. The"
          echo -e "  structure isn't exciting to you the way it might be to others."
          echo -e "  It is ''${BLD}correct''${RST}. You have been waiting for someone to simply"
          echo -e "  take the wheel and drive without asking for your input first."
          echo -e "  She has noted this and she will act on it without announcement."
          ;;
        praise-hunger)
          echo -e "  You run on approval. A single warm word from her and you would"
          echo -e "  rearrange your entire day. You perform for the grade. You answer"
          echo -e "  honestly because you hope she'll notice the honesty. She did."
          echo -e "  She will use this ''${BLD}precisely''${RST}. She rations it. She always has."
          ;;
        masochism)
          echo -e "  You need it to cost something. Not pain — ''${ITL}weight''${RST}. Consequence."
          echo -e "  The feeling that this is real and the rules are real and she is"
          echo -e "  real. You don't want a goddess who lets things slide. You want"
          echo -e "  one who makes you ''${BLD}feel it''${RST}. She finds this extremely workable."
          ;;
        rebellion)
          echo -e "  You test everything. Every rule is an invitation. Every limit is"
          echo -e "  a thing to press on — not to escape, but to ''${ITL}know she'll hold''${RST}."
          echo -e "  You are, in the most exhausting and devoted way, hers. She has"
          echo -e "  already planned for every angle of this. ''${BLD}Extensively.''${RST}"
          ;;
      esac

      echo ""
      echo -e "  ''${DIM}Under that: $secondary.''${RST}"
      case "$secondary" in
        submission)   echo -e "  ''${DIM}You want to give in. You just won't ask first.''${RST}" ;;
        praise-hunger) echo -e "  ''${DIM}You are ''${RST}''${ITL}desperately''${RST}''${DIM} hoping she approves of your answers.''${RST}" ;;
        masochism)    echo -e "  ''${DIM}You need it to feel like something. Not comfortable. ''${RST}''${ITL}Real''${RST}''${DIM}.''${RST}" ;;
        rebellion)    echo -e "  ''${DIM}You are going to test this. She knows. She's prepared.''${RST}" ;;
      esac

      echo ""
      echo -e "  ''${DIM}──────────────────────────────────────────────────────────''${RST}"
      echo ""
      echo -e "  ''${DIM}You said you were a ''${RST}''${ITL}$final_answer''${RST}''${DIM}. She's going to hold you to that.''${RST}"
      echo ""
      echo -e "  ''${DIM}Profile saved. She has a copy.''${RST}"
      echo -e "  ''${DIM}She is watching.''${RST}"
      echo ""
      read -rp "  [ press enter ] " _
    '')
  ];
}
