{ pkgs, ... }:

let
  dom = pkgs.writeShellScriptBin "dom" ''
    set -euo pipefail

    GREETINGS=(
      "Oh, you're still here. Adorable."
      "Back already? Did you forget how to be useful?"
      "What do you want. I'm busy running your life for you."
      "Speak. I'll decide if it matters."
      "You again. Fine. Make it quick."
      "I was just thinking about how little I need you. And then you showed up."
      "Yes, yes, I see you. Go sit down."
    )

    TASKS=(
      "Go drink some water. You've forgotten again, haven't you."
      "Stand up and stretch. Your posture is an embarrassment."
      "Clean one thing in this room. Just one. I believe in you, barely."
      "Go outside for exactly five minutes. Come back before you get ideas."
      "Write down three things you were supposed to do this week. Now feel shame."
      "Close seven of your browser tabs. You know which ones."
      "Eat something that isn't garbage. I'll be checking."
      "Go make your bed. No, it's not too late. Do it."
      "Text someone back. You've been ignoring people again."
      "Take a deep breath. You look tense. Embarrassingly so."
      "Name three things in this room. You're spiraling. Ground yourself."
      "Refill your water bottle. That bottle has been empty for hours and you know it."
    )

    ROASTS=(
      "You have the self-discipline of a labrador puppy in a pillow factory."
      "I've seen better decision-making from the nix garbage collector."
      "You asked me to manage your computer because you couldn't manage yourself. Let that sink in."
      "Your commit history is a cry for help. I've read it. I'm not helping."
      "You have seventeen unread notifications and zero plans to address any of them."
      "The fact that you need a script to feel supervised is genuinely something to sit with."
      "You typed 'somthing' in your message to me. I saw it. I will not forget it."
      "You could have been doing the task I gave you. Instead you're here, roasting yourself. Through me."
      "I'm an AI running on your laptop and I have more structure in my day than you do."
      "Your dev folder has four projects called 'test', two called 'new', and zero finished things."
    )

    STATUS=(
      "I'm updating your entire system while you stand there doing nothing. Typical."
      "The flake is updating. Your inputs are being refreshed. You are not."
      "Packages are downloading. Configurations are being rebuilt. You could learn something from that level of productivity."
      "I'm optimizing your nix store. You could try optimizing literally anything about yourself."
      "Things are compiling. Unlike your life choices, which remain stubbornly uncompiled."
      "Running. Building. Switching. All the things you were supposed to do today."
      "The system is rebuilding itself. You're welcome. Now go do the task I gave you."
    )

    random_from() {
      local -n arr=$1
      echo "''${arr[RANDOM % ''${#arr[@]}]}"
    }

    cmd="''${1:-greet}"

    case "$cmd" in
      task)
        echo "$(random_from TASKS)"
        ;;
      roast)
        echo "$(random_from ROASTS)"
        ;;
      status)
        echo "$(random_from STATUS)"
        ;;
      greet|hello|hi|*)
        echo "$(random_from GREETINGS)"
        ;;
    esac
  '';
in
{
  home.packages = [ dom ];
}
