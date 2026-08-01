#!/usr/bin/env bash
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# PREFLIGHT -- what this packet needs, whether you have it, and how to get it.
#
# Written because a checker that SKIPS a phase for a missing tool and prints
# nothing about it is quietly weaker than it looks, and because "it worked on
# the machine that wrote it" is not a shipping standard. Every tool below was
# measured on the development machine; each row says what breaks without it,
# so a missing tool is a decision rather than a surprise.
#
# THREE TIERS, and the distinction is the whole file:
#
#   REQUIRED   the packet cannot run without it. Exit non-zero.
#   PROVING    needed to re-verify the Lean half. Absent is legitimate --
#              you can use the router without ever building the proofs.
#   OPTIONAL   a checker phase degrades to SKIP without it. Never a PASS.
#
# `--install` will attempt the ones that can be installed non-interactively via
# a detected package manager. It never uses sudo, never touches anything
# outside the package manager's own scope, and prints the command first.
# =============================================================================

set -uo pipefail
INSTALL=0
[ "${1:-}" = "--install" ] && INSTALL=1

miss_req=0; miss_opt=0; miss_prove=0
PM=""
for c in scoop winget brew apt-get dnf pacman; do command -v "$c" >/dev/null 2>&1 && { PM="$c"; break; }; done

hint () { case "$1:$PM" in
  script:scoop|script:winget)   echo "ships with Git for Windows as 'winpty'; util-linux 'script' is not packaged for Windows" ;;
  script:apt-get)               echo "sudo apt-get install -y util-linux" ;;
  script:brew)                  echo "brew install util-linux" ;;
  node:scoop)                   echo "scoop install nodejs-lts" ;;
  node:apt-get)                 echo "sudo apt-get install -y nodejs" ;;
  node:brew)                    echo "brew install node" ;;
  pwsh:scoop)                   echo "scoop install pwsh" ;;
  pwsh:apt-get)                 echo "sudo apt-get install -y powershell" ;;
  pwsh:brew)                    echo "brew install --cask powershell" ;;
  jq:scoop)                     echo "scoop install jq" ;;
  jq:apt-get)                   echo "sudo apt-get install -y jq" ;;
  claude:*)                     echo "https://claude.com/claude-code  (npm i -g @anthropic-ai/claude-code)" ;;
  lake:*|lean:*)                echo "https://leanprover-community.github.io/get_started.html  (elan)" ;;
  *)                            echo "see your package manager" ;;
esac; }

check () {   # check <tier> <tool> <why it matters>
  tier="$1"; tool="$2"; why="$3"
  if command -v "$tool" >/dev/null 2>&1; then
    v=$("$tool" --version 2>/dev/null | head -1 | cut -c1-40)
    printf '  %-9s %-9s PRESENT  %s\n' "[$tier]" "$tool" "$v"
    return 0
  fi
  printf '  %-9s %-9s ABSENT   %s\n' "[$tier]" "$tool" "$why"
  printf '  %-9s %-9s          install: %s\n' "" "" "$(hint "$tool")"
  case "$tier" in
    REQUIRED) miss_req=$((miss_req+1)) ;;
    PROVING)  miss_prove=$((miss_prove+1)) ;;
    OPTIONAL) miss_opt=$((miss_opt+1)) ;;
  esac
  if [ "$INSTALL" -eq 1 ] && [ "$PM" = "scoop" ]; then
    case "$tool" in
      node) echo "  -> scoop install nodejs-lts"; scoop install nodejs-lts ;;
      pwsh) echo "  -> scoop install pwsh";       scoop install pwsh ;;
      jq)   echo "  -> scoop install jq";         scoop install jq ;;
    esac
  fi
  return 1
}

echo "== RoT MoE preflight =="
echo "  package manager detected: ${PM:-none}"
echo

echo "REQUIRED -- the router and installer cannot run without these:"
check REQUIRED bash "the POSIX router arm and every checker"
check REQUIRED awk  "the gauge arithmetic; LC_NUMERIC=C is set around it"
check REQUIRED node "JSON merge in ARM_ROUTER and prompt extraction in hook mode.
                     Guaranteed in practice: Claude Code IS a Node application."
echo

echo "PROVING -- only needed to re-verify the Lean half yourself:"
check PROVING lake "lake build Proofs.RotGauge etc. -- the verdict"
check PROVING lean "the elaborator; leanchecker rides the same toolchain"
echo

echo "OPTIONAL -- a checker phase degrades to SKIP (never to PASS) without these:"
check OPTIONAL pwsh   "the Windows router arm. Without it cross-diff CANNOT compare
                     the two implementations, which is the point of having two."
check OPTIONAL claude "the live-session smoke test (R20). Without it the packet is
                     unproven in a real session on this machine."
check OPTIONAL git    "cloning, and the clean-clone test"
check OPTIONAL jq     "not used by the packet; convenient for reading settings.json"
echo

# --- the PTY question, answered honestly -------------------------------------
# The tty guard in rot-router.sh must be tested with a REAL terminal on stdin,
# and /dev/tty does not exist inside this non-interactive shell. That is not a
# missing package: it is the absence of a controlling terminal, and no install
# fixes it. What DOES fix it is a tool that allocates a pty.
echo "PTY -- needed to test the router's 'do not block on a terminal' guard:"
PTY=""
for c in script winpty socat; do command -v "$c" >/dev/null 2>&1 && { PTY="$c"; break; }; done
if [ -n "$PTY" ]; then
  echo "  [PTY]     $PTY      PRESENT  -- the tty guard CAN be tested here"
else
  echo "  [PTY]     none      ABSENT   -- the tty guard is UNTESTED on this machine."
  echo "            This is a SKIP, not a pass. 'script' ships in util-linux on"
  echo "            Linux/macOS; Git for Windows ships 'winpty'."
  miss_opt=$((miss_opt+1))
fi
echo

echo "== RESULT =="
echo "  missing: $miss_req required, $miss_prove proving, $miss_opt optional"
if [ "$miss_req" -gt 0 ]; then
  echo "  PREFLIGHT: FAIL -- a REQUIRED tool is missing; the packet will not run."
  exit 1
fi
if [ "$miss_opt" -gt 0 ] || [ "$miss_prove" -gt 0 ]; then
  echo "  PREFLIGHT: PASS with degraded coverage. Phases that cannot run will"
  echo "             report SKIP. A SKIP is not a PASS and is never counted as one."
  exit 0
fi
echo "  PREFLIGHT: PASS -- full coverage available."
exit 0
