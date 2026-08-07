#!/usr/bin/env sh
# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# rot-router.sh -- the RoT MoE router, POSIX arm.
#
# Two jobs, and the second one is new:
#
#   TIER 1  keyword routing -> a mode and its lead lens.
#   GAUGE   the R/s+ divergence figure over nine measured lens activities.
#
# WHY TIER 1 IS HERE AT ALL. Grepping the PowerShell that ships today for the
# mode names finds them only in a comment and in payload text: TIER 1 routing
# was SPECIFIED and never implemented. The gauge is what shipped. That gap is
# why lean/Proofs/RotRoute.lean says, in its own docstring, that it models the
# spec rather than running code -- and this file is what closes it. The
# priority order below is the one RotRoute.lean proves total, exhaustive and
# free of dead lanes.
#
# THE LOCALE TRAP IS NOT OPTIONAL. The PowerShell formats every number with
# InvariantCulture (rot-lean-inject.ps1:406-415). Under a comma-decimal locale
# "0.09" renders "0,09", the decimal separator collides with the field
# separator, and the injected vector becomes unparseable. LC_NUMERIC=C is the
# POSIX equivalent and it is set below, unconditionally, before any arithmetic.
#
# DETERMINISTIC MODE, and it is what makes cross-diffing possible at all:
#   rot-router.sh --vector a1,..,a9 --breadth N [--M x --C y --T z]
#   rot-router.sh --route "some prompt text"
# Both print one line and read nothing from disk, so the two implementations
# can be run over an identical corpus and compared byte for byte.
# =============================================================================

LC_ALL=C
LC_NUMERIC=C
export LC_ALL LC_NUMERIC

# --- TIER 1 ------------------------------------------------------------------
# Stems are case-insensitive substrings, quoted from rot-lean.md section 3.
# `code` (CLINICAL) and `art` (CREATIVE) are deliberately ABSENT: on a prover
# head `code` matches nearly every prompt and would pin the router to CLINICAL
# permanently, collapsing the tier into a constant; `art` collides with
# `.artifact`/`artifacts` paths. That deletion is a routing choice and it is
# disclosed here for the same reason the FORGE additions are.
#
# ORDER IS THE CONTRACT, not the word list. FORGE first: on this head the Lean
# stems are the common case. route_exact in RotRoute.lean characterises every
# lane in both directions against exactly this order.
# `prove proof lemma lean qed` joined in 0.7.0. MEASURED before the change, on
# the shipped router: "prove this lemma" -> CONVERGENT, and "prove the read loop
# conserves bytes in lean" -> STEALTH (it matched `byte`). On a prover head the
# two most proof-shaped prompts imaginable reached every lane except FORGE.
# They could not be added until `fired` matched word prefixes; see the note
# there, and RotStem.firesWord for why that was the prerequisite rather than a
# refinement.
STEMS_FORGE='run build install deploy reproduce ship lake theorem tactic sorry mathlib .lean prove proof lemma lean qed'
STEMS_CLINICAL='debug error bug fix secur audit verif test cve segfault crash panic leak regress traceback'
STEMS_EXECUTIVE='decid urgenc strike direct declar now conclud'
STEMS_EMPATHIC='emot feel grief lonel soul story human tired lost'
STEMS_STRATEGIC='strateg plan goal roadmap priorit legal recommend analyz'
STEMS_CREATIVE='creativ chaos surreal disrupt paradox dream invent'
STEMS_PREDICTIVE='futur scenar predict trend forec likel horizon next'
STEMS_STEALTH='encod optim token compress concise byte distill'
STEMS_RECURSIVE='evolv recurs meta architect refactor ontolog hybrid'

# CONVERGENT is the only lane with no lead LENS -- by design, it is the lane
# where all nine co-reason and none leads. It used to print the literal "none",
# and that reads as a null: as though the router had failed to decide, rather
# than decided that nobody leads.
#
# What actually convenes the nine on that lane is the MODEL the user chose. So
# that is what is named. `opus[1m]` and `sonnet` produce different lines, which
# is correct -- the convener is genuinely different.
#
# MEASURED, not assumed (live UserPromptSubmit payload captured 2026-08-03):
#   session_id, transcript_path, cwd, prompt_id, permission_mode,
#   hook_event_name, prompt
# There is NO `model` key in the payload. So it is read from the settings file
# the user's own client writes, and every step degrades instead of failing:
# env override -> settings.json -> the literal "model". The last fallback is
# still a word, never "none" and never an empty string, because a hook that
# emits an empty lead is worse than one that emits a generic one.
convener () {
  if [ -n "$ROTMOE_MODEL" ]; then printf '%s' "$ROTMOE_MODEL"; return 0; fi
  _cfg="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"
  if [ -r "$_cfg" ]; then
    # One line, one field, no JSON parser: the value of a top-level "model".
    _m=$(tr -d '\n' < "$_cfg" | sed -n 's/.*"model"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
    if [ -n "$_m" ]; then printf '%s' "$_m"; return 0; fi
  fi
  printf 'model'
}

# A STEM MUST START A WORD. Until 0.7.0 this was a plain substring test, and
# that is why `prove`, `proof` and `lemma` could not be added to the FORGE list:
# `prove` occurs inside "improve", `lemma` inside "dilemma", `lean` inside
# "cleaning". The same flaw was already live for stems that shipped long ago --
# `fix` fires on "prefix", `now` on "known", `test` on "latest" -- and had been
# routing prompts onto the wrong lane for as long as the table existed.
#
# The rule: a stem matches at the start of the prompt, or immediately after a
# character that is not alphanumeric. So "proofs" and "prover" still fire (a stem
# is a word PREFIX, which is what `verif` -> "verification" and `strateg` ->
# "strategy" have always relied on) while "improve" does not.
#
# NOT "proving" -- and the difference is worth stating because the first draft of
# this comment got it wrong. `prove` is not a prefix of "proving" (p-r-o-v-i-n-g
# breaks at the fifth character), so it never fired under EITHER matcher. The
# executable example at RotStem.lean:386 pins that, which is how the mistake was
# found: the spec disagreed with the prose and the spec was right.
#
# THE EXCEPTION, and it is why `.lean` still works: a stem that itself begins
# with a non-alphanumeric character falls back to the substring test, because
# "basic.lean" has no word boundary before the dot.
#
# Proved in lean/Proofs/RotStem.lean. `firesWord_imp_fires` is the statement that
# made this safe to ship: word-prefix firing IMPLIES substring firing, for every
# prompt and every stem class, so the change can only ever remove a false
# positive -- it cannot invent a match and move a prompt onto a lane it was never
# reaching. `firesWord_strictly_weaker` proves it is not vacuous.
#
# MATCHED_STEM: WHY THE ROUTER NOW SAYS *WHICH* STEM FIRED.
#
# The debug log records `chars`, never the prompt -- a log has to be safe to
# paste into an issue. The cost of that, measured by trying to diagnose a
# mis-route from a log: the lane is recorded and the REASON is not, so a report
# of "my proof prompt routed CONVERGENT" is undiagnosable. Everything the log
# carries can be checked and none of it explains the decision.
#
# A stem is the missing datum and it is safe to record, which is the whole point:
# stems come from a CLOSED SET defined in this file, above. Emitting one leaks
# nothing about the user's text beyond which fixed vocabulary word appeared --
# and that is precisely what the routing decision is.
#
# It also makes the decision CHECKABLE from the log alone: the fired lane must be
# the one lane whose table owns that stem. That catches a mis-wired table, a stem
# duplicated across lanes, and a lane firing with a stem it does not own.
# Specified in lean/Proofs/RotLog.lean.
fired () {   # fired "<lowercased prompt>" "<stem list>" -> 0 if any stem starts a word
  _p="$1"; _s="$2"
  MATCHED_STEM=''
  for _stem in $_s; do
    case "$_stem" in
      [!a-z0-9]*)
        # punctuation-led stem: plain substring, as before
        case "$_p" in *"$_stem"*) MATCHED_STEM="$_stem"; return 0 ;; esac ;;
      *)
        case "$_p" in
          "$_stem"*)            MATCHED_STEM="$_stem"; return 0 ;;   # at the very start of the prompt
          *[!a-z0-9]"$_stem"*)  MATCHED_STEM="$_stem"; return 0 ;;   # preceded by a non-word character
        esac ;;
    esac
  done
  return 1
}

# route emits "<LANE LENS>|<matched stem>". The separator is the LAST `|`, so a
# convener model name containing one cannot swallow the stem. Callers that must
# print the lane alone -- `--route`, whose output the cross-diff compares between
# the two arms byte for byte -- strip the suffix; nothing about that output moved.
route () {
  _p=$(printf '%s' "$1" | tr 'A-Z' 'a-z')
  if   fired "$_p" "$STEMS_FORGE";      then _lane="FORGE Claude"
  elif fired "$_p" "$STEMS_CLINICAL";   then _lane="CLINICAL AntiVenom"
  elif fired "$_p" "$STEMS_EXECUTIVE";  then _lane="EXECUTIVE Venom"
  elif fired "$_p" "$STEMS_EMPATHIC";   then _lane="EMPATHIC Violet"
  elif fired "$_p" "$STEMS_STRATEGIC";  then _lane="STRATEGIC Nova"
  elif fired "$_p" "$STEMS_CREATIVE";   then _lane="CREATIVE Carnage"
  elif fired "$_p" "$STEMS_PREDICTIVE"; then _lane="PREDICTIVE Chroma"
  elif fired "$_p" "$STEMS_STEALTH";    then _lane="STEALTH Soleil"
  elif fired "$_p" "$STEMS_RECURSIVE";  then _lane="RECURSIVE Eidolon"
  else                                       _lane="CONVERGENT $(convener)"; MATCHED_STEM=''
  fi
  printf '%s|%s\n' "$_lane" "$MATCHED_STEM"
}

# --- THE GAUGE ---------------------------------------------------------------
# Ported line for line from rot-lean-inject.ps1:357-416 and proved against
# lean/Proofs/RotGauge.lean. The lens order is fixed and load-bearing: the
# corpus, the PowerShell and this file must agree on which slot is which lens.
#
# LENS ORDER: Nova Violet AntiVenom Venom Carnage Chroma Soleil Eidolon Claude
# FORGE weights, quoted from rot-lean.md section 4, never re-derived here.
LAMBDAS='1.4 0.6 1.9 1.2 0.6 1.0 1.0 1.2 2.3'
MUS='1.05 0.85 1.10 1.05 0.90 1.10 0.95 1.10 1.15'
NAMES='Nova Violet AntiVenom Venom Carnage Chroma Soleil Eidolon Claude'

gauge () {   # gauge "a1,..,a9" breadth M C T
  _acts="$1"; _breadth="$2"; _M="$3"; _C="$4"; _T="$5"
  printf '%s|%s|%s|%s|%s|%s|%s|%s\n' \
    "$_acts" "$_breadth" "$_M" "$_C" "$_T" "$LAMBDAS" "$MUS" "$NAMES" |
  awk -F'|' -v dbg="${ROTMOE_DEBUG_LOG:-}" -v ts="$(date -Is 2>/dev/null || date)" '
    # Match PowerShell ToString("0.##"): round, then strip trailing zeros and a
    # bare trailing dot. 0.90 -> "0.9", 1.00 -> "1", 0.09 -> "0.09".
    # Formatting is part of the observable: the cross-diff compares these
    # STRINGS byte for byte, which is precisely what catches a locale bug.
    function fmt(x, d,   s) {
      s = sprintf("%." d "f", x)
      if (s ~ /\./) { sub(/0+$/, "", s); sub(/\.$/, "", s) }
      return s
    }
    {
      n = split($1, a, ",");
      breadth = $2 + 0; M = $3 + 0; C = $4 + 0; T = $5 + 0;
      split($6, lam, " "); split($7, mu, " "); split($8, nm, " ");

      K = n;
      mean = 0; for (i = 1; i <= n; i++) mean += a[i] + 0;
      mean = mean / K;

      sum = 0; active = "";
      for (i = 1; i <= n; i++) {
        act = a[i] + 0;
        if (act > 0) active = (active == "" ? nm[i] : active "," nm[i]);
        d  = act - mean; if (d < 0) d = -d;          # delta from ensemble mean
        s  = 1.0 / (1.0 + exp(-4.0 * (d - 0.5)));    # sigmoid, slope 4, centre 0.5
        H  = (breadth > 0 ? act / breadth : 0.0);    # share of the turn breadth
        if (H > 1.0) H = 1.0;
        term = lam[i] * s * (1.0 + H) * mu[i] * M * C * T;
        sum += term;
        if (dbg != "") {
          terms = terms (terms == "" ? "" : ",") \
            sprintf("{\"lens\":\"%s\",\"lambda\":%s,\"mu\":%s,\"a\":%s,\"delta\":%s,\"sigma\":%s,\"H\":%s,\"term\":%s}",
                    nm[i], fmt(lam[i],3), fmt(mu[i],3), fmt(act,3), fmt(d,4), fmt(s,4), fmt(H,4), fmt(term,5));
        }
      }
      R = sum / K;
      band = (R < 0.9 ? "BELOW RANGE" : (R > 1.8 ? "ABOVE RANGE" : "IN RANGE (0.9-1.8)"));
      if (active == "") active = "none";
      # DEBUG LOG -- one JSON line carrying every factor of the sum, so the
      # reported R/s+ can be recomputed by hand from the record. A summary
      # cannot show that a lens was multiplied by the wrong mu or never
      # participated; this can. Logging must never break a turn, so the write
      # is appended with >> and any failure is swallowed by the caller.
      if (dbg != "") {
        printf "{\"kind\":\"gauge\",\"ts\":\"%s\",\"K\":%d,\"mean\":%s,\"breadth\":%d,\"M\":%s,\"C\":%s,\"T\":%s,\"sum\":%s,\"Rs\":%s,\"active\":\"%s\",\"lenses\":[%s]}\n",
               ts, K, fmt(mean,4), breadth, fmt(M,3), fmt(C,3), fmt(T,3), fmt(sum,5), fmt(R,5), active, terms >> dbg;
      }
      printf "R/s+ = %s [%s] mean=%s breadth=%d K=%d lenses=%s\n",
             fmt(R, 2), band, fmt(mean, 3), breadth, K, active;
    }'
}

# --- HOOK MODE ---------------------------------------------------------------
# THE DEFECT THIS EXISTS TO FIX, recorded because it is the most useful thing
# in this file.
#
# The router shipped with --vector and --route and NOTHING ELSE. ARM_ROUTER
# registers it as a hook command with no arguments, so every real invocation hit
# the usage branch and exited 2. The hook fired on every turn and did nothing.
#
# lake build was green. leanchecker was green. The cross-diff agreed byte for
# byte on 49 rows. The installer round trip was byte-identical. The mutation
# suite killed 10 of 10. ALL OF IT WAS GREEN while the shipped hook errored on
# every single turn -- because none of those instruments RUNS the hook the way
# Claude Code runs it. Only an executed session found it, which is exactly why
# R20 exists.
#
# Claude Code sends the invoking event as JSON on STDIN (measured in the shipped
# PowerShell at rot-lean-inject.ps1:119-128, which reads it via
# [Console]::In.ReadToEnd() guarded by IsInputRedirected). Hook mode is
# therefore the DEFAULT: no arguments means "you were called as a hook".
hook_mode () {
  # Never block. A terminal on stdin means a human ran this by hand, and reading
  # unconditionally would hang forever -- the same trap leanchecker --help falls
  # into. The guard is not optional.
  if [ -t 0 ]; then
    echo "rot-router.sh: hook mode expects a JSON payload on stdin." >&2
    echo "  try: rot-router.sh --route \"some text\"" >&2
    exit 2
  fi
  payload=$(cat)
  [ -z "$payload" ] && exit 0     # nothing to route; silence is correct

  # Extract the prompt. node gives an exact parse and is GUARANTEED here --
  # Claude Code is itself a Node application, so anything that can invoke this
  # hook can run node. The sed path is a degraded fallback and is labelled as
  # one rather than presented as equivalent: it cannot handle escaped quotes,
  # and it scans the whole payload, so a stem appearing in some other field
  # (a cwd containing "lake", say) would route on it. Benign, but not the same.
  if command -v node >/dev/null 2>&1; then
    prompt=$(printf '%s' "$payload" | node -e '
      let s=""; process.stdin.on("data",d=>s+=d).on("end",()=>{
        // MEASURED DEFECT, 2026-08-03: this read `j.prompt || j.tool_name` only.
        // On UserPromptSubmit that is right. On PreToolUse the payload carries no
        // prompt, so the router saw the bare tool NAME -- "Bash", "Edit", "Read",
        // "Grep" -- and not one of those matches any stem. Every autonomous
        // firing therefore returned CONVERGENT, measured on all four. The half of
        // the router that watches what the MODEL decided to do carried no signal
        // at all, while looking perfectly healthy in the log.
        // The fix reads what the tool is actually DOING. A Bash invoking the
        // Lean build tool is FORGE work; a Bash searching a log for the word
        // error is CLINICAL work; the tool name alone cannot tell them apart.
        // Command, file path and pattern are the fields that carry the intent.
        //
        // NOTE ON WORDING, and it is not fussiness: this comment deliberately
        // NAMES no toolchain binary next to a backtick. checker/hook-footprint.sh
        // forbids a Lean invocation in a shipped hook and matches COMMAND
        // POSITION -- and in shell, a backtick followed by that name IS command
        // substitution. The checker cannot know this block is JavaScript. It
        // caught an earlier draft of this very comment, which is the rule
        // working, so the prose moved rather than the rule.
        try { const j=JSON.parse(s);
          const ti = j.tool_input || {};
          const act = [ti.command, ti.file_path, ti.path, ti.pattern, ti.description]
                        .filter(x => typeof x === "string").join(" ");
          process.stdout.write(String(j.prompt || (act ? (j.tool_name||"") + " " + act : j.tool_name) || "")); }
        catch(e) { process.stdout.write(""); }
      });' 2>/dev/null)
  else
    prompt=$(printf '%s' "$payload" | sed -n 's/.*"prompt"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
    [ -z "$prompt" ] && prompt="$payload"
  fi

  _routed=$(route "$prompt")
  lane=${_routed%|*}
  _stem=${_routed##*|}

  # README.md:77 promises this line carries "a named lane AND A GAUGE READING".
  # For a long time it carried the lane only, and the comment that used to sit
  # here defended that: a single hook invocation has not measured nine lens
  # activities, and emitting a fabricated vector would be worse than emitting
  # none. The first half of that is still true. The conclusion was wrong.
  #
  # The router HAS measured something by this point: WHICH LANE FIRED. Expressed
  # as an activity vector that is one-hot -- the lead lens of the fired lane at
  # 1, every other lens at 0, breadth 1. That is not an invented profile, it is
  # this turn's routing decision written in the gauge's own units, and it is
  # reproducible by hand -- WITH THE SAME M, C AND T, which is the whole point
  # of writing them out:
  #   rot-router.sh --vector 0,0,0,0,0,0,0,0,1 --breadth 1 --M 1 --C 1 --T 1
  #     -> R/s+ = 0.66,  which is exactly what the hook line prints for FORGE.
  # An earlier draft of this comment cited 0.7, the figure the CLI prints when
  # it falls back to its OWN defaults (T = 0.8, not 1.0). Same vector, different
  # scalars, different number -- and a reproduction command that does not
  # reproduce is worse than none, because the reader concludes the gauge is
  # unstable rather than that the instructions were incomplete. Measured both
  # ways before this line was written.
  # A CONVERGENT turn fires no lens, so its vector is all zeros with breadth 0
  # and the gauge is defined there too (0.16 under these scalars). Every lane
  # therefore has a reading, and none of them is guessed.
  #
  # M, C and T are the neutral element 1.0 -- NOT measurements dressed up as
  # defaults. Memory residue, confidence calibration and temporal recency are
  # genuinely unavailable to one stateless hook call, so they are set to the
  # value that leaves the product unchanged, and this comment is where that is
  # admitted rather than buried.
  #
  # The lens index comes from NAMES itself, so adding or renaming a lens moves
  # this automatically. A second hard-coded lane->index table would be a
  # snapshot waiting to drift out of step with the first one.
  _lens=${lane#* }
  _vec=''; _br=0; _i=1
  for _n in $NAMES; do
    if [ "$_n" = "$_lens" ]; then _vec="$_vec,1"; _br=1; else _vec="$_vec,0"; fi
    _i=$((_i+1))
  done
  _vec=${_vec#,}

  # PREFLIGHT THE DEBUG CHANNEL ONCE, BEFORE ANY WRITER TOUCHES IT.
  #
  # Measured 2026-08-07: this log has TWO writers, not one -- the awk in
  # `gauge` emits `"kind":"gauge"`, and the block below emits `"kind":"route"`.
  # Patching only the second left the first printing
  #     awk: ... fatal: cannot redirect to `...': No such file or directory
  # straight into the user's session. One channel gets ONE test and ONE marker
  # bit, which is also what lean/Proofs/RotDebugLog.lean models: `observe`
  # returns a single `marker`, not one per writer.
  #
  # `: >> file` appends nothing and creates the file if it can, so it is a
  # writability probe with no record cost and no risk of a partial line.
  _dbg_lost=0
  if [ -n "${ROTMOE_DEBUG_LOG:-}" ]; then
    if : 2>/dev/null >> "$ROTMOE_DEBUG_LOG"; then
      :
    else
      # Unwritable. Blank the variable so the awk writer never attempts it --
      # a hook must not spray a fatal into a transcript over a debug file.
      _dbg_lost=1
      ROTMOE_DEBUG_LOG=''
    fi
  fi

  _rs=$(gauge "$_vec" "$_br" 1 1 1 | sed -n 's|^R/s+ = \([0-9.][0-9.]*\).*|\1|p')
  [ -z "$_rs" ] && _rs='n/a'
  # One record per ROUTED TURN, matching the ps1 arm's shape so the two logs are
  # comparable. `chars` not the prompt: a debug log must be safe to paste into
  # an issue, and the decision is what is under test, not the user's text.
  # DEBUG CHANNEL. Governed by lean/Proofs/RotDebugLog.lean, which proves three
  # things this block must satisfy:
  #
  #   * the write stays TOLERANT -- a debug file must never fail a user's turn,
  #     so `|| true` is deliberate and stays;
  #   * a LOST append must leave a mark -- `lost_evidence_is_always_marked`.
  #     Without it, "the router never fired" and "the router fired and the log
  #     was unwritable" produce identical evidence (`silent_channel_is_ambiguous`,
  #     and `..._at_every_volume` for any traffic level). That is the same
  #     missing-evidence class as the twelve fake RotGauge kills;
  #   * the file is BOUNDED, discarding the OLDEST -- `rotate_keeps_the_newest`.
  #     Keeping the front instead is refuted by `taking_the_front_loses_the_newest`.
  #     Not hypothetical: ~/.claude holds a 1.4 GB and a 1.1 GB log written by
  #     the same unbounded append pattern.
  #
  # The marker goes to the router's OWN stdout, not to a sidecar file: if the
  # log path is unwritable, a file beside it very likely is too, and a marker
  # that can fail the same way as the thing it reports is not a marker.
  if [ -n "${ROTMOE_DEBUG_LOG:-}" ]; then
    # `2>/dev/null` comes BEFORE the append on purpose. Redirections are applied
    # left to right, and the "No such file or directory" for a failed `>>` is
    # emitted by the SHELL, not by printf -- with the order reversed it escapes
    # to the transcript before stderr has been silenced. Measured, not assumed.
    if printf '{"kind":"route","ts":"%s","lane":"%s","lens":"%s","Rs":"%s","chars":%s,"stem":"%s","arm":"sh"}\n' \
         "$(date -Is 2>/dev/null || date)" "${lane%% *}" "$_lens" "$_rs" "${#prompt}" "$_stem" \
         2>/dev/null >> "$ROTMOE_DEBUG_LOG"
    then
      # Bound the file. `tail -n` keeps the LAST cap lines, which is the
      # `rotate` of the Lean module: drop from the front, retain the newest.
      _cap="${ROTMOE_DEBUG_LOG_MAX:-5000}"
      case "$_cap" in (*[!0-9]*|'') _cap=5000 ;; esac
      if [ "$_cap" -gt 0 ] 2>/dev/null; then
        # BSD `wc -l` PADS ITS OUTPUT: macOS returns "      24", not "24".
        # The guard below used to reject anything non-numeric and fall back to
        # 0 -- so on macOS the count was always 0, the comparison was always
        # false, and ROTATION NEVER RAN. Measured in CI run 31202010565: the log
        # grew to 24 lines against a cap of 5 while ubuntu and windows passed,
        # because GNU wc emits no padding. A sanitiser written to be defensive
        # is what silently disabled the feature on one platform.
        #
        # `tr -dc` keeps only digits, which handles the padding without having
        # to know which wc is present -- the same reasoning as the step-log
        # probe: do not encode the other side's formatting, tolerate it.
        _n=$(wc -l < "$ROTMOE_DEBUG_LOG" 2>/dev/null | tr -dc '0-9')
        [ -n "$_n" ] || _n=0
        if [ "$_n" -gt "$_cap" ]; then
          _tmp="$ROTMOE_DEBUG_LOG.rot.$$"
          if tail -n "$_cap" "$ROTMOE_DEBUG_LOG" > "$_tmp" 2>/dev/null; then
            mv -f "$_tmp" "$ROTMOE_DEBUG_LOG" 2>/dev/null || rm -f "$_tmp" 2>/dev/null || true
          else
            rm -f "$_tmp" 2>/dev/null || true
          fi
        fi
      fi
    else
      _dbg_lost=1
    fi
  fi
  if [ "$_dbg_lost" -eq 1 ]; then
    echo "RoT MoE :: TIER 1 -> $lane | R/s+ $_rs | debug-log UNWRITABLE (record lost)"
  else
    echo "RoT MoE :: TIER 1 -> $lane | R/s+ $_rs"
  fi
  exit 0
}

# --- entry point -------------------------------------------------------------
[ $# -eq 0 ] && hook_mode

MODE=""; VEC=""; BREADTH=0; M=1.05; C=1.0; T=1.0; PROMPT=""

# A FLAG WITHOUT ITS VALUE MUST REFUSE, NOT SPIN.
# Measured 2026-08-01: `rot-router.sh --vector` (no value) ran until it was
# killed at 120 s. Not a stdin block, as it first appeared -- an INFINITE LOOP.
# With `$# = 1`, `shift 2` fails and shifts nothing, `$1` is still `--vector`,
# and the `while` re-enters the same branch forever. Every option below had the
# same shape. This is the R20 defect's family: an argument path that no test
# exercised because the hook is normally called with no arguments at all.
need_value () {   # need_value <flag> <count-remaining>
  if [ "$2" -lt 2 ]; then
    echo "rot-router.sh: $1 requires a value" >&2
    echo "usage: rot-router.sh --vector a1,..,a9 --breadth N [--M x --C y --T z]" >&2
    echo "       rot-router.sh --route \"prompt text\"" >&2
    exit 2
  fi
}
while [ $# -gt 0 ]; do
  case "$1" in
    --vector)  need_value "$1" $#; MODE=gauge; VEC="$2";     shift 2 ;;
    --breadth) need_value "$1" $#; BREADTH="$2";             shift 2 ;;
    --M)       need_value "$1" $#; M="$2";                   shift 2 ;;
    --C)       need_value "$1" $#; C="$2";                   shift 2 ;;
    --T)       need_value "$1" $#; T="$2";                   shift 2 ;;
    --route)   need_value "$1" $#; MODE=route; PROMPT="$2";  shift 2 ;;
    --version) echo "rot-router.sh 1.0.0"; exit 0 ;;
    *) echo "usage: rot-router.sh --vector a1,..,a9 --breadth N [--M x --C y --T z]" >&2
       echo "       rot-router.sh --route \"prompt text\"" >&2
       exit 2 ;;
  esac
done

case "$MODE" in
  gauge) gauge "$VEC" "$BREADTH" "$M" "$C" "$T" ;;
  # `route` now returns "<LANE LENS>|<stem>"; --route prints the lane ALONE, so
  # its output is byte-identical to every earlier version and the cross-diff
  # against the ps1 arm compares the same string it always did.
  route) _routed=$(route "$PROMPT"); echo "${_routed%|*}" ;;
  *)     echo "rot-router.sh: no mode given (--vector or --route)" >&2; exit 2 ;;
esac
