# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# prover-remind.nu -- ORGAN 4, Nushell arm: the proof-debt reminder.
#
# Port of hooks/prover-remind.ps1 (678 lines). The PowerShell arm stays the
# reference: checker/cross-diff-remind.sh drives `--decide` over a corpus and
# requires BYTE-IDENTICAL output on every row, so every string below is
# transcribed from the ps1 verbatim, not paraphrased.
#
# NEVER THROWS, ALWAYS EXITS 0 in hook mode. `--decide` may exit 2 on a usage
# error: a checker calling it wrongly must not silently pass.
#
# THREE PORT DECISIONS, EACH MEASURED ON THIS HOST (nu 0.115.0), NOT ASSUMED:
#
#  1. BOUNDED `lake build`. The ps1 uses Start-Job + Wait-Job -Timeout. GNU
#     `timeout` is on PATH here (C:\Program Files\Git\usr\bin\timeout.exe) and
#     was the obvious substitute -- it does NOT work: `timeout 2 cmd /c ping
#     -n 10` returned exit 0, never 124. It cannot kill a Windows child. What
#     does work is nu's own job mailbox: `job spawn` the build, have the child
#     `| job send 0`, and `job recv --timeout` in the parent. Measured: the
#     bound trips, `job kill` reaps the child, and `job flush` before spawning
#     stops a message from a previous build leaking in as this build's verdict.
#
#  2. NO STRING INTERPOLATION ANYWHERE IN THE VERDICT TEXT. Nushell's $"..."
#     treats `(` as the start of an expression, and this file's contract
#     strings are full of literal parens -- `module(s):`, `(last: X)`,
#     `(exit 0, 1287ms)`. `$"...module(s)..."` parses `(s)` as a call to a
#     command named `s`. Every verdict is therefore built with `+` over
#     single-quoted literals. Uglier, and the only spelling that cannot
#     silently corrupt the one thing the cross-arm diff checks.
#
#  3. MINUTES ARE ROUNDED, NOT FLOORED. The ps1 casts a TotalMinutes double
#     with [int], which is round-half-to-even, not truncation. `//` in nu
#     floors, which would report one minute less than the ps1 for most of
#     every minute. `math round` matches on everything except an exact .5
#     boundary (half-even vs half-up), which no clock lands on twice.
# =============================================================================

# THE KNOWN NON-ANSWERS, defined once and shared by every consumer below.
# A reason matching this says the re-check NEVER COMPLETED, not that the kernel
# refused a proof. Matched by SHAPE because the producer emits parameterised
# text ("TIMEOUT after 300s", "LAUNCH_FAILED: <msg>"). Reasons are uppercased
# before matching, so a case-sensitive `=~` here is the same test the ps1's
# case-insensitive `-match` performs on already-uppercased input.
const UNFINISHED_PAT = '^TIMEOUT\b|^NOT_FOUND\b|^LAUNCH_FAILED\b|BAD_ALLOC|OUT OF MEMORY|INTERNAL PANIC|FAILED TO READ FILE'

# additionalContext is accepted on only SOME events. Wiring this hook to an
# event is not permission to speak on it: emitting on the rest logged
# "Hook JSON output validation failed - (root): Invalid input" every fire.
const CTX_EVENTS = ['PreToolUse' 'PostToolUse' 'PostToolBatch' 'SessionStart' 'UserPromptSubmit' 'UserPromptExpansion']

def get-env-or [name: string, fallback: string]: nothing -> string {
    let v = ($env | get -o $name | default '')
    if (($v | into string) | str trim | is-empty) { $fallback } else { $v | into string }
}

# HOME, ON EVERY PLATFORM. The ps1 carries the measurement: USERPROFILE does
# not exist outside Windows and Join-Path REFUSES a null Path, which killed the
# whole script at config time on ubuntu-latest before it parsed an argument.
def home-dir []: nothing -> string {
    let up = ($env | get -o USERPROFILE | default '')
    if not ($up | is-empty) { return $up }
    let h = ($env | get -o HOME | default '')
    if not ($h | is-empty) { return $h }
    '.'
}

# The literal path is tried FIRST and the drive-letter reading only as a
# fallback: on Linux `/c/...` is an ordinary absolute path and must win.
# Preferring what EXISTS over what a rule says should exist is the only
# version that cannot break the other platform.
def resolve-recorded-path [v: string]: nothing -> string {
    if ($v | str trim | is-empty) { return '' }
    let p = ($v | str replace --all '\' '/')
    if ($p | path exists) { return $p }
    let m = ($p | parse --regex '^/(?P<d>[A-Za-z])/(?P<rest>.*)$')
    if (($m | length) > 0) {
        let win = (($m | get 0.d | str uppercase) + ':/' + ($m | get 0.rest))
        if ($win | path exists) { return $win }
    }
    ''
}

def get-recorded-workspace [state_dir: string]: nothing -> string {
    let f = ($state_dir | path join 'workspace')
    if not ($f | path exists) { return '' }
    let raw = (try { open --raw $f | lines | get -o 0 | default '' } catch { '' })
    resolve-recorded-path ($raw | str trim)
}

def test-lean-workspace [d: string]: nothing -> bool {
    if ($d | str trim | is-empty) { return false }
    if not (($d | path join 'Proofs') | path exists) { return false }
    (($d | path join 'lakefile.toml') | path exists) or (($d | path join 'lakefile.lean') | path exists)
}

# DISCOVERY -- nothing in the plugin install path writes the recorded file, so
# the middle step of the chain is permanently empty for a marketplace install.
# Ask the filesystem instead. Both layouts are accepted: the workspace itself,
# and a project keeping Lean in a `lean/` subdirectory.
def get-discovered-workspace []: nothing -> string {
    mut d = (get-env-or 'ROTMOE_CWD' ($env.PWD? | default '.'))
    for _ in 0..7 {
        if ($d | str trim | is-empty) { break }
        if (test-lean-workspace $d) { return $d }
        let sub = ($d | path join 'lean')
        if (test-lean-workspace $sub) { return $sub }
        let p = ($d | path dirname)
        if (($p | is-empty) or ($p == $d)) { break }
        $d = $p
    }
    ''
}

# Resolution order: env -> RECORDED -> DISCOVERED -> our own shipped corpus.
# The bundled fallback is last and is the one that cannot accuse (see W5).
def resolve-config []: nothing -> record {
    let here = (($env.CURRENT_FILE? | default '.') | path dirname)
    let state_dir = (get-env-or 'ROTMOE_STATE_DIR' ((home-dir) | path join '.local/state/rot-moe'))
    let ws_env = (get-env-or 'ROTMOE_LEAN_WORKSPACE' '')
    let ws_rec = (if ($ws_env | is-empty) { get-recorded-workspace $state_dir } else { '' })
    let ws_dis = (if (($ws_env | is-empty) and ($ws_rec | is-empty)) { get-discovered-workspace } else { '' })
    let src = (if not ($ws_env | is-empty) { 'env'
        } else if not ($ws_rec | is-empty) { 'recorded'
        } else if not ($ws_dis | is-empty) { 'discovered'
        } else { 'bundled' })
    let ws = (if not ($ws_env | is-empty) { $ws_env
        } else if not ($ws_rec | is-empty) { $ws_rec
        } else if not ($ws_dis | is-empty) { $ws_dis
        } else { $here | path join '..' 'lean' })
    {
        here: $here
        ws: $ws
        ws_source: $src
        proofs_dir: ($ws | path join 'Proofs')
        state_dir: $state_dir
        watch_repo: (get-env-or 'ROTMOE_WATCH_REPO' '.')
        goal_file: (get-env-or 'ROTMOE_GOAL_FILE' '')
        stale_min: ((get-env-or 'ROTMOE_PROOF_STALE_MIN' '45') | into int)
        debt_ext: ((get-env-or 'ROTMOE_DEBT_EXT' 'rs c h cpp hpp go ts js py java kt swift') | split row --regex '\s+')
        risk_re: (get-env-or 'ROTMOE_DEBT_PATTERN' 'as u8|as u16|as u32|as i8|as i16|as i32|as usize|saturating_|wrapping_|checked_|\.clamp\(|\.max\(|\.min\(|<<|>>|MAX_|MIN_|_CAP|_FLOOR|_LIMIT')
    }
}

# THE PROOF SCAN, IN ONE PLACE. Hook mode and --measure must not each carry
# their own copy: the one-level scan survived in the ps1 precisely because the
# only thing exercising the measurement was hook mode, and nothing compared it
# to anything. Recursion lives INSIDE this function -- one level deep meant
# that once proofs were filed by subject the newest visible file was whatever
# last landed in the root (measured on one tree: one level -> 2947 min stale,
# recursive -> 54 min).
#
# TWO NUSHELL TRAPS, BOTH MEASURED HERE, BOTH SILENT. The first spelling was
# `ls ($proofs_dir | path join '**' '*.lean')` and it returned ZERO files
# against a tree the ps1 arm scans 324 files in:
#
#   1. `path join` uses the platform separator, so on Windows it produced
#      `D:/Lean/proofs/Proofs\**\*.lean` -- and a backslash inside a glob is an
#      ESCAPE, not a separator. The pattern is built with '/' for that reason.
#   2. `ls $var` treats a string variable as a LITERAL PATH and refuses to
#      expand it: `No matches found for DoNotExpand(...)`. Globbing from a
#      variable requires `into glob`.
#
# Neither throws. Together they returned count 0 / mins -1, which Invoke-Decide
# words as "No .lean proofs found in the configured workspace" -- a confident,
# wrong, perfectly green answer about a corpus that is right there. Verified
# after the fix: 324 files, newest stem Compressor, and `**/` does cover files
# sitting directly in Proofs/ (324 recursive vs 103 direct-only), so the
# one-level scan defect the ps1 header documents cannot come back this way.
def get-proof-scan [proofs_dir: string]: nothing -> record {
    let pat = ($proofs_dir + '/**/*.lean')
    let all = (try { ls ($pat | into glob) } catch { [] })
    if (($all | length) == 0) { return { count: 0, mins: -1, last: '-' } }
    let newest = ($all | sort-by modified | last)
    let mins = (((date now) - $newest.modified) / 1min | math round | into int)
    { count: ($all | length), mins: $mins, last: ($newest.name | path parse | get stem) }
}

def split-csv [s: string]: nothing -> list<string> {
    if (($s | is-empty) or ($s == '-')) { return [] }
    $s | split row ',' | where { |it| $it =~ '\S' }
}

def join-first-n [items: list<string>, n: int]: nothing -> string {
    $items | take $n | str join ','
}

# --- DECIDE ------------------------------------------------------------------
# A PURE function of measured inputs, mirroring the ps1 clause for clause and
# word for word. Field order is the contract: preamble, kernel, sorry, debt,
# staleness, alarms, method. Returns null for silence.
def invoke-decide [
    event: string, mins: int, last_in: string, debt: string,
    kred: string, ksorry: string, alarms: int, stale_min: int
]: nothing -> any {
    let last = (if ($last_in == '-') { '' } else { $last_in })
    let d = (split-csv $debt)
    let r = (split-csv $kred)
    let s = (split-csv $ksorry)
    let nd = ($d | length)
    let nr = ($r | length)
    let ns = ($s | length)

    # SILENCE. The kernel conditions are ANDed in deliberately: a rejected
    # proof term or a stray `sorry` breaks silence no matter how fresh the
    # last proof is.
    if (($nd == 0) and ($mins >= 0) and ($mins < $stale_min) and ($nr == 0) and ($ns == 0)) {
        return null
    }

    mut out = (if ($event == 'PreToolUse') {
        'BEFORE YOU ACT: this is the one moment a proof obligation can change the action rather than judge it. If what you are about to do touches a bound, a cast or a clamp, decide NOW whether it needs a theorem -- deciding afterwards is how debt accumulates.'
    } else if ($event == 'UserPromptSubmit') {
        'THE SOCIO JUST SPOKE -- re-read the goal before assuming it is unchanged. Carry the standing proof debt into whatever was just asked; a new instruction does not retire an open obligation.'
    } else {
        'RESULT IS IN -- attribute it. A green build is elaboration, not truth; bind the measurement to a theorem or say plainly that it is MEASURED, not PROVED.'
    })

    # Split the watchdog's red list into modules the kernel actually REJECTED
    # and modules whose re-check never finished (trailing `?`). A timeout
    # reported as a rejection is a false accusation.
    let nonempty = ($r | where { |t| not ($t | is-empty) })
    let rej_list = ($nonempty | where { |t| not ($t | str ends-with '?') })
    let unf_list = ($nonempty | where { |t| $t | str ends-with '?' } | each { |t| $t | str replace --regex '\?$' '' })
    let nrej = ($rej_list | length)
    let nunf = ($unf_list | length)

    if ($nrej > 0) {
        $out = $out + ' KERNEL REJECTED ' + ($nrej | into string) + ' module(s): ' + (join-first-n $rej_list 4) + '. leanchecker disagrees with lake build -- those theorems are NOT proved. Fix before anything else.'
    }
    if ($nunf > 0) {
        $out = $out + ' KERNEL RE-CHECK DID NOT FINISH for ' + ($nunf | into string) + ' module(s): ' + (join-first-n $unf_list 4) + '. A TIMEOUT IS NOT A REJECTION and it is not a pass either -- the question was never answered. Re-run lake env leanchecker on those modules with a longer bound before believing anything about them.'
    }
    if ($ns > 0) {
        $out = $out + ' SORRY PRESENT in: ' + (join-first-n $s 4) + '. A sorry is an admission, never a result -- report it with a count.'
    }
    if ($nd > 0) {
        let more = (if ($nd > 4) { ' (+' + (($nd - 4) | into string) + ' more)' } else { '' })
        $out = $out + ' LEAN DEBT: ' + ($nd | into string) + ' uncommitted source file(s) carry cast/clamp/saturating/bound code -- ' + (join-first-n $d 4) + $more + '.'
        $out = $out + ' For EACH: state in writing what must hold for ALL inputs, then PROVE it or say plainly there is no universal claim.'
    }
    if ($mins >= $stale_min) {
        $out = $out + ' No proof written for ' + ($mins | into string) + ' min (last: ' + $last + ').'
    } else if ($mins < 0) {
        $out = $out + ' No .lean proofs found in the configured workspace -- verify ROTMOE_LEAN_WORKSPACE before assuming none exist.'
    }
    if ($alarms > 0) {
        $out = $out + ' ' + ($alarms | into string) + ' alarm row(s) open in the goal file; an alarm closes ONLY with instrument + negative control.'
    }
    $out = $out + ' Close a proof with THREE instruments: lake build (exit code read DIRECTLY, never through a pipe) -> #print axioms (sorryAx = NOT proved; no axioms at all is usually vacuous) -> lake env leanchecker <Module> (kernel recheck; exit 0 with ZERO bytes = pass, a module with no oleans exits 1 = the control). Then MUTATE, delete the stale .olean, rebuild, confirm the theorems DIE. Zero sorry. Never native_decide. A test SAMPLES; a theorem SETTLES.'

    # ASCII guard at the single exit point: a non-ASCII byte under a legacy
    # code page can terminate the JSON string early and kill the injection.
    $out | str replace --all --regex '[^\x20-\x7E]' ' '
}

# Read the kernel watchdog's status file and classify it. ONE reader, two
# callers (--kernel and hook mode); two copies would drift, and the drift
# would be exactly the kind nobody notices until an alarm lies again.
def read-kernel [state_dir: string]: nothing -> record {
    let vs = ($state_dir | path join 'lean-verify-status.json')
    if not ($vs | path exists) { return { red: [], sorry: [] } }
    let v = (try { open --raw $vs | from json } catch { null })
    if ($v == null) { return { red: [], sorry: [] } }
    let red = (try {
        ($v | get -o red | default []) | each { |it|
            let m = ($it | get -o module | default '' | into string)
            let rs = (($it | get -o reason | default '' | into string) | str uppercase)
            if ($rs =~ $UNFINISHED_PAT) { $m + '?' } else { $m }
        }
    } catch { [] })
    let sf = (try { ($v | get -o sorryFiles | default []) | each { |it| $it | into string } } catch { [] })
    { red: $red, sorry: $sf }
}

# --- THE HOOK INVOKES LEAN ---------------------------------------------------
# ...WHEN LEAN WORK HAS JUST HAPPENED, AND ONLY THEN. Measured in the ps1:
# router 176 ms, one module no-op 1206 ms, whole corpus 4850 ms. Building on
# every prompt and every tool call would cost a fifty-call session one to four
# MINUTES for verdicts that barely change.
#
# Silent -- never broken -- when lake is absent, when the build cannot be
# bounded, or when ROTMOE_LEAN_VERIFY=0. An optional dependency that breaks
# the hook when missing is not optional.
def invoke-lean-verify [payload: any, ws: string]: nothing -> string {
    if ($payload == null) { return '' }
    if ((get-env-or 'ROTMOE_LEAN_VERIFY' '1') == '0') { return '' }
    if ((which lake | length) == 0) { return '' }

    let ti = ($payload | get -o tool_input)
    if ($ti == null) { return '' }
    let fp_raw = ($ti | get -o file_path | default ($ti | get -o path | default ''))
    let fp = ($fp_raw | into string)
    if ($fp | is-empty) { return '' }
    if not ($fp | str ends-with '.lean') { return '' }
    if not ($ws | path exists) { return '' }

    let ws_abs = ($ws | path expand)
    let norm = ($fp | str replace --all '\' '/')
    let wsn = ($ws_abs | str replace --all '\' '/')
    let rel = (if ($norm | str starts-with ($wsn + '/')) {
        $norm | str substring (($wsn | str length) + 1)..
    } else {
        let m = ($norm | parse --regex '/lean/(?P<r>.+)$')
        if (($m | length) > 0) { $m | get 0.r } else { '' }
    })
    if ($rel | is-empty) { return '' }
    let module = (($rel | str replace --regex '\.lean$' '') | str replace --all '/' '.')
    if ($module | is-empty) { return '' }

    let secs = ((get-env-or 'ROTMOE_LEAN_VERIFY_SECS' '300') | into int)
    let t0 = (date now)
    # A message left over from an earlier build would otherwise be received as
    # THIS build's verdict. Measured: without the flush, a prior job's record
    # is returned immediately and the wrong module is reported.
    job flush
    let jid = (job spawn {
        let r = (do { cd $ws_abs; ^lake build $module } | complete)
        { out: (($r.stdout | into string) + ($r.stderr | into string)), code: $r.exit_code } | job send 0
    })
    # WHAT THIS BOUND DOES AND DOES NOT DO -- MEASURED, because the honest
    # limit matters more than the comforting one.
    #
    # DOES: return the TIMED OUT verdict at the bound, and exit the nu process
    # at the bound. Measured with a 25s child and a 2s bound: verdict emitted
    # and process gone at 2117ms.
    #
    # DOES NOT: kill the external build. `job kill` ends the nu job thread; the
    # `lake` process it spawned keeps running. The ps1 arm's Stop-Job tears
    # down a whole job process and does terminate it -- that is a real
    # difference between the arms, not a cosmetic one. Two consequences,
    # both measured: an orphaned build finishes in the background, and while
    # it lives it holds an inherited handle on the output pipe, so a reader
    # waiting for EOF (rather than for process exit) sees the verdict at the
    # bound but does not see the stream close until the orphan ends -- 2.1s to
    # first byte, 24.2s to EOF, on the fixture above.
    #
    # NOT PAPERED OVER WITH A TREE-KILL, because the tree-kill does not work:
    # nu's `ps` reports NO process whose ppid is $nu.pid for this child, so
    # there is nothing to walk. Killing by image name would kill a build the
    # user started by hand, which is worse than the leak.
    #
    # THE BOUND THAT ACTUALLY GOVERNS IS THE WIRING'S. This hook is registered
    # at timeout 18000, and ROTMOE_LEAN_VERIFY_SECS defaults to 300: any build
    # slow enough to reach the internal bound was killed by Claude Code 282
    # seconds earlier. Set ROTMOE_LEAN_VERIFY_SECS BELOW the registered hook
    # timeout or the internal bound is decoration.
    let msg = (try { job recv --timeout ($secs * 1sec) } catch { null })
    if ($msg == null) {
        try { job kill $jid }
        return ('LEAN TIMED OUT: ' + $module + ' did not finish in ' + ($secs | into string) + 's. NOT proved -- a build you killed is not a verdict.')
    }
    let ms = ((((date now) - $t0) / 1ms) | math round | into int)
    let out = ($msg.out | into string)
    let code = ($msg.code | into int)

    # A file may contain `sorry` and still elaborate. Reporting that as a pass
    # is the exact laundering this project exists to prevent, so it is a THIRD
    # state. This used to scan the file's TEXT and cried wolf: a doc comment
    # reading "no sorry, no native_decide" was counted as an admission. Ask the
    # ELABORATOR instead -- it knows a term from a word in a comment, and its
    # warning is per-DECLARATION, which is the honest unit.
    let sry = ($out | lines | where { |l| $l =~ 'declaration uses .sorry.' } | length)

    if ($code != 0) {
        let errs = ($out | lines | where { |l| $l =~ 'error:' })
        let err_raw = (if (($errs | length) > 0) { $errs | get 0 | str trim } else { '<no error line captured>' })
        let err = (if (($err_raw | str length) > 200) { $err_raw | str substring 0..200 } else { $err_raw })
        return ('LEAN REFUSED: ' + $module + ' does NOT build (lake build exit ' + ($code | into string) + ', ' + ($ms | into string) + 'ms). First error: ' + $err + ' -- this is not proved. Fix it before the code is called delivered.')
    }
    if ($sry > 0) {
        return ('LEAN INCOMPLETE: ' + $module + ' builds (exit 0, ' + ($ms | into string) + 'ms) but contains ' + ($sry | into string) + ' sorry. A sorry is an ADMISSION, not a proof -- the module is not done.')
    }
    ('LEAN VERIFIED: ' + $module + ' builds, lake build exit 0 in ' + ($ms | into string) + 'ms, zero sorry. Elaboration is not truth -- close it with #print axioms (sorryAx = not proved) and lake env leanchecker ' + $module + '.')
}

# UNCOMMITTED SOURCE THAT IS PROOF-SHAPED. The ps1 does Push-Location and runs
# git cwd-relative; `-C` is the same measurement without mutating the caller's
# location, which matters here because a hook shares its process with nothing
# and must leave no state behind.
def scan-debt [cfg: record]: nothing -> list<string> {
    let repo = $cfg.watch_repo
    let a = (do { ^git -C $repo diff --name-only --diff-filter=ACM } | complete)
    if ($a.exit_code != 0) { return [] }
    let b = (do { ^git -C $repo diff --cached --name-only --diff-filter=ACM } | complete)
    let changed = ((($a.stdout | lines) ++ ($b.stdout | lines)) | where { |l| not ($l | str trim | is-empty) } | uniq)
    $changed | each { |rel|
        let ext = ($rel | path parse | get extension)
        if not ($ext in $cfg.debt_ext) { return null }
        let full = ($repo | path join $rel)
        if not ($full | path exists) { return null }
        let hit = (try { open --raw $full | lines | any { |l| $l =~ $cfg.risk_re } } catch { false })
        if $hit { $rel | path basename } else { null }
    } | compact
}

def count-alarms [goal_file: string]: nothing -> int {
    if ($goal_file | is-empty) { return 0 }
    if not ($goal_file | path exists) { return 0 }
    try {
        open --raw $goal_file | lines | where { |l| $l =~ '^>\s*\|\s*\*{0,2}R\d+[a-z]?\*{0,2}\s*\|' } | length
    } catch { 0 }
}

export def main [
    --decide            # deterministic mode: EVENT MINS LASTPROOF DEBT KRED KSORRY ALARMS
    --measure           # count, minutes and name, off disk
    --workspace         # which step of the chain answered, and the path
    --kernel            # the classified kernel verdict, as <red>|<sorry>
    --version
    ...rest: string
] {
    # THE PIPELINE INPUT IS CAPTURED HERE, ON THE FIRST LINE, AND THE POSITION
    # IS LOAD-BEARING. `$in` inside a `try { }` block resolves to THAT BLOCK's
    # input -- which is null -- not to the command's pipeline input. The first
    # draft read `$in` inside the hook-mode try and so parsed nothing on every
    # single fire.
    #
    # It did not look broken. With no payload the event falls back to its
    # 'PostToolUse' default, and the whole staleness path needs no payload, so
    # a PostToolUse fire produced byte-identical output to the ps1 arm for
    # entirely the wrong reason. It was a SessionEnd payload that exposed it:
    # the ps1 arm emitted 0 bytes (schema gate), this arm emitted 724 bytes
    # labelled `hookEventName: PostToolUse` and burned two stamps. A parity
    # test that only ever fires the default event cannot see this.
    let stdin_raw = (try { $in | into string } catch { '' })

    if $version { print 'prover-remind.nu 1.0.0'; return }

    # AN UNKNOWN ARGUMENT MUST REFUSE, NOT BE SWALLOWED. The ps1 carries the
    # measurement: `-Event '*'` exited 0 with ZERO bytes and looked fine, while
    # the POSIX arm exited 2. A hook that exits 0 having done nothing is
    # indistinguishable from a hook that worked, which is the false green this
    # project exists to hunt. Nushell rejects an undeclared --flag itself; this
    # covers stray POSITIONALS, which it would otherwise hand over silently.
    if ((not ($decide or $measure or $workspace)) and (($rest | length) > 0)) {
        print -e 'usage: prover-remind.nu                (hook mode, JSON on stdin)'
        print -e '       prover-remind.nu --decide EVENT MINS LASTPROOF DEBT KRED KSORRY ALARMS'
        print -e '       prover-remind.nu --measure      (count, minutes and name, off disk)'
        print -e ('refusing unknown argument(s): ' + ($rest | str join ' '))
        exit 2
    }

    let cfg = (resolve-config)

    if $measure {
        let s = (get-proof-scan $cfg.proofs_dir)
        print (($s.count | into string) + ' ' + ($s.mins | into string) + ' ' + $s.last)
        return
    }

    # --kernel: the instrument the classification never had. `--decide`
    # receives KRED already marked, so every test to date exercised the WORDING
    # of the verdict and none exercised the CLASSIFICATION that produces it --
    # which is how a broken demotion survived 69 contract rows, 31 cross-arm
    # rows and a full gate. A parity checker cannot catch a bug both arms share.
    if $kernel {
        let k = (read-kernel $cfg.state_dir)
        print (($k.red | str join ',') + '|' + ($k.sorry | str join ','))
        return
    }

    if $workspace {
        print ($cfg.ws_source + ' ' + $cfg.ws)
        return
    }

    if $decide {
        if (($rest | length) != 7) {
            print -e 'usage: prover-remind.nu --decide EVENT MINS LASTPROOF DEBT KRED KSORRY ALARMS'
            exit 2
        }
        let ctx = (invoke-decide ($rest | get 0) (($rest | get 1) | into int) ($rest | get 2) ($rest | get 3) ($rest | get 4) ($rest | get 5) (($rest | get 6) | into int) $cfg.stale_min)
        if ($ctx != null) { print $ctx }
        return
    }

    # --- HOOK MODE -----------------------------------------------------------
    # Everything below is wrapped so the contract holds: never throw, exit 0.
    try {
        let raw = $stdin_raw
        let payload = (if (($raw | str trim | is-empty)) { null } else { try { $raw | from json } catch { null } })
        let ev_raw = (if ($payload == null) { 'PostToolUse' } else {
            ($payload | get -o hook_event_name | default 'PostToolUse' | into string)
        })
        let ev_clean = ($ev_raw | str replace --all --regex '[^A-Za-z0-9_-]' '')
        let ev = (if ($ev_clean | is-empty) { 'PostToolUse' } else { $ev_clean })

        # VERIFY FIRST, ADVISE SECOND.
        let lean_verdict = (if (($ev == 'PostToolUse') and ($payload != null)) {
            try { invoke-lean-verify $payload $cfg.ws } catch { '' }
        } else { '' })

        # Per-event throttle: independent stamps, so no lane can silence
        # another. A build verdict is never throttled -- throttling exists so a
        # tight tool loop cannot spam ADVICE, and "this module does not
        # compile" is not advice.
        let thr_env = (if ($ev == 'UserPromptSubmit') { (get-env-or 'ROTMOE_THROTTLE_PROMPT' '0')
            } else if ($ev == 'PreToolUse') { (get-env-or 'ROTMOE_THROTTLE_PRE' '7')
            } else { (get-env-or 'ROTMOE_THROTTLE_POST' '5') })
        let thr = (if not ($lean_verdict | is-empty) { 0 } else { $thr_env | into int })

        if not ($cfg.state_dir | path exists) { mkdir $cfg.state_dir }
        let stamp = ($cfg.state_dir | path join ('prover-remind.' + $ev + '.stamp'))
        if (($thr > 0) and ($stamp | path exists)) {
            let age = (try { (((date now) - (ls -D $stamp | get 0.modified)) / 1min) } catch { 0.0 })
            if ($age < $thr) { return }
        }

        let scan = (get-proof-scan $cfg.proofs_dir)
        let debt_files = (try { scan-debt $cfg } catch { [] })
        let alarms = (count-alarms $cfg.goal_file)
        let k = (read-kernel $cfg.state_dir)

        # THE BUNDLED CORPUS CANNOT ACCUSE (W5). When the chain bottoms out at
        # the plugin's own read-only lean/, the staleness figure measures OUR
        # shipped proofs, a tree the user never worked in. Staleness is
        # suppressed on that fallback; debt, kernel, sorry and alarms keep
        # their voice -- they measure the USER's repository.
        let bundled = ($cfg.ws_source == 'bundled')
        let mins = (if $bundled { 0 } else { $scan.mins })
        let last = (if $bundled { '-' } else { $scan.last })

        # STALENESS ALONE IS ADVICE, NOT A VERDICT. One shared stamp throttles
        # the staleness-only case to stale_min itself. The stamp is only
        # WRITTEN at the emission point below, so a suppressed or schema-gated
        # turn never burns it.
        let stale_only = ((($debt_files | length) == 0) and (($k.red | length) == 0) and
                          (($k.sorry | length) == 0) and ($alarms == 0) and ($mins >= $cfg.stale_min))
        let stale_stamp = ($cfg.state_dir | path join 'prover-remind.stale.stamp')
        if ($stale_only and ($lean_verdict | is-empty) and ($stale_stamp | path exists)) {
            let s_age = (try { (((date now) - (ls -D $stale_stamp | get 0.modified)) / 1min) } catch { 0.0 })
            if ($s_age < $cfg.stale_min) { return }
        }

        let ctx_base = (invoke-decide $ev $mins $last ($debt_files | str join ',') ($k.red | str join ',') ($k.sorry | str join ',') $alarms $cfg.stale_min)

        # THE VERDICT OUTRANKS THE ADVICE. invoke-decide returns nothing in the
        # common case, so a build failure would otherwise be discarded on the
        # way out because the REMINDER had nothing to add.
        let ctx = (if not ($lean_verdict | is-empty) {
            if ($ctx_base != null) { $lean_verdict + ' ' + $ctx_base } else { $lean_verdict }
        } else { $ctx_base })
        if (($ctx == null) or ($ctx | is-empty)) { return }

        # SCHEMA GATE: being wired to an event is not permission to speak on
        # it. The label is NOT touched -- it must keep naming the invoking
        # event -- only the emission is gated, and an event the CLI later
        # starts accepting simply gets no injection, which is the safe way to
        # be wrong.
        if not ($ev in $CTX_EVENTS) { return }

        (date now | format date '%+') | save -f $stamp
        if $stale_only { (date now | format date '%+') | save -f $stale_stamp }

        # The invoking event MUST be echoed back or Claude Code discards it.
        # `print -n`, not `print`: the ps1 emits via [Console]::Out.Write with
        # NO trailing newline, and a bare `print` here made this arm one byte
        # longer than the reference on every single fire (723 vs 724).
        print -n ({ hookSpecificOutput: { hookEventName: $ev, additionalContext: $ctx } } | to json --raw)
    } catch { }
}
