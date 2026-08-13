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

# --- OBSERVABILITY STATE ------------------------------------------------------
# Defaults set HERE, before any use, because gauge() is called from hook mode and
# an unset variable under `set -u` would fail the user's turn over a log field.
_rot_sess=unknown
_rot_proj=''
_rot_src=cli
_rot_local_lost=0

# THE DECLARATION IS READ ON EVERY PATH, not only in hook mode.
#
# MEASURED 2026-08-09, and this was a live contamination hole: `--vector` and
# `--route` exit before the hook-mode block below, so the resolution at "case
# ${ROTMOE_DEBUG_SRC}" was never reached on a CLI invocation. A harness that
# correctly exported ROTMOE_DEBUG_SRC=test and then called `--vector` had its
# gauge record written as src="cli" -- indistinguishable from a real user at a
# terminal. That is the exact defect the field was added to close, surviving in
# a second doorway.
#
# lean/Proofs/RotSessionLog.lean:classify says a declaration OUTRANKS inference.
# A proof binds only the code that consults it; this line is what makes the CLI
# path a place where that theorem has force. Hook mode re-runs the same
# resolution after parsing the payload (infer, THEN declare) so an explicit
# value still wins there -- see src_declaration_wins_on_every_path.
case "${ROTMOE_DEBUG_SRC:-}" in
  test) _rot_src=test ;;
  cli)  _rot_src=cli ;;
  hook) _rot_src=hook ;;
esac

# Start of this invocation, for the `ms` field the ps1 arm has always had and
# this one did not -- the POSIX arm was unmeasurable for latency.
#
# BSD date has no %N: on macOS `date +%s%N` returns a literal trailing "N", so
# the guard below blanks it and `ms` is emitted as -1 meaning NOT MEASURABLE
# HERE. Emitting 0 instead would be a lie at millisecond precision, and a lie
# that reads as "instantaneous" is worse than an honest absence.
_rot_t0=$(date +%s%N 2>/dev/null)
case "$_rot_t0" in (*[!0-9]*|'') _rot_t0='' ;; esac

# Session id -> filename-safe token. The executable twin of `sanitiseSession` in
# lean/Proofs/RotSessionLog.lean; checker/session-log.sh compares the two so they
# cannot drift. `tr -cd` deletes the complement of the allowed set, which is
# removal rather than blacklisting -- no_dot and no_forward_slash are what make
# a session id of "../../etc/passwd" incapable of leaving the directory.
_rot_scrub () {
  _s=$(printf '%s' "${1:-}" | tr -cd 'A-Za-z0-9-' | cut -c1-64)
  [ -n "$_s" ] || _s=unknown
  printf '%s' "$_s"
}

# The per-session project log. Returns a STATUS-PREFIXED path on stdout.
#
# FAILURE TRAVELS ON STDOUT, and it has to. This function is always called as
# `$(_rot_local_file)`, which is a SUBSHELL: a variable set in here is gone the
# moment it returns. Two earlier versions set a flag instead and it never
# reached the marker, so a project sink that could not be created failed in
# total silence.
#
# THE PREFIX IS FIXED-WIDTH, and that is not decoration. The first version used
# a leading '!' meaning "degraded", which is ambiguous the moment a project
# path itself begins with '!' -- measured with cwd="!rel": the decoder ate the
# bang, the record was written to "rel/..." instead of "!rel/...", awk died
# with a fatal redirect error, and the gauge record was lost. A sentinel that
# can occur in the payload is not a sentinel. One status character, always
# present, strips unconditionally, and no path can forge it.
#
#   ""        sink disabled -- not a failure, nothing to report
#   "0<path>" fine
#   "1<path>" usable, but degraded (the .gitignore was not written)
#   "1"       unusable
_rot_local_file () {
  case "${ROTMOE_DEBUG_LOCAL:-}" in
    0) return 0 ;;
    1) : ;;
    *) [ -n "${ROTMOE_DEBUG_LOG:-}" ] || return 0 ;;
  esac
  [ -n "$_rot_proj" ] || return 0
  _d="$_rot_proj/.rot-moe"
  _st=0
  if [ ! -d "$_d" ]; then
    mkdir -p "$_d" 2>/dev/null || { printf '1'; return 0; }
    # Self-ignoring: the router writes into someone else's repository and must
    # not turn up in their `git status`.
    printf '%s\n' '*' > "$_d/.gitignore" 2>/dev/null || _st=1
  fi
  printf '%s%s' "$_st" "$_d/rot-route-$_rot_sess.jsonl"
}

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
# TERMINATE A PARTIAL LINE BEFORE APPENDING -- `RotLogAtomicity.appendSafe`.
#
# If the file ends WITHOUT a newline, some writer was killed mid-record (the
# 1200 ms hook budget did this routinely before it was raised to 18000).
# Appending onto those bytes fuses two records into one line and destroys
# BOTH: `naive_loses_the_next_record` proves the recovered-record count does
# not go up at all, so the interrupted process costs its SUCCESSOR a perfectly
# good record. Closing the line first isolates the fragment and keeps this
# record intact -- `safe_keeps_the_next_record`, +1.
#
# On a healthy file this is a NO-OP: `identical_on_the_healthy_path` proves the
# two writers are the same function when nothing is pending, which is why it is
# safe on the hot path.
#
# TOP LEVEL ON PURPOSE. This lived inside hook_mode at first and guarded only
# the two shell appends -- and the gauge record is written by AWK (`print rec
# >> dbg`), which runs FIRST in the turn. The guard therefore fired after the
# damage, saw a newline-terminated file, and correctly did nothing, while the
# fusion happened one writer earlier. checker/log-integrity.sh caught that: the
# repaired writer recovered 2 records where 1 + 2 = 3 were due. Every sink must
# be terminated before EVERY writer, not before the last one.
#
# Measured before the repair: 409 of 5000 lines unparseable (8.2%), 27 of them
# carrying two `"kind"` keys.
#
# `$(tail -c 1 …)` strips a trailing newline, so the substitution is EMPTY
# exactly when the file already ends in one -- no `wc`, no platform-specific
# padding to sanitise.
_rot_terminate () {
  [ -n "${1:-}" ] || return 0
  [ -s "$1" ] || return 0
  if [ -n "$(tail -c 1 "$1" 2>/dev/null)" ]; then
    printf '\n' 2>/dev/null >> "$1" || return 0
  fi
  return 0
}

# MUTUAL EXCLUSION ACROSS BOTH ARMS -- `RotLogLock.exclusion_forbids_a_split`.
#
# `_rot_terminate` above is the correct repair for a writer KILLED mid-record,
# and under concurrency it is the CAUSE of a second, different corruption. Writer
# B reads the last byte while writer A is still emitting, sees a byte that is not
# a newline BECAUSE A IS MID-RECORD, and injects `\n` inside A's record --
# splitting one valid line into two invalid ones.
#
# Measured on the live sink 2026-08-11: 265 of 5000 lines unparseable (5.3%),
# `gauge` 222 of them. Crucially torn(no closing brace)=0 -- NOTHING was
# truncated, so this is not the killed-writer failure. One line began inside
# another record's array (`{"kens":"Venom"...`); a 1309-byte gauge record was
# mangled at byte 712. `gauge` dominates because it is the longest record
# (~1300 B, nine-lens array) and so holds the window open widest.
#
# The three steps are each atomic; the SEQUENCE was not, and nothing made it so.
# `terminating_is_not_exclusion` proves the existing repair cannot close this:
# both writers terminating still admits the split.
#
# `mkdir` is the primitive because it is the only one BOTH arms share and both
# get atomically from the OS -- it either creates the directory or fails, never
# half-creates. A lock file written with `>` would race exactly like the append
# it is meant to protect.
#
# On contention we REFUSE and record the loss rather than write unlocked:
# `refusing_beats_writing_unlocked` -- a refusal costs 1 record, an unlocked
# write destroys 2, because the split turns one valid line into two invalid ones.
# The loss is flagged, never silent: `a_refusal_is_visible`.
_rot_lock_acquire () {
  [ -n "${1:-}" ] || return 1
  _lk="$1.lock"
  _n=0
  while [ "$_n" -lt 50 ]; do
    if mkdir "$_lk" 2>/dev/null; then return 0; fi
    # A holder that died leaves the directory behind and would disable logging
    # forever. Break it only when it is demonstrably older than any real write,
    # which takes milliseconds -- 30 s is four orders of magnitude of headroom.
    if [ -d "$_lk" ] && [ -z "$(find "$_lk" -maxdepth 0 -newermt '-30 seconds' 2>/dev/null)" ]; then
      rmdir "$_lk" 2>/dev/null || :
    fi
    _n=$((_n + 1))
    sleep 0.02 2>/dev/null || :
  done
  return 1
}

_rot_lock_release () {
  [ -n "${1:-}" ] || return 0
  rmdir "$1.lock" 2>/dev/null || :
  return 0
}

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
  # THE LOOP VARIABLE IS `_fstem`, NOT `_stem`, AND THAT RENAME IS A BUG FIX.
  #
  # The main flow keeps the ROUTED stem in `_stem` (`_stem=${_routed##*|}`) and
  # writes it to the debug record. This loop used the same name. That was
  # survivable only by accident: `fired` was called exclusively from `route`,
  # `route` was called as `$(route ...)`, and the subshell contained the damage.
  #
  # The moment TIER 2 called `fired` from the MAIN shell -- which it must, to
  # count how many lanes match without paying a fork per lane -- the collision
  # became live and EVERY record's stem field became `qed`, the last stem in the
  # FORGE list. cross-diff caught it in one run: "sh 'qed' / ps1 'bug'".
  #
  # Renaming here fixes it at the source, so any future main-shell caller is
  # safe. Saving and restoring `_stem` at the one call site would have worked
  # today and re-armed the trap for the next person.
  _p="$1"; _s="$2"
  MATCHED_STEM=''
  for _fstem in $_s; do
    case "$_fstem" in
      [!a-z0-9]*)
        # punctuation-led stem: plain substring, as before
        case "$_p" in *"$_fstem"*) MATCHED_STEM="$_fstem"; return 0 ;; esac ;;
      *)
        case "$_p" in
          "$_fstem"*)            MATCHED_STEM="$_fstem"; return 0 ;;   # at the very start of the prompt
          *[!a-z0-9]"$_fstem"*)  MATCHED_STEM="$_fstem"; return 0 ;;   # preceded by a non-word character
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

# --- TIER 2: NSIL -- FUSE and ELEVATE ----------------------------------------
# These two were SPECIFIED in rot-lean.md section 3 and NOT IMPLEMENTED. The
# README said so plainly and two theorems pinned it (`fusion_is_unreachable`),
# which is the honest way to carry a gap -- but a gap carried long enough starts
# reading as a design decision. It was not one. This is the implementation.
#
#   FUSE     intent spans two or more domains -> those leads co-activate.
#            Trigger: stems from >= 2 DISTINCT lanes fire on one prompt.
#   ELEVATE  no lane triggers, but the query is dense -> all nine at once,
#            no single lead.
#
# WHY THIS IS SAFE FOR TIER 1. `route` is untouched and still returns exactly
# one lane, so `--route` output, the cross-diff corpus and every lane theorem in
# RotRoute.lean are unaffected. NSIL reads the SAME prompt and decides how many
# lenses the gauge should see. A single-lane prompt produces the identical vector
# it produced before, byte for byte -- verified by the corpus, not assumed.
#
# THE DENSITY FLOOR IS DERIVED, AND I WILL NOT PRETEND IT WAS MEASURED. ELEVATE
# needs "dense", and a bare number in prose is the naked-Nat defect this project
# refuses. The floor is the ROSTER SIZE: a query earns all nine lenses when it
# carries at least one word per lens. That ties the constant to a declared list
# (`NAMES`) instead of to a preference, so adding a tenth lens moves the floor
# automatically. It is a MODELLING CHOICE, not a measurement, and saying which
# it is costs nothing.
#
# Lenses are emitted in ROSTER ORDER, never in match order, so the activity
# vector is canonical and the two arms cannot disagree about bit order.
#
# COST DISCIPLINE, MEASURED THE HARD WAY. The first version of this layer
# returned its result through `$( )` and counted words with `wc -w | tr -d ' '`.
# That is four extra FORKS per turn on a router whose budget is counted in
# spawns (`checker/bench-router.sh:183`), and `bench-router` went red at
# **527.3 ms against the 500 ms bound** the moment it landed. That was not the
# host being slow -- it was this feature being expensive, and the two are only
# distinguishable if you suspect your own change first.
#
# So: these helpers SET GLOBALS instead of printing into a command
# substitution, and nothing here spawns a process. The only exec left is the one
# `tr` for lowercasing, which the router already paid once in `route`.
nsil_active_lenses () {   # <lowercased prompt> -> sets NSIL_ACT, NSIL_N
  _np=$1
  # `fired` sets MATCHED_STEM as a side effect and TIER 1 already consumed it.
  # Save and restore, or the marker's stem field silently becomes the last lane
  # probed here rather than the lane that actually routed. This matters MORE now
  # that there is no subshell to contain the damage.
  _nsil_saved=$MATCHED_STEM
  _nsil_out=''
  fired "$_np" "$STEMS_STRATEGIC"  && _nsil_out="$_nsil_out Nova"
  fired "$_np" "$STEMS_EMPATHIC"   && _nsil_out="$_nsil_out Violet"
  fired "$_np" "$STEMS_CLINICAL"   && _nsil_out="$_nsil_out AntiVenom"
  fired "$_np" "$STEMS_EXECUTIVE"  && _nsil_out="$_nsil_out Venom"
  fired "$_np" "$STEMS_CREATIVE"   && _nsil_out="$_nsil_out Carnage"
  fired "$_np" "$STEMS_PREDICTIVE" && _nsil_out="$_nsil_out Chroma"
  fired "$_np" "$STEMS_STEALTH"    && _nsil_out="$_nsil_out Soleil"
  fired "$_np" "$STEMS_RECURSIVE"  && _nsil_out="$_nsil_out Eidolon"
  fired "$_np" "$STEMS_FORGE"      && _nsil_out="$_nsil_out Claude"
  MATCHED_STEM=$_nsil_saved
  NSIL_ACT=${_nsil_out# }
  NSIL_N=0
  for _nsil_x in $NSIL_ACT; do NSIL_N=$((NSIL_N+1)); done
}

# Word count with ZERO spawns. `set --` inside a function replaces that
# FUNCTION's positional parameters, not the caller's, so this is contained.
#
# `set -f` is not optional and not caution: `set -- $1` word-splits UNQUOTED, so
# a prompt containing `*` would undergo pathname expansion and the "word count"
# would silently become the number of files in the working directory. Globbing
# is disabled across the split and restored immediately after.
nsil_count_words () {
  set -f
  set -- $1
  NSIL_WORDS=$#
  set +f
}

# NSIL_FLOOR is derived from NAMES *after* NAMES exists -- see below the roster
# definition. It CANNOT be computed here: this point in the file is above
# `NAMES=`, so the loop would iterate an empty string and set the floor to 0,
# which makes `words >= floor` true for every prompt and fires ELEVATE on a
# four-word sentence. That is exactly what happened, and `log-replay` caught it
# by disagreeing with the ps1 arm on "some entirely unremarkable sentence".

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

# TIER 2's density floor: one word per lens, COUNTED from the roster above so a
# tenth lens moves it automatically. It must be derived HERE, immediately after
# NAMES -- an earlier draft computed it 25 lines above this point, read an empty
# NAMES, and produced a floor of 0.
NSIL_FLOOR=0
for _rs_x in $NAMES; do NSIL_FLOOR=$((NSIL_FLOOR+1)); done

# ---------------------------------------------------------------------------
# THE SECTION 2 DEFAULT ROSTER -- the table Symbiogenesis is defined over.
#
# LAMBDAS/MUS above are the FORGE PROFILE (section 4) and are what the gauge
# scores a turn with. They are NOT the operands of the merge law. rot-lean.md
# section 3 defines the hybrid over the section 2 DEFAULTS, and the proof agrees:
# `nova_violet_hybrid` in RotEigenform.lean is 33/20 = (1.6 + 1.3)/2 + 0.2, which
# uses Nova 1.6 and Violet 1.3 -- not the FORGE 1.4 and 0.6. Mixing the two
# tables silently produces a hybrid that no theorem describes, which is exactly
# the trap FULL-CHECKLIST.md logged as TRAP 1 before this table existed.
#
# STORED AS HUNDREDTHS, AS INTEGERS, ON PURPOSE. POSIX sh has no float
# arithmetic, and reaching for `awk` would cost a fork per turn on a router
# whose budget is counted in spawns -- the same mistake that put this file 27 ms
# over the bound earlier today. Every value in the law is an exact multiple of
# 0.01, every lambda is a multiple of 0.10 so `(a+b)/2` is always exact, and the
# gains are +0.20 and +0.05. So integer hundredths reproduce the Lean rationals
# EXACTLY -- no rounding, no epsilon, no float comparison anywhere.
#
# H is the UPPER bound of each section 2 range, the convention nova = 7/20 and
# violet = 9/20 already fixed in RotEigenform.lean.
#          Nova Violet AntiV Venom Carn Chroma Soleil Eido Claude
DEF_LAM='  160  130    150   170   110  120    80     140  150'
DEF_MU='   100  95     100   105   120  125    90     110  105'
DEF_H='    35   45     30    28    55   38     22     38   30'

# merge, per rot-lean.md section 3 -- lambda=(l1+l2)/2+0.2, mu=max, H=max+0.05.
# Sets HYB_LAM/HYB_MU/HYB_H in hundredths. No subshell, no external process.
nsil_hybrid () {   # <name1> <name2>
  HYB_LAM=''; HYB_MU=''; HYB_H=''
  _h_i=0; _h_l1=''; _h_l2=''; _h_m1=''; _h_m2=''; _h_h1=''; _h_h2=''
  for _h_n in $NAMES; do
    _h_i=$((_h_i+1))
    if [ "$_h_n" = "$1" ] || [ "$_h_n" = "$2" ]; then
      _h_j=0
      for _h_v in $DEF_LAM; do _h_j=$((_h_j+1)); [ "$_h_j" -eq "$_h_i" ] && { [ -z "$_h_l1" ] && _h_l1=$_h_v || _h_l2=$_h_v; }; done
      _h_j=0
      for _h_v in $DEF_MU;  do _h_j=$((_h_j+1)); [ "$_h_j" -eq "$_h_i" ] && { [ -z "$_h_m1" ] && _h_m1=$_h_v || _h_m2=$_h_v; }; done
      _h_j=0
      for _h_v in $DEF_H;   do _h_j=$((_h_j+1)); [ "$_h_j" -eq "$_h_i" ] && { [ -z "$_h_h1" ] && _h_h1=$_h_v || _h_h2=$_h_v; }; done
    fi
  done
  [ -n "$_h_l2" ] || return 1
  HYB_LAM=$(( (_h_l1 + _h_l2) / 2 + 20 ))
  HYB_MU=$_h_m1;  [ "$_h_m2" -gt "$HYB_MU" ] && HYB_MU=$_h_m2
  HYB_H=$_h_h1;   [ "$_h_h2" -gt "$HYB_H" ]  && HYB_H=$_h_h2
  HYB_H=$((HYB_H + 5))
  return 0
}

# hundredths -> decimal string, builtin printf only (no fork).
hund () { printf '%d.%02d' $(( $1 / 100 )) $(( $1 % 100 )); }

gauge () {   # gauge "a1,..,a9" breadth M C T
  _acts="$1"; _breadth="$2"; _M="$3"; _C="$4"; _T="$5"
  # The second sink is resolved in the shell, not in awk: creating a directory
  # and its .gitignore is not awk's job, and a failure there must not reach the
  # user's transcript. gauge() runs inside a command substitution at the call
  # site, so _rot_local_lost set here does NOT propagate to the marker -- the
  # route record's own attempt is what reports a local-sink failure.
  # gauge() is itself called in a command substitution, so a flag set here can
  # never reach the marker -- the route record's own attempt is what reports a
  # local-sink failure. Only the path is decoded, and an unusable sink becomes
  # the empty string so awk is never handed a path it cannot open.
  _loc_g=$(_rot_local_file)
  case "$_loc_g" in
    '')  : ;;
    1)   _loc_g='' ;;
    0*)  _loc_g=${_loc_g#0} ;;
    1*)  _loc_g=${_loc_g#1} ;;
    *)   _loc_g='' ;;
  esac
  # The gauge record is the FIRST write of the turn, so this is where a dangling
  # fragment must be closed. awk's `print rec >> dbg` cannot inspect the tail
  # byte itself without reopening the file, and doing it here keeps the single
  # implementation of the rule in one place -- see `_rot_terminate` above.
  # THIS is the writer that produced the measured corruption. Of 265 unparseable
  # lines in the live sink, 222 were `kind":"gauge"` -- this record -- because at
  # ~1300 bytes (the nine-lens array) it holds the terminate-then-append window
  # open widest. The route record below is the same composite and only 27 of the
  # 265. Locking the route site alone would have left the main offender open,
  # which the contention control caught: the file still grew by one line.
  #
  # Both sinks are locked here because ONE awk invocation writes both. The order
  # is fixed dbg-then-loc and no other site ever holds two at once, so no cycle
  # exists -- and every acquire is bounded anyway, so contention degrades to a
  # refusal rather than a hang.
  #
  # A sink whose lock we could not take is BLANKED, and awk's own
  # `if (dbg != "")` guard then skips it. Refusing one record beats splitting a
  # neighbour: `RotLogLock.refusing_beats_writing_unlocked`.
  _g_dbg="${ROTMOE_DEBUG_LOG:-}"
  _g_loc="$_loc_g"
  if [ -n "$_g_dbg" ]; then _rot_lock_acquire "$_g_dbg" || _g_dbg=''; fi
  if [ -n "$_g_loc" ]; then _rot_lock_acquire "$_g_loc" || _g_loc=''; fi
  _rot_terminate "$_g_dbg"
  _rot_terminate "$_g_loc"
  printf '%s|%s|%s|%s|%s|%s|%s|%s\n' \
    "$_acts" "$_breadth" "$_M" "$_C" "$_T" "$LAMBDAS" "$MUS" "$NAMES" |
  awk -F'|' -v dbg="$_g_dbg" -v loc="$_g_loc" -v sess="$_rot_sess" -v src="$_rot_src" -v ts="$(date -Is 2>/dev/null || date)" '
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
      # Built once, written to both sinks. Two printf statements would be two
      # places for the schema to drift, and the field order must match the ps1
      # arm exactly or a reader cannot treat the two logs as one stream.
      if (dbg != "" || loc != "") {
        rec = sprintf("{\"kind\":\"gauge\",\"ts\":\"%s\",\"session\":\"%s\",\"src\":\"%s\",\"K\":%d,\"mean\":%s,\"breadth\":%d,\"M\":%s,\"C\":%s,\"T\":%s,\"sum\":%s,\"Rs\":%s,\"active\":\"%s\",\"lenses\":[%s]}",
               ts, sess, src, K, fmt(mean,4), breadth, fmt(M,3), fmt(C,3), fmt(T,3), fmt(sum,5), fmt(R,5), active, terms);
        if (dbg != "") print rec >> dbg;
        if (loc != "") print rec >> loc;
      }
      printf "R/s+ = %s [%s] mean=%s breadth=%d K=%d lenses=%s\n",
             fmt(R, 2), band, fmt(mean, 3), breadth, K, active;
    }'
  # Release in the reverse of the acquire order. A lock left behind would make
  # every later writer wait out its bound and then refuse -- logging would go
  # silent 30 s at a time until the staleness breaker fired.
  [ -n "$_g_loc" ] && _rot_lock_release "$_g_loc"
  [ -n "$_g_dbg" ] && _rot_lock_release "$_g_dbg"
  return 0
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

  # WHICH SESSION, WHICH PROJECT, AND WHERE THE RECORD CAME FROM.
  #
  # Parameter expansion rather than a second node spawn: the hook already costs
  # ~125 ms and is registered on 31 events, so a second interpreter per event
  # would be paid 31 times a turn.
  case "$payload" in
    *'"session_id"'*)
      _rot_sess=${payload#*\"session_id\"}
      _rot_sess=${_rot_sess#*\"}
      _rot_sess=${_rot_sess%%\"*}
      ;;
  esac
  _rot_sess=$(_rot_scrub "$_rot_sess")

  case "$payload" in
    *'"cwd"'*)
      _rot_proj=${payload#*\"cwd\"}
      _rot_proj=${_rot_proj#*\"}
      _rot_proj=${_rot_proj%%\"*}
      ;;
  esac
  # JSON escapes a Windows separator, so "C:\Users\x" arrives doubled. Left as
  # forward slashes, which every shell and PowerShell on this platform accept.
  # tr, NOT sed. With | as the sed delimiter the escaped-backslash pattern is
  # ambiguous across implementations, and checker/portability.sh refuses it:
  # a strip that fails OPEN on BSD would leave separators in a value that
  # reaches a directory path. tr has no delimiter to collide with.
  _rot_proj=$(printf '%s' "$_rot_proj" | tr '\\' '/')
  [ -n "$_rot_proj" ] || _rot_proj=$PWD

  # PROVENANCE -- `classify` in lean/Proofs/RotSessionLog.lean. Inference first,
  # then an explicit declaration overrides it, and ONLY for the three known
  # values: unknown_declaration_falls_back proves a typo demotes to inference
  # rather than inventing a fourth class.
  case "$payload" in *'"hook_event_name"'*) _rot_src=hook ;; esac
  case "${ROTMOE_DEBUG_SRC:-}" in
    test) _rot_src=test ;;
    cli)  _rot_src=cli ;;
    hook) _rot_src=hook ;;
  esac

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

  # TIER 2 (NSIL) decides how many lenses this turn activates. TIER 1's lane is
  # already fixed and is not revisited here.
  #
  # BREADTH IS NOW COUNTED, NOT ASSIGNED, and that is the substantive change.
  # The old line set `_br=1` next to the bit it had just written, so the field
  # was an ASSERTION about the vector rather than a MEASUREMENT of it -- true
  # only while exactly one bit could ever be set. `RotLensActivation.lean` proved
  # that assignment honest, but only under a distinct-names hypothesis, and
  # `a_duplicated_name_makes_the_assignment_undercount` showed it lying the
  # moment the hypothesis failed. Counting the bits removes the hypothesis
  # entirely: breadth is the number of ones because it is computed from them.
  nsil_active_lenses "$(printf '%s' "$prompt" | tr 'A-Z' 'a-z')"
  _nsil_act=$NSIL_ACT
  _nsil_n=$NSIL_N
  nsil_count_words "$prompt"
  _nsil_words=$NSIL_WORDS
  _nsil_floor=$NSIL_FLOOR
  # NOVA ADJUDICATES EVERY TURN -- THE DEFAULT IS `CONFIRM`, NOT "no decision".
  #
  # rot-lean.md section 3: NSIL's verdict "beats TIER 1", and CONFIRM is the
  # verdict meaning "the keyword match agrees with the real intent, so the TIER 1
  # lead stands". A single-lane turn is therefore NOT a turn where NSIL was
  # absent -- it is a turn Nova let through. The first draft of this block left
  # the field EMPTY on those turns, which encoded the opposite: that the layer
  # had never run. That is an architectural falsehood, and it is the kind that
  # survives because the output looks identical either way.
  #
  # The visible marker still shows nothing for CONFIRM, deliberately: CONFIRM
  # means the lane you can already see is the answer, so a tag would add bytes
  # and no information. The VERDICT is recorded in the route record instead,
  # where it is auditable -- see the `nsil` field below.
  NSIL_DECISION='CONFIRM'
  if [ "$_nsil_n" -ge 2 ]; then
    NSIL_DECISION='FUSE'
    # NSIL IS NOVA'S LAYER -- the name is not decoration. rot-lean.md section 3:
    # "TIER 2 -- NSIL (Nova Sovereign Intent Layer). Nova reads true intent along
    # six axes." A FUSE decision therefore is not something that happened NEAR
    # Nova, it is something Nova DID. Leaving her bit at 0 on a turn she
    # adjudicated would make the vector describe a fusion that nobody decided.
    #
    # So Nova joins the active set BY CONSTRUCTION, not by preference. This is
    # also the answer to the routing question underneath: a fused turn must not
    # be one lens leading the rest, it is several lenses contributing a point of
    # view with Nova reading the intent across them. Nova is idempotent here --
    # if STRATEGIC was one of the lanes that fired, the set is unchanged and
    # breadth 2 is still reachable.
    case " $_nsil_act " in *" Nova "*) : ;; *) _nsil_act="Nova $_nsil_act" ;; esac
  elif [ "$_nsil_n" -eq 0 ] && [ "${_nsil_words:-0}" -ge "$_nsil_floor" ]; then
    NSIL_DECISION='ELEVATE'
    _nsil_act=$NAMES
  else
    # Exactly one lane fired, or none and the prompt is not dense. Either way the
    # vector is what it has always been: the routed lens alone, or -- on
    # CONVERGENT, whose "lens" is the convener MODEL name and matches no roster
    # entry -- all zeros with breadth 0. Unchanged, deliberately.
    _nsil_act=$_lens
  fi

  # SYMBIOGENESIS, EVALUATED. When exactly two lenses fused, the merge law has a
  # defined answer and the router can now state it -- the section 2 default table
  # above is the piece that was missing, not the law, which RotEigenform.lean has
  # proved over ℚ all along.
  #
  # Deliberately NOT computed for three or more. rot-lean.md section 3 defines
  # the hybrid over TWO leads, and folding pairwise would add +0.2 per fold
  # (+0.4 at three lenses, +0.6 at four) -- an escalation no theorem sanctions.
  # That is a spec question for the Socio, not a default to be invented by
  # whichever code path happened to run first. Silence here is the honest answer
  # until it is decided.
  NSIL_HYB=''
  if [ "$NSIL_DECISION" = 'FUSE' ]; then
    _hy_n=0; _hy_a=''; _hy_b=''
    for _hy_x in $_nsil_act; do
      _hy_n=$((_hy_n+1))
      [ "$_hy_n" -eq 1 ] && _hy_a=$_hy_x
      [ "$_hy_n" -eq 2 ] && _hy_b=$_hy_x
    done
    if [ "$_hy_n" -eq 2 ] && nsil_hybrid "$_hy_a" "$_hy_b"; then
      NSIL_HYB=$(printf ',"hybrid":{"pair":"%sx%s","lam":%s,"mu":%s,"h":%s}' \
        "$_hy_a" "$_hy_b" "$(hund "$HYB_LAM")" "$(hund "$HYB_MU")" "$(hund "$HYB_H")")
    fi
  fi

  _vec=''; _br=0
  for _n in $NAMES; do
    _on=0
    for _a in $_nsil_act; do [ "$_a" = "$_n" ] && _on=1; done
    if [ "$_on" -eq 1 ]; then _vec="$_vec,1"; _br=$((_br+1)); else _vec="$_vec,0"; fi
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
    # WHICH EVENT PRODUCED THIS RECORD -- added 2026-08-08.
    #
    # The router is now registered on ELEVEN lifecycle events, and until this
    # field existed the debug log could not tell you which one fired. Six
    # records from a live session were indistinguishable: three gauges and three
    # routes, with no way to know whether they came from SessionStart, a tool
    # call, or Stop. That makes the central claim of the wiring -- that the
    # router observes the whole session -- UNFALSIFIABLE FROM THE LOG, which is
    # the same defect class this project hunts everywhere else.
    #
    # Parsed with parameter expansion rather than a second `node` process: the
    # hook already costs ~125 ms and a second interpreter spawn would roughly
    # double it on every event, eleven times per turn.
    #
    # THE CHARSET GUARD IS LOAD-BEARING, not decoration. This value is
    # interpolated into a JSON record; a payload carrying a quote or a brace in
    # that field would emit a malformed line and corrupt the log for every
    # reader downstream, including checker/log-replay.sh. Anything that is not
    # plain letters is refused and recorded as "-", which is honest: it says a
    # record was written and the event was not identifiable.
    _ev='-'
    case "$payload" in
      *'"hook_event_name"'*)
        _ev=${payload#*\"hook_event_name\"}
        _ev=${_ev#*\"}
        _ev=${_ev%%\"*}
        ;;
    esac
    case "$_ev" in (*[!A-Za-z]*|'') _ev='-' ;; esac
    # LATENCY. The ps1 arm has always emitted `ms` and this one never did, so
    # the POSIX arm could not be compared against it. -1 is not a duration: it
    # means this platform has no sub-second clock (BSD date has no %N), and it
    # is emitted rather than 0 because a 0 would read as "instantaneous".
    _ms=-1
    if [ -n "$_rot_t0" ]; then
      _t1=$(date +%s%N 2>/dev/null)
      case "$_t1" in (*[!0-9]*|'') _t1='' ;; esac
      [ -n "$_t1" ] && _ms=$(( (_t1 - _rot_t0) / 1000000 ))
    fi

    # Field order is byte-for-byte the ps1 arm's, so both logs parse as one
    # stream and cross-diff compares like with like.
    # `nsil` carries NOVA'S VERDICT ON EVERY TURN -- CONFIRM, FUSE or ELEVATE --
    # so a reader can tell a lane that was adjudicated and upheld from one that
    # was never examined. `breadth` rides with it because the two are only
    # meaningful together: FUSE with breadth 2 and FUSE with breadth 4 are
    # different turns, and the visible marker deliberately shows nothing at all
    # for CONFIRM.
    _rec=$(printf '{"kind":"route","ts":"%s","event":"%s","session":"%s","src":"%s","lane":"%s","lens":"%s","Rs":"%s","chars":%s,"stem":"%s","nsil":"%s","breadth":%s%s,"arm":"sh","ms":%s}' \
         "$(date -Is 2>/dev/null || date)" "$_ev" "$_rot_sess" "$_rot_src" "${lane%% *}" "$_lens" "$_rs" "${#prompt}" "$_stem" "$NSIL_DECISION" "$_br" "$NSIL_HYB" "$_ms")

    # The partial-line guard is `_rot_terminate`, defined at TOP LEVEL near
    # `convener` -- it has to be reachable by the awk gauge writer too, which
    # runs before this one. Both sinks are terminated again here because the
    # gauge write may itself have been interrupted between then and now.

    # SECOND SINK first: it must not be behind the central sink's success, or a
    # user with an unwritable central log would silently lose the local one too.
    #
    # The decode runs HERE, in the main shell, and that placement is the whole
    # point. Twice the failure flag was set inside a command substitution and
    # died there. A subshell cannot report to its parent except through stdout.
    _loc=$(_rot_local_file)
    case "$_loc" in
      '')  : ;;
      1)   _rot_local_lost=1; _loc='' ;;
      0*)  _loc=${_loc#0} ;;
      1*)  _rot_local_lost=1; _loc=${_loc#1} ;;
      *)   _rot_local_lost=1; _loc='' ;;
    esac
    if [ -n "$_loc" ]; then
      # The lock spans terminate+append together: splitting them is the defect.
      if _rot_lock_acquire "$_loc"; then
        _rot_terminate "$_loc"
        printf '%s\n' "$_rec" 2>/dev/null >> "$_loc" || _rot_local_lost=1
        _rot_lock_release "$_loc"
      else
        _rot_local_lost=1
      fi
    fi

    if _rot_lock_acquire "$ROTMOE_DEBUG_LOG"; then
      _rot_terminate "$ROTMOE_DEBUG_LOG"
      _rot_wrote=0
      printf '%s\n' "$_rec" 2>/dev/null >> "$ROTMOE_DEBUG_LOG" && _rot_wrote=1
      _rot_lock_release "$ROTMOE_DEBUG_LOG"
    else
      # Contended past the bound: refuse and MARK it. `_dbg_lost` is the flag the
      # marker actually reads (consumed by the lost-record branch further down);
      # an invented name here would be an alarm that cannot fire.
      #
      # That branch's message string is deliberately NOT repeated in any comment:
      # checker/debug-channel.sh plants a copy with the marker deleted and then
      # asserts it is gone, so a second textual occurrence anywhere in this file
      # makes the control unable to prove anything. Measured -- the first draft
      # of this comment quoted it and turned the control red.
      _rot_wrote=0
      _dbg_lost=1
    fi
    if [ "$_rot_wrote" = 1 ]
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
  # BOTH SINKS REPORT. `_rot_local_lost` was set in three places and read in
  # none -- an alarm that cannot fire, which is worse than no alarm because it
  # reads like coverage. The project sink can fail for reasons the central one
  # cannot: a read-only checkout, a directory the user owns but the agent does
  # not, a full disk on a different volume. Silence there would look exactly
  # like a session that produced no records.
  #
  # The central marker stays BYTE-IDENTICAL so cross-diff keeps comparing the
  # same string; the project marker is a separate, additive suffix.
  _mark=""
  [ "$_dbg_lost" -eq 1 ] && _mark="$_mark | debug-log UNWRITABLE (record lost)"
  [ "$_rot_local_lost" -eq 1 ] && _mark="$_mark | project-log UNWRITABLE (record lost)"
  # A TIER 2 decision is shown INSIDE the lane field, which is the segment the
  # contract defines as pipe-free (`live-session-smoke.sh:481` matches
  # `-> (LANE) [^|]*\| R/s\+`). Appending here therefore keeps every existing
  # assertion matching -- the prefix, the lane token and the ` | R/s+ ` boundary
  # are all untouched -- while making the fusion VISIBLE rather than burying it
  # in a debug record. A capability the user cannot see on the line is a
  # capability they have to take on faith.
  # NAME THE PARTICIPANTS, not just the count. "x3" says three lenses spoke
  # without saying which, which is the same diminishment as printing only the
  # lead lane: the reader cannot tell a fusion of Nova+Violet from Nova+Venom.
  # The roster-ordered list is short, pipe-free, and it is the actual evidence.
  _nsil_tag=""
  if [ -n "$NSIL_DECISION" ] && [ "$NSIL_DECISION" != "CONFIRM" ]; then
    _nsil_names=''
    for _a in $_nsil_act; do _nsil_names="$_nsil_names+$_a"; done
    _nsil_tag=" [NSIL $NSIL_DECISION ${_nsil_names#+}]"
  fi
  echo "RoT MoE :: TIER 1 -> $lane$_nsil_tag | R/s+ $_rs$_mark"
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
