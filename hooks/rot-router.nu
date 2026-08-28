# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# rot-router.nu -- the RoT MoE router, Nushell arm. STAGE 1: the CLI half.
#
# Port of hooks/rot-router.ps1 (1457 lines). The PowerShell arm stays the
# reference: checker/cross-diff.sh runs both over one corpus and requires
# BYTE-IDENTICAL output on every row.
#
# WHAT THIS FILE COVERS, AND WHAT IT DOES NOT -- said plainly so nobody wires
# it up expecting the other half:
#
#   COVERED  --version, --route, --vector (with --breadth/--m/--c/--t/
#            --profile/--lane), TIER 1 routing, the NSIL lens set, the ten
#            section 4 profiles, the band tables, and the gauge including the
#            -Voice LENSDATA lines. That is rot-router.ps1 lines 1-740, which
#            is the entire numeric contract the cross-diff corpus exercises.
#
#   NOT YET  hook mode (ps1 742-1457): the payload read, the per-session
#            project log, the sentinel clause, the animus remark and the voice
#            block. Until that lands this file must NOT be wired to an event.
#
#   DELIBERATELY ABSENT  the debug-log sinks. Invoke-Gauge in the ps1 writes a
#            gauge record when ROTMOE_DEBUG_LOG is set, under a mkdir-based
#            lock the two arms use to exclude EACH OTHER. Writing half of that
#            protocol would put malformed records into a live sink that the
#            ps1 arm is still appending to, so this arm writes NOTHING to
#            either sink and stdout is unaffected either way. Stage 2 owns it.
#
# InvariantCulture on every number, exactly as the ps1 does. Nushell formats
# numbers with a '.' regardless of locale, so the comma-decimal hazard the ps1
# guards against does not arise here -- but the same guarantee is required, so
# every emitted figure goes through format-num rather than plain interpolation.
# =============================================================================

# --- TIER 1 ------------------------------------------------------------------
# ORDER IS THE CONTRACT. route_exact in lean/Proofs/RotRoute.lean characterises
# every lane in both directions against exactly this order, so a reordering
# here is a proved defect rather than a matter of taste. `code` and `art` are
# deliberately absent -- both arms must delete the same two.
# ORGAN 7, imported rather than re-implemented. `rot-env-load` is `def --env`,
# so its declarations land in the caller's scope -- which is exactly the
# semantics the ps1 gets by dot-sourcing rot-env.ps1 and is why it must NOT be
# called through a subshell.
use rot-env.nu [rot-env-load]

# The DTD is resolved from CLAUDE_PLUGIN_ROOT, then ROTMOE_HOME, then this.
# Named as a fallback out loud: a hardcoded path that pretends to be the
# primary lookup is how an installed plugin silently reads a stale contract.
const ROT_HOME_FALLBACK = 'C:/Users/Saimono/.claude/plugins/cache/nestor-plugins/rot-moe/9.0.2'

const TIER1 = [
    { mode: 'FORGE'      lead: 'Claude'    stems: ['run' 'build' 'install' 'deploy' 'reproduce' 'ship' 'lake' 'theorem' 'tactic' 'sorry' 'mathlib' '.lean' 'prove' 'proof' 'lemma' 'lean' 'qed'] }
    { mode: 'CLINICAL'   lead: 'AntiVenom' stems: ['debug' 'error' 'bug' 'fix' 'secur' 'audit' 'verif' 'test' 'cve' 'segfault' 'crash' 'panic' 'leak' 'regress' 'traceback'] }
    { mode: 'EXECUTIVE'  lead: 'Venom'     stems: ['decid' 'urgenc' 'strike' 'direct' 'declar' 'now' 'conclud'] }
    { mode: 'EMPATHIC'   lead: 'Violet'    stems: ['emot' 'feel' 'grief' 'lonel' 'soul' 'story' 'human' 'tired' 'lost' 'relation'] }
    { mode: 'STRATEGIC'  lead: 'Nova'      stems: ['strateg' 'plan' 'goal' 'roadmap' 'priorit' 'legal' 'recommend' 'analyz'] }
    { mode: 'CREATIVE'   lead: 'Carnage'   stems: ['creativ' 'chaos' 'surreal' 'disrupt' 'paradox' 'dream' 'invent' 'brainstorm' 'ideat' 'imagin' 'tagline'] }
    { mode: 'PREDICTIVE' lead: 'Chroma'    stems: ['futur' 'scenar' 'predict' 'trend' 'forec' 'likel' 'horizon' 'next'] }
    { mode: 'STEALTH'    lead: 'Soleil'    stems: ['encod' 'optim' 'token' 'compress' 'concise' 'byte' 'distill'] }
    { mode: 'RECURSIVE'  lead: 'Eidolon'   stems: ['evolv' 'recurs' 'meta' 'architect' 'refactor' 'ontolog' 'hybrid'] }
]

# LENS ORDER is fixed and load-bearing: corpus, POSIX arm and this file must
# agree on which slot is which lens.
const NAMES = ['Nova' 'Violet' 'AntiVenom' 'Venom' 'Carnage' 'Chroma' 'Soleil' 'Eidolon' 'Claude']

# THE TEN SECTION 4 PROFILES -- the lane chooses the weights. Roster order
# throughout. Every profile silent about a lens uses that lens's SECTION 2
# DEFAULT (Claude 1.5/1.05) -- sourced, not guessed.
const PROFILES = {
    CONVERGENT: { L: [1.6 1.3 1.5 1.7 1.1 1.2 0.8 1.4 1.5] M: [1.00 0.95 1.00 1.05 1.20 1.25 0.90 1.10 1.05] }
    CLINICAL:   { L: [1.4 0.7 2.5 1.0 0.5 1.0 1.2 1.3 1.5] M: [1.00 0.90 1.20 1.00 0.80 1.10 1.00 1.10 1.05] }
    EXECUTIVE:  { L: [1.5 0.8 1.3 2.4 0.7 1.1 1.0 1.0 1.5] M: [1.05 0.90 1.00 1.20 1.00 1.10 0.90 1.00 1.05] }
    EMPATHIC:   { L: [0.8 2.3 0.9 0.8 1.8 1.4 0.7 1.0 1.5] M: [0.90 1.15 0.95 0.90 1.30 1.20 0.85 1.00 1.05] }
    STRATEGIC:  { L: [2.2 0.9 1.8 1.6 0.7 1.5 0.6 1.3 1.5] M: [1.15 0.95 1.00 1.10 1.20 1.25 0.90 1.10 1.05] }
    CREATIVE:   { L: [1.0 1.6 0.8 0.7 2.5 1.2 0.9 1.5 1.5] M: [1.00 1.15 0.90 1.00 1.35 1.10 0.85 1.15 1.05] }
    PREDICTIVE: { L: [1.4 1.0 1.2 1.2 0.9 2.4 0.8 1.3 1.5] M: [1.10 1.00 1.00 1.05 1.00 1.25 0.90 1.10 1.05] }
    STEALTH:    { L: [0.7 0.6 1.5 0.8 0.5 0.7 2.5 1.0 1.5] M: [0.90 0.85 1.10 0.90 0.80 0.90 1.20 1.00 1.05] }
    RECURSIVE:  { L: [1.5 1.0 1.6 0.8 1.1 1.2 0.9 2.3 1.5] M: [1.10 1.00 1.10 0.95 1.20 1.15 0.90 1.20 1.05] }
    FORGE:      { L: [1.4 0.6 1.9 1.2 0.6 1.0 1.0 1.2 2.3] M: [1.05 0.85 1.10 1.05 0.90 1.10 0.95 1.10 1.15] }
}

# NOVA'S BAND FLAG -- section 5's per-lens optimal R/s+ ranges, in hundredths.
# The band is PER LANE: one global range would flag a lane permanently through
# no fault of its own. CONVERGENT and STRATEGIC share 1.0-2.0 because section 5
# lists Nova once, for "Convergent/Strategic".
const BANDS = {
    CONVERGENT: [100 200], STRATEGIC: [100 200], EMPATHIC: [120 250]
    CLINICAL:   [80 150],  EXECUTIVE: [70 180],  CREATIVE: [150 350]
    PREDICTIVE: [100 220], STEALTH:   [50 120],  RECURSIVE: [80 150]
    FORGE:      [90 180]
}

# VIOLET'S JAZZ TRACKS -- section 2's five names in charter order. Her charter
# selects by the query's EMOTIONAL FREQUENCY, which no shell can read; the
# clock is what the router CAN measure, and the five names are themselves named
# for hours, so the stanza offers the hour's track as a DEFAULT and says so.
const VIOLET_TRACKS = ['MORNING_BLUES' 'AFTERNOON_SWING' 'NIGHT_SAXOPHONE' 'MIDNIGHT_RAIN' 'DAWN_ECHOES']

# THE SECTION 2 DEFAULT ROSTER -- the table Symbiogenesis is defined over.
# HUNDREDTHS AS INTEGERS, matching the POSIX arm byte for byte. Nushell has
# floats and could compute this directly, and that is exactly why it must not:
# the arms have to agree on every emitted digit, and floating point is where
# they would silently stop agreeing.
const DEF_LAM = [160 130 150 170 110 120 80 140 150]
const DEF_MU  = [100 95 100 105 120 125 90 110 105]
const DEF_H   = [35 45 30 28 55 38 22 38 30]

const CHROMA_SPAWNED = 12
const CHROMA_SHOWN_NORMAL = 5
const CHROMA_SHOWN_EMERGENCY = 3
const TOKEN_FLOOR_PCT = 20

# CONVERGENT is the only lane with no lead LENS -- by design, all nine
# co-reason and none leads. It used to print the literal 'none', which reads as
# a null: as though the router failed to decide, rather than decided that
# nobody leads. What convenes the nine is the MODEL the user chose, so that is
# what gets named. The payload carries no model key (measured), so it is read
# from the settings file the client itself writes, degrading at every step
# rather than failing.
def get-convener []: nothing -> string {
    let m = ($env | get -o ROTMOE_MODEL | default '')
    if not ($m | is-empty) { return ($m | into string) }
    let cfg_dir = ($env | get -o CLAUDE_CONFIG_DIR | default '' | into string)
    let dir = (if ($cfg_dir | is-empty) {
        (($env | get -o HOME | default ($env | get -o USERPROFILE | default '.')) | path join '.claude')
    } else { $cfg_dir })
    let cfg = ($dir | path join 'settings.json')
    if ($cfg | path exists) {
        let j = (try { open --raw $cfg | from json } catch { null })
        if ($j != null) {
            let mo = ($j | get -o model | default '')
            if not (($mo | into string) | is-empty) { return ($mo | into string) }
        }
    }
    'model'
}

# A STEM MUST START A WORD. `prove` cannot be a substring stem because
# "improve" contains it, and neither can `lemma` ("dilemma") or `lean`
# ("cleaning"). The same flaw was already live for `fix` ("prefix"), `now`
# ("known") and `test` ("latest").
#
# Written with an index scan rather than a regex ON PURPOSE. A regex would need
# every stem escaped, and `.lean` -- a stem that begins with a metacharacter --
# is exactly the case that would silently become "any character followed by
# lean". The dot is also why the punctuation-led fallback exists: "basic.lean"
# has no word boundary before it.
def test-word-char [c: string]: nothing -> bool {
    $c =~ '^[\p{L}\p{N}]$'
}

# Literal text, not a pattern: `.lean` must match a dot, not "any character".
# Backslash is escaped FIRST or the escapes added after it would themselves be
# escaped.
def regex-escape [s: string]: nothing -> string {
    mut out = $s
    for c in ['\' '.' '+' '*' '?' '(' ')' '[' ']' '{' '}' '^' '$' '|'] {
        $out = ($out | str replace --all $c ('\' + $c))
    }
    $out
}

# ONE REGEX PER STEM, NOT A HAND-ROLLED CHARACTER SCAN.
#
# The first draft mirrored the ps1's index loop literally: `split chars` to a
# list, then `skip $i | take $sl | str join` at EVERY index. TIER 1 holds 90
# stems and both invoke-route and get-nsil-active-lenses walk all of them, so a
# single hook did up to 180 full splits plus ~180*n*len(stem) allocating list
# operations. MEASURED, same payload, ps1 vs nu:
#
#     1,100 chars     0.37 s  vs   7.9 s
#     4,400 chars     0.38 s  vs 103.4 s
#    17,600 chars     0.39 s  vs  TIMEOUT at 180 s
#    35,200 chars     0.40 s  vs  TIMEOUT at 180 s
#
# The ps1 arm is flat because .NET indexes a string in place; Nushell's list
# pipeline allocates. `(^|[^\p{L}\p{N}])` is the SAME predicate the loop
# encoded -- match at position 0, or immediately after a character that is not
# a letter or digit -- expressed so the regex engine scans the string once.
# Nushell's regex crate has no lookbehind, so the preceding character is
# CONSUMED by the alternation rather than asserted; that cannot cause a miss,
# because the engine attempts every start position independently.
def test-stem-fires [p: string, stem: string]: nothing -> bool {
    if ($stem | is-empty) { return false }
    if not (test-word-char ($stem | str substring 0..<1)) {
        return ($p | str contains $stem)
    }
    $p =~ ('(^|[^\p{L}\p{N}])' + (regex-escape $stem))
}

# `Invoke-Route` returns "<LANE LENS>|<stem>" exactly as the POSIX `route`
# does, and --route prints the lane alone so that output is unchanged. The
# debug log records the STEM because a lane without its reason cannot be
# diagnosed, and a stem leaks nothing: they come from a CLOSED SET defined in
# this file.
def invoke-route [prompt: string]: nothing -> string {
    let p = ($prompt | str lowercase)
    for lane in $TIER1 {
        for stem in $lane.stems {
            if (test-stem-fires $p $stem) {
                return ($lane.mode + ' ' + $lane.lead + '|' + $stem)
            }
        }
    }
    'CONVERGENT ' + (get-convener) + '|'
}

# Split the two fields on the LAST separator, so a model name containing `|`
# cannot eat the stem. Used by both callers; a second inline split would be a
# second source of truth for the same contract.
def split-routed [routed: string]: nothing -> list<string> {
    let i = ($routed | str index-of --end '|')
    if $i < 0 { return [$routed ''] }
    # `0..<$i`, NOT `0..$i`: Nushell ranges are INCLUSIVE of the end, so the
    # obvious transliteration of .NET's Substring(0, i) kept the separator and
    # --route printed "FORGE Claude|". Caught by the corpus on row 1.
    [($routed | str substring 0..<$i) ($routed | str substring ($i + 1)..)]
}

# --- TIER 2: NSIL -- FUSE and ELEVATE ----------------------------------------
# FUSE fires when >= 2 DISTINCT lanes match, ELEVATE when none match and the
# prompt carries at least one word per lens. Lenses come back in ROSTER order,
# never match order, so the two arms cannot disagree about bit order in the
# activity vector.
def get-nsil-active-lenses [prompt: string]: nothing -> list<string> {
    let p = ($prompt | str lowercase)
    let hit = ($TIER1 | each { |lane|
        let fired = ($lane.stems | any { |stem| test-stem-fires $p $stem })
        if $fired { $lane.lead } else { null }
    } | compact)
    $NAMES | where { |n| $n in $hit }
}

# Unknown lane -> CONVERGENT, which section 3 already names as the default with
# no trigger, so the fallback is the spec's own answer rather than a shrug.
def select-profile [lane: string]: nothing -> record {
    let p = ($PROFILES | get -o $lane)
    if $p == null { $PROFILES.CONVERGENT } else { $p }
}

def select-band [lane: string]: nothing -> list<int> {
    let b = ($BANDS | get -o $lane)
    if $b == null { $BANDS.FORGE } else { $b }
}

# hundredths -> the same decimal string the POSIX arm's printf produces.
def format-hund [v: int]: nothing -> string {
    (($v // 100) | into string) + '.' + (($v mod 100) | fill --alignment right --character '0' --width 2)
}

# BANKER'S ROUNDING, WRITTEN OUT, BECAUSE NUSHELL'S IS NOT .NET'S.
#
# The ps1 rounds with [Math]::Round(x, d), which is MidpointRounding.ToEven.
# `math round --precision` rounds half AWAY FROM ZERO. Measured, six probes,
# four disagree:
#
#     x       prec   pwsh    nu
#     0.125   2      0.12    0.13
#     2.5     0      2       3
#     1.005   2      1.00    1
#     0.045   2      0.04    0.05
#
# Nothing here throws; the arms would simply have emitted different digits for
# the same turn, which is precisely what the ps1 header names as the most
# likely place for a silent divergence -- and the reason the cross-diff
# compares the formatted STRING and not the number.
#
# The half case is decided on the FLOOR's parity, which reproduces ToEven for
# negatives too (-2.5 -> floor -3, odd, +1 -> -2, matching .NET). Everything
# after the rounding is integer arithmetic, so no second float format can
# reintroduce a difference.
def round-half-even [x: float, d: int]: nothing -> int {
    let scale = (10 ** $d)
    let scaled = ($x * ($scale | into float))
    let fl = ($scaled | math floor)
    let fi = ($fl | into int)
    let frac = ($scaled - $fl)
    if $frac > 0.5 { $fi + 1
    } else if $frac < 0.5 { $fi
    } else if (($fi mod 2) != 0) { $fi + 1
    } else { $fi }
}

# Mirrors ToString('0.##') / ('0.###'): round, then drop trailing zeros and a
# bare trailing dot. Written explicitly rather than relying on a format string,
# so that the rounding rule is visible next to the awk one it must match.
#
# The '' / '-' guard is not decoration: .NET Core formats negative zero as
# "-0.00", which trims down to a bare "-". Both arms answer '0' there.
def format-num [x: float, d: int]: nothing -> string {
    let scale = (10 ** $d)
    let units = (round-half-even $x $d)
    let au = ($units | math abs)
    let ip = ($au // $scale)
    let fp = ($au mod $scale)
    let body = (if $d <= 0 {
        ($ip | into string)
    } else {
        ($ip | into string) + '.' + ($fp | fill --alignment right --character '0' --width $d)
    })
    # NEGATIVE ZERO KEEPS ITS SIGN. [Math]::Round(-0.5, 0) is -0.0, and .NET
    # Core 3.0+ formats that as "-0", not "0" -- so the ps1 emits "-0" and the
    # trimming below leaves it alone (there is no '.' to trim through). Six of
    # 150 grid rows diverged on exactly this: -0.5 d=0, -0.0001 d=0/2/3,
    # -0.125 d=0, -0.045 d=0. The `''`/`'-'` guard further down is NOT the
    # place to fix it: that guard exists for a bare "-", and collapsing "-0"
    # there would put the divergence back.
    #
    # The sign is read off the STRING, not from `$x < 0.0` and not from a
    # `1.0 / $x` sign probe: Nushell raises nu::shell::division_by_zero rather
    # than yielding an infinity, and that error aborted the whole pipeline the
    # moment a vector contained an exact 0 -- both suites truncated mid-run.
    # Nushell preserves -0.0 and renders it "-0", so `str starts-with '-'`
    # answers for a true -0.0 and for every ordinary negative alike.
    let neg_zero = (($units == 0) and (($x | into string | str starts-with '-')))
    let s = (if (($units < 0) or $neg_zero) { '-' + $body } else { $body })
    let t = (if ($s | str contains '.') {
        ($s | str trim --right --char '0' | str trim --right --char '.')
    } else { $s })
    if (($t | is-empty) or ($t == '-')) { '0' } else { $t }
}

# Mirrors ToString('0.##') on the band bounds specifically.
def format-band-bound [x: float]: nothing -> string {
    format-num $x 2
}

# --- THE GAUGE ---------------------------------------------------------------
# NO SECOND BAND TABLE: $BANDS is declared once above and this reads THAT.
# --voice is the sh arm's optional 7th gauge argument: it turns on the per-lens
# LENSDATA lines the voice block consumes. It is passed ONLY by hook mode's
# voice path, so --vector output stays byte-identical to every earlier release.
#
# THE WEIGHTS AND THE BAND ARE TWO SEPARATE CHOICES, and conflating them is a
# real defect rather than a tidy-up. In the ps1, `Select-Profile $Profile` sets
# $script:Lambdas/$Mus while the $Lane argument reaches the gauge for the BAND
# only -- so `--vector` with neither flag scores on the CONVERGENT weights and
# reports against the FORGE band. Deriving both from one name silently rescored
# every default-path row on the FORGE table.
#
# ONE COMPUTATION, THREE CONSUMERS. `gauge-compute` is where the arithmetic
# lives; the human line, the LENSDATA lines and the gauge debug record are all
# projections of the SAME record. The ps1 gets this from $script:Lambdas being
# visible to Invoke-Gauge; taking the weights as an ARGUMENT here is what lets
# hook mode hand in a BOOSTED table without a second scoring path.
def gauge-compute [
    vec: string, br: int, m: float, c: float, t: float,
    lane: string,                # band selection only
    lambdas: list<float>,        # weight table, already boosted if applicable
    mus: list<float>
]: nothing -> record {
    let acts = ($vec | split row ',' | each { |a| $a | str trim | into float })
    let k = ($acts | length)
    let mean = (($acts | math sum) / $k)

    let rows = (0..($k - 1) | each { |i|
        let a = ($acts | get $i)
        let d = (($a - $mean) | math abs)
        let s = (1.0 / (1.0 + ((-4.0 * ($d - 0.5)) | math exp)))
        let h_raw = (if $br > 0 { $a / ($br | into float) } else { 0.0 })
        let h = (if $h_raw > 1.0 { 1.0 } else { $h_raw })
        let term = (($lambdas | get $i) * $s * (1.0 + $h) * ($mus | get $i) * $m * $c * $t)
        { name: ($NAMES | get $i), a: $a, d: $d, s: $s, h: $h, term: $term }
    })

    let sum = ($rows | get term | math sum)
    let active = ($rows | where { |r| $r.a > 0 } | get name)
    let r_val = ($sum / $k)

    let bb = (select-band $lane)
    let lo = (($bb | get 0) / 100.0)
    let hi = (($bb | get 1) / 100.0)
    let band_txt = '(' + (format-band-bound $lo) + '-' + (format-band-bound $hi) + ')'
    let band = (if $r_val < $lo { 'BELOW RANGE ' + $band_txt
        } else if $r_val > $hi { 'ABOVE RANGE ' + $band_txt
        } else { 'IN RANGE ' + $band_txt })
    let lenses = (if ($active | is-empty) { 'none' } else { $active | str join ',' })

    let human = ('R/s+ = ' + (format-num $r_val 2) + ' [' + $band + '] mean=' + (format-num $mean 3)
        + ' breadth=' + ($br | into string) + ' K=' + ($k | into string) + ' lenses=' + $lenses)
    # One machine-readable line per lens, AFTER the human line so every existing
    # consumer keeps matching what it always matched.
    # Precisions match the sh awk: lambda 2, sigma 4, H 4, term 5, share 0
    # (share = 100*term/sum), and the 6.0.2 pair APPENDED so the first six
    # positions never move: delta 4, mu 3.
    let data = (0..($k - 1) | each { |i|
        let r = ($rows | get $i)
        let shr = (if $sum > 0 { 100.0 * $r.term / $sum } else { 0.0 })
        ('LENSDATA|' + $r.name + '|' + (format-num ($lambdas | get $i) 2) + '|' + (format-num $r.s 4)
            + '|' + (format-num $r.h 4) + '|' + (format-num $r.term 5) + '|' + (format-num $shr 0)
            + '|' + (format-num $r.d 4) + '|' + (format-num ($mus | get $i) 3))
    })

    { k: $k, mean: $mean, rows: $rows, sum: $sum, r: $r_val, band: $band,
      band_txt: $band_txt, lenses: $lenses, human: $human, lensdata: $data,
      lambdas: $lambdas, mus: $mus }
}

# THE WEIGHTS AND THE BAND ARE TWO SEPARATE CHOICES, and conflating them is a
# real defect rather than a tidy-up. In the ps1, `Select-Profile $Profile` sets
# $script:Lambdas/$Mus while the $Lane argument reaches the gauge for the BAND
# only -- so `--vector` with neither flag scores on the CONVERGENT weights and
# reports against the FORGE band. Deriving both from one name silently rescored
# every default-path row on the FORGE table.
def invoke-gauge [
    vec: string, br: int, m: float, c: float, t: float,
    lane: string = 'FORGE',      # band selection only
    --profile: string = 'CONVERGENT',   # weight table only
    --voice
]: nothing -> list<string> {
    let prof = (select-profile $profile)
    let g = (gauge-compute $vec $br $m $c $t $lane $prof.L $prof.M)
    if $voice { [$g.human] ++ $g.lensdata } else { [$g.human] }
}

# The gauge's own debug record -- the THIRD consumer of gauge-compute, and the
# reason the weights had to become an argument: this record states the lambda
# and mu each lens was actually scored with, so a BOOST is falsifiable from the
# log rather than only asserted on the marker line.
def gauge-record [
    g: record, br: int, m: float, c: float, t: float, session: string, src: string
]: nothing -> string {
    let terms = ($g.rows | enumerate | each { |it|
        let r = $it.item
        ('{"lens":"' + $r.name + '","lambda":' + (format-num ($g.lambdas | get $it.index) 3)
            + ',"mu":' + (format-num ($g.mus | get $it.index) 3)
            + ',"a":' + (format-num $r.a 3) + ',"delta":' + (format-num $r.d 4)
            + ',"sigma":' + (format-num $r.s 4) + ',"H":' + (format-num $r.h 4)
            + ',"term":' + (format-num $r.term 5) + '}')
    })
    ('{"kind":"gauge","ts":"' + (rot-ts) + '","session":"' + $session + '","src":"' + $src
        + '","K":' + ($g.k | into string) + ',"mean":' + (format-num $g.mean 4)
        + ',"breadth":' + ($br | into string) + ',"M":' + (format-num $m 3)
        + ',"C":' + (format-num $c 3) + ',"T":' + (format-num $t 3)
        + ',"sum":' + (format-num $g.sum 5) + ',"Rs":' + (format-num ($g.sum / $g.k) 5)
        + ',"active":"' + $g.lenses + '","lenses":[' + ($terms | str join ',') + ']}')
}

# SOLEIL'S TOKEN_EMERGENCY_MONITOR. THE BUDGET IS ACCEPTED, NEVER GUESSED: the
# payload was measured to carry no token budget, and inferring one from prompt
# length would be inventing a reading and then acting on it. Absent means
# unknown, and unknown is NOT an emergency -- an alarm with no sensor attached
# must stay quiet.
def get-token-emergency []: nothing -> bool {
    let pct = ($env | get -o ROTMOE_TOKEN_PCT | default '' | into string)
    if ($pct | is-empty) { return false }
    let n = (try { $pct | into int } catch { null })
    if $n == null { return false }
    $n < $TOKEN_FLOOR_PCT
}

def get-violet-track [hh: string]: nothing -> string {
    let h = (try { $hh | into int } catch { null })
    if $h == null { return '' }
    if (($h >= 5) and ($h <= 11)) { return ($VIOLET_TRACKS | get 0) }
    if (($h >= 12) and ($h <= 17)) { return ($VIOLET_TRACKS | get 1) }
    if (($h >= 18) and ($h <= 22)) { return ($VIOLET_TRACKS | get 2) }
    if (($h == 23) or ($h <= 3)) { return ($VIOLET_TRACKS | get 3) }
    if ($h == 4) { return ($VIOLET_TRACKS | get 4) }
    ''
}

# A FLAG, never a veto -- section 5 is explicit that out-of-range is a
# correction signal, not a refusal. Nothing branches on the result.
def get-band-flag [lane: string, rs: string]: nothing -> string {
    if $rs == 'n/a' { return 'IN' }
    let b = (select-band $lane)
    # [int][math]::Round(...) is ToEven here too -- same helper, not a second
    # rounding rule living beside the first.
    let v = (round-half-even (($rs | into float) * 100) 0)
    if $v < ($b | get 0) { 'BELOW' } else if $v > ($b | get 1) { 'ABOVE' } else { 'IN' }
}

def get-nsil-hybrid [a: string, b: string]: nothing -> any {
    let i = ($NAMES | enumerate | where item == $a | get -o 0.index)
    let j = ($NAMES | enumerate | where item == $b | get -o 0.index)
    if (($i == null) or ($j == null) or ($i == $j)) { return null }
    {
        lam: (((($DEF_LAM | get $i) + ($DEF_LAM | get $j)) // 2) + 20)
        mu: ([($DEF_MU | get $i) ($DEF_MU | get $j)] | math max)
        h: (([($DEF_H | get $i) ($DEF_H | get $j)] | math max) + 5)
    }
}

# =============================================================================
# STAGE 2 -- HOOK MODE
# =============================================================================

# The state dir, resolved exactly as every other organ resolves it:
# ROTMOE_STATE_DIR -> XDG_STATE_HOME/rot-moe -> $HOME/.local/state/rot-moe.
def rot-state-dir []: nothing -> string {
    let explicit = ($env | get -o ROTMOE_STATE_DIR | default '' | into string)
    if not ($explicit | is-empty) { return $explicit }
    let xdg = ($env | get -o XDG_STATE_HOME | default '' | into string)
    let home_dir = ($env | get -o HOME | default ($env | get -o USERPROFILE | default '.') | into string)
    if ($xdg | is-empty) {
        ($home_dir | path join '.local' 'state' 'rot-moe')
    } else {
        ($xdg | path join 'rot-moe')
    }
}

# `sanitiseSession` in lean/Proofs/RotSessionLog.lean, and the sh arm's
# `_rot_scrub`: keep [A-Za-z0-9-], cut to 64, empty scrubs to the fallback.
# This is NOT cosmetic -- the value is interpolated into a FILENAME, and a
# session id of "../../.ssh/authorized_keys" would otherwise make the router
# append outside the project. Traversal is removed by DELETING the characters,
# never by blacklisting the ".." spelling.
def rot-scrub [raw: string, fallback: string]: nothing -> string {
    let kept = ($raw | str replace --all --regex '[^A-Za-z0-9-]' '')
    let cut = (if ($kept | str length) > 64 { $kept | str substring 0..<64 } else { $kept })
    if ($cut | is-empty) { $fallback } else { $cut }
}

# MUTUAL EXCLUSION -- the ps1's Get-RotLogLock and the sh arm's
# `_rot_lock_acquire` are the SAME algorithm on purpose: one lock protocol,
# several implementations, so the arms exclude EACH OTHER and not merely
# themselves. The token is THE DIRECTORY ITSELF.
#
# Nushell's own `mkdir` is `mkdir -p` semantics: it SUCCEEDS on an existing
# directory, which is precisely the answer a lock must never give -- it would
# hand the lock to every caller at once. `cmd /c mkdir` fails with a non-zero
# exit when the directory exists, which is the atomic primitive the other two
# arms get from IOException and from mkdir(1).
def rot-log-lock [path: string]: nothing -> bool {
    if ($path | is-empty) { return false }
    let lk = $path + '.lock'
    # Refuse rather than materialise the parent of an unwritable log path: the
    # ps1 measured checker/debug-channel.sh going red on exactly that, because
    # creating the parent made the append succeed and the lost-record marker
    # stopped firing. No parent, no write, and the loss is MARKED.
    let parent = ($path | path dirname)
    if (not ($parent | is-empty)) and (not ($parent | path exists)) { return false }
    let win = ($lk | str replace --all '/' '\')
    mut i = 0
    while $i < 50 {
        let rc = (do -i { ^cmd /c mkdir $win } | complete | get exit_code)
        if $rc == 0 { return true }
        # A holder that died leaves the directory behind and would silence
        # logging forever. Break it only when demonstrably older than any real
        # write -- writes take milliseconds, so 30 s is four orders of margin.
        try {
            if ($lk | path exists) {
                let age = ((date now) - (ls -D $lk | get 0.modified))
                if $age > 30sec { rm -rf $lk }
            }
        }
        sleep 20ms
        $i = $i + 1
    }
    false
}

def rot-log-unlock [path: string] {
    if ($path | is-empty) { return }
    try { rm -rf ($path + '.lock') }
}

# TERMINATE A PARTIAL LINE BEFORE APPENDING -- `RotLogAtomicity.appendSafe`.
# A writer killed between its bytes leaves a line with no newline; the next
# append lands ON those bytes and costs its SUCCESSOR a good record. Closing
# the line first isolates the fragment and keeps the new record. NO-OP on a
# healthy file.
def rot-complete-partial-line [path: string] {
    if not ($path | path exists) { return }
    let size = (try { ls -D $path | get 0.size | into int } catch { 0 })
    if $size == 0 { return }
    let last = (try { open --raw $path | bytes at ($size - 1).. | into int } catch { 10 })
    if $last != 10 { "\n" | save --append --raw $path }
}

# The SECOND log: one file per session, inside the project being worked on, so
# a session can be inspected beside the code that produced it. Independent of
# the central sink on purpose. Returns true when the record was LOST.
def rot-debug-local [line: string, project_dir: string, session: string, dbg_path: string]: nothing -> bool {
    let mode = ($env | get -o ROTMOE_DEBUG_LOCAL | default '' | into string)
    if $mode == '0' { return false }
    if not (($mode == '1') or (not ($dbg_path | is-empty))) { return false }
    if ($project_dir | is-empty) { return false }
    try {
        let d = ($project_dir | path join '.rot-moe')
        if not ($d | path exists) {
            mkdir $d
            # A self-ignoring directory. The router writes into someone else's
            # repository; polluting their `git status` would be rude and would
            # eventually get the whole log committed by accident.
            "*\n" | save --raw --force ($d | path join '.gitignore')
        }
        let f = ($d | path join ('rot-route-' + $session + '.jsonl'))
        # The lock spans the repair AND the append. Splitting them is the
        # defect: a reader that repairs while a writer is mid-record splits
        # that record.
        if not (rot-log-lock $f) { return true }
        try {
            rot-complete-partial-line $f
            # LF, NOT CRLF -- Y6. `save --append --raw` writes exactly the
            # bytes given, which is what the ps1 had to reach for
            # AppendAllText to get.
            ($line + "\n") | save --append --raw $f
        }
        rot-log-unlock $f
        false
    } catch {
        true
    }
}

# Both sinks are attempted, and the local one is NOT behind the central one's
# early return -- that ordering was the bug in the ps1's first draft: with
# ROTMOE_DEBUG_LOG unset the per-session log could never be created at all.
# Returns {central: bool, local: bool}, each true when that record was LOST.
# A refusal costs 1 record; an unlocked write destroys 2. The loss must be
# RECORDED, never silent -- otherwise it is indistinguishable from a router
# that never fired.
# THE SINK PATH IS AN ARGUMENT, NOT AN ENVIRONMENT READ. Measured 2026-08-27:
# the first draft resolved it from $env inside main, where the assignment sat
# in a `try` block -- and a plain `$env.X = ...` does NOT escape that block's
# scope in Nushell, so every read afterwards saw the empty string. Result: 13
# of 13 stdout comparisons matched the ps1 arm byte for byte while BOTH log
# sinks silently wrote nothing. Threading the path makes the flow visible and
# the failure impossible to reintroduce.
def rot-debug [line: string, project_dir: string, session: string, dbg_path: string]: nothing -> record {
    let local_lost = (rot-debug-local $line $project_dir $session $dbg_path)
    let p = $dbg_path
    if ($p | is-empty) { return { central: false, local: $local_lost } }
    let central_lost = (try {
        if not (rot-log-lock $p) {
            true
        } else {
            try {
                rot-complete-partial-line $p
                ($line + "\n") | save --append --raw $p
            }
            rot-log-unlock $p
            false
        }
    } catch { true })
    if $central_lost { return { central: true, local: $local_lost } }

    # Bound the file, discarding the OLDEST. The hazard is measured, not
    # theoretical: ~/.claude holds a 1.4 GB and a 1.1 GB log grown by exactly
    # this append pattern with no bound.
    #
    # TRIM TO A LOW-WATER MARK, NOT BACK TO THE CAP. Trimming to exactly the
    # cap leaves the file AT the cap, so the next append exceeds it by one and
    # rewrites the whole file again to drop a single line -- every turn,
    # forever, and invisible because the bound is always respected. Keeping
    # 80 % turns that into a rewrite once per ~20 % of the cap.
    try {
        let cap_raw = ($env | get -o ROTMOE_DEBUG_LOG_MAX | default '' | into string)
        let cap = (if ($cap_raw =~ '^\d+$') { $cap_raw | into int } else { 5000 })
        if $cap > 0 {
            let lines = (open --raw $p | lines)
            if ($lines | length) > $cap {
                let keep_n = (($cap * 8) // 10)
                let keep = (if $keep_n <= 0 { $lines | last $cap } else { $lines | last $keep_n })
                (($keep | str join "\n") + "\n") | save --raw --force $p
            }
        }
    }
    { central: false, local: $local_lost }
}

# ISO 8601 with a fractional second and an offset -- the shape Get-Date -Format
# 'o' produces, so both arms' records sort and parse the same way.
#
# SIX FRACTIONAL DIGITS, NOT .NET's SEVEN. chrono, which is what `format date`
# is built on, accepts only %.3f, %.6f and %.9f; '%.7f' is rejected outright
# with nu::shell::type_mismatch "invalid format" -- which killed the turn the
# moment the first record was written. Padding six digits to seven would
# fabricate a digit of precision the clock never gave, so the field is one
# digit shorter and honest. Every consumer parses ISO 8601, which makes the
# fraction width a formatting detail, not a contract.
def rot-ts []: nothing -> string {
    (date now | format date '%Y-%m-%dT%H:%M:%S%.6f%:z')
}

# ROUTE ON WHAT THE TOOL IS DOING, not on its name. MEASURED DEFECT 2026-08-03:
# reading only the tool NAME made every PreToolUse firing route to CONVERGENT,
# because "Bash", "Edit", "Read" and "Grep" match no stem. The autonomous half
# of the router was inert and looked healthy.
def payload-prompt [j: any, raw: string]: nothing -> string {
    if $j == null { return $raw }
    let p = ($j | get -o prompt)
    if (($p != null) and (not (($p | into string) | is-empty))) { return ($p | into string) }
    let tn = ($j | get -o tool_name)
    if (($tn == null) or (($tn | into string) | is-empty)) { return '' }
    let ti = ($j | get -o tool_input)
    let act = (if $ti == null { [] } else {
        ['command' 'file_path' 'path' 'pattern' 'description'] | each { |f|
            let v = ($ti | get -o $f)
            if (($v != null) and (($v | describe) == 'string') and (not ($v | is-empty))) { $v } else { null }
        } | compact
    })
    if ($act | is-empty) { ($tn | into string) } else { ($tn | into string) + ' ' + ($act | str join ' ') }
}

# THE PAYLOAD SURVEY -- KEYS ONLY (top-level, tool_input, tool_response), never
# a value, opt-in via ROTMOE_DEBUG_PAYLOAD=1, its own per-session sink,
# degrades to silence. The ship-what-you-measure prerequisite for V2's result
# clauses.
def payload-survey [j: any, session: string] {
    if ($env | get -o ROTMOE_DEBUG_PAYLOAD | default '' | into string) != '1' { return }
    if $j == null { return }
    try {
        let ps_dir = (rot-state-dir)
        mkdir $ps_dir
        let tr = ($j | get -o tool_response)
        let tr_type = (if $tr == null { 'absent' } else {
            let d = ($tr | describe)
            # A list of records describes as `table<...>` (or bare `table` when
            # the rows disagree on columns), never `list<...>` -- a bare list-
            # test labels every such payload 'scalar', which is the exact blind
            # spot the note below says this survey exists to remove. Same defect
            # class as rot-voice-gate.nu:82.
            if (($d | str starts-with 'list') or ($d | str starts-with 'table')) { 'array'
            } else if ($d | str starts-with 'record') { 'object'
            } else { 'scalar' }
        })
        # ABSENT AND EMPTY ARE DIFFERENT FACTS, and the survey is the one file
        # whose entire job is to report what the payload actually carried: a
        # field that was not sent is null, a field that was sent with no keys
        # is []. The ps1 arm collapses both to null because ConvertTo-Json
        # renders its empty array that way -- a survey that cannot tell
        # "no tool_input" from "empty tool_input" is exactly the blind spot
        # this instrument exists to remove.
        let keys_of = { |o|
            if $o == null { null
            } else if (($o | describe) | str starts-with 'record') { $o | columns | sort
            } else { [] }
        }
        let line = ({
            kind: 'payload'
            event: (($j | get -o hook_event_name | default '') | into string)
            tool: (($j | get -o tool_name | default '') | into string)
            keys: (do $keys_of $j)
            toolInputKeys: (do $keys_of ($j | get -o tool_input))
            toolResponseKeys: (do $keys_of $tr)
            toolResponseType: $tr_type
        } | to json --raw)
        ($line + "\n") | save --append --raw ($ps_dir | path join ('rot-payload.' + $session + '.jsonl'))
    }
}

export def main [
    --vector: string    # comma-separated activity vector
    --breadth: int = 0
    --m: float = 1.05
    --c: float = 1.0
    --t: float = 1.0
    --profile: string   # name the weight table out loud
    --lane: string
    --route: string     # print the TIER 1 lane for a prompt
    --voice             # gauge only: append per-lens LENSDATA lines
    --version
] {
    # STDIN IS READ FIRST OR NOT AT ALL. `$in` is consumed by the first
    # expression that touches the pipeline, so capturing it here -- before any
    # branch -- is what keeps hook mode working no matter which flags were
    # also passed. A manual run has no pipeline and lands on '', which is the
    # IsInputRedirected guard the ps1 needs to avoid blocking on a terminal.
    let payload = (try { $in | default '' | into string } catch { '' })
    let __start = (date now)

    if $version { print 'rot-router.nu 1.0.0'; return }

    if ($route != null) {
        let r = (split-routed (invoke-route $route))
        print ($r | get 0)
        return
    }

    if ($vector != null) {
        # --profile names the weight table, --lane picks the band, and the two
        # defaults are NOT the same word: weights fall back to CONVERGENT (the
        # convener, section 3's default-with-no-trigger) and the band falls
        # back to FORGE, exactly as the ps1's script-level $Lambdas and its
        # $laneArg do.
        let lane_arg = (if ($lane == null) { 'FORGE' } else { $lane })
        let prof_arg = (if ($profile == null) { 'CONVERGENT' } else { $profile })
        let out = (if $voice {
            invoke-gauge $vector $breadth $m $c $t $lane_arg --profile $prof_arg --voice
        } else {
            invoke-gauge $vector $breadth $m $c $t $lane_arg --profile $prof_arg
        })
        for line in $out { print $line }
        return
    }

    # =====================================================================
    # HOOK MODE. Claude Code sends the invoking event as JSON on stdin.
    # =====================================================================
    if ($payload | str trim | is-empty) {
        print -e 'rot-router.nu: hook mode expects a JSON payload on stdin. Try --route "some text".'
        exit 2
    }

    # A payload that does not parse is not a reason to fail the user's turn.
    # Route the raw text: the routing decision degrades, the session does not
    # break.
    #
    # A PAYLOAD THAT IS NOT A JSON OBJECT IS NOT A PAYLOAD. `from json` does
    # NOT always throw on junk the way ConvertFrom-Json does: fed the
    # malformed fixture it returned a bare STRING, which then reached
    # `get -o prompt` and killed the turn with
    # nu::shell::only_supports_this_input_type -- the one case in thirteen
    # where the nu arm produced nothing while the ps1 arm degraded and routed.
    # Demoting a non-record to null puts the two arms back on the same rule.
    let j = (try {
        let parsed = ($payload | from json)
        if (($parsed | describe) | str starts-with 'record') { $parsed } else { null }
    } catch { null })
    let prompt = (payload-prompt $j $payload)

    # WHICH SESSION PRODUCED THIS RECORD. Both reads are guarded; an
    # unidentifiable session degrades to 'unknown' rather than losing the
    # record -- the same honesty rule the event field follows.
    let sid = (if $j == null { null } else { $j | get -o session_id })
    let session = (if $sid == null { 'unknown' } else { rot-scrub ($sid | into string) 'unknown' })
    let cwd_raw = (if $j == null { null } else { $j | get -o cwd })
    let project_dir = (if $cwd_raw == null { (pwd) } else { $cwd_raw | into string })

    # ORGAN 7 -- the environment layer. Parsed never sourced, declared-only,
    # unset-only. A missing library is a no-op.
    try { rot-env-load $project_dir }

    # THE DEBUG CHANNEL DEFAULTS ON IN HOOK MODE -- W7. '0' is the canonical
    # off switch on every arm (ENV.5). Bounded twice: each file by the
    # ROTMOE_DEBUG_LOG_MAX trim, the file COUNT by a once-per-session janitor
    # that only runs when this session's file does not exist yet. An
    # unwritable state dir degrades to OFF, never to a failed turn.
    let dbg_declared = ($env | get -o ROTMOE_DEBUG_LOG | default '' | into string)
    let dbg_path = (if not ($dbg_declared | is-empty) {
        # '0' is the canonical off switch; any other declared value is taken
        # as the operator's chosen path and is NOT second-guessed here -- an
        # unwritable one is reported by the lost-record marker, which is the
        # honest answer rather than a silent fallback to somewhere else.
        if $dbg_declared == '0' { '' } else { $dbg_declared }
    } else {
        let dl_dir = (rot-state-dir)
        let dl_path = ($dl_dir | path join ('rot-debug.' + $session + '.jsonl'))
        let ready = (try {
            if not ($dl_path | path exists) {
                mkdir $dl_dir
                # THE JANITOR IS GUARDED SEPARATELY, and that separation is
                # load-bearing: housekeeping must never be able to disable the
                # instrument it is housekeeping for.
                #
                # BACKSLASH IS GLOB'S ESCAPE CHARACTER. `path join` yields a
                # native Windows path, and handing that to `glob` raises
                # "error with glob pattern" -- which, from inside the sink's
                # own try, silently turned logging OFF for every hook call.
                # The pattern is built with forward slashes for exactly this
                # reason; `open`, `ls` and `rm` accept either.
                try {
                    let cutoff = ((date now) - 7day)
                    let pat = (($dl_dir | str replace --all '\' '/' | str trim --right --char '/') + '/rot-debug.*.jsonl')
                    glob $pat | each { |f|
                        try { if ((ls -D $f | get 0.modified) < $cutoff) { rm -f $f } }
                    } | ignore
                }
            }
            true
        } catch { false })
        if $ready { $dl_path } else { '' }
    })
    # Exported as well as threaded: the ps1 sets the variable, and anything
    # this process later hands to a child must see the same sink.
    if not ($dbg_path | is-empty) { $env.ROTMOE_DEBUG_LOG = $dbg_path }
    let dbg_on = (not ($dbg_path | is-empty))

    payload-survey $j $session

    # PROVENANCE -- `classify` in lean/Proofs/RotSessionLog.lean. Seven
    # checkers feed the router synthetic payloads and write into the same log;
    # 738 of 955 sh records were theirs and nothing in the schema said so. An
    # unrecognised ROTMOE_DEBUG_SRC is IGNORED, never believed: a typo demotes
    # to inference rather than inventing a fourth class.
    let has_event = (($j != null) and (($j | get -o hook_event_name) != null))
    let src_decl = ($env | get -o ROTMOE_DEBUG_SRC | default '' | into string)
    let src = (if $src_decl in ['test' 'cli' 'hook'] { $src_decl
        } else if $has_event { 'hook' } else { 'cli' })

    # WHICH EVENT FIRED -- extracted BEFORE TIER 2, because the density
    # verdicts read it. The charset guard is load-bearing: this value goes
    # into a JSON record AND is echoed back in the envelope, so a quote or a
    # brace arriving here would emit a malformed line that breaks every
    # downstream reader. Anything not plain letters is recorded as "-".
    let ev_raw = (if $has_event { ($j | get hook_event_name) | into string } else { '-' })
    let ev = (if ($ev_raw =~ '^[A-Za-z]+$') { $ev_raw } else { '-' })

    # DENSITY IS A PROPERTY OF A QUERY, NOT OF A COMMAND LINE (W3): tool-event
    # text is the tool name plus command/path/pattern, routinely nine-plus
    # words, and the floor read it as a dense query. The density verdicts
    # (BOOST, ELEVATE) fire only where a human typed the words; every
    # stem-based verdict is untouched on tool events.
    let nsil_query = ($ev in ['UserPromptSubmit' 'UserPromptExpansion'])

    let routed = (split-routed (invoke-route $prompt))
    let lane0 = ($routed | get 0)
    let stem = ($routed | get 1)
    let lens0 = ($lane0 | split row ' ' | get 1)

    # --- TIER 2 (NSIL) ---------------------------------------------------
    # BREADTH IS COUNTED, NOT ASSIGNED. Nova adjudicates every turn: the
    # default verdict is CONFIRM ("the TIER 1 lead stands"), never an empty
    # field -- an empty field would say the layer never ran.
    let nsil_fired = (get-nsil-active-lenses $prompt)
    let nsil_words = ($prompt | split row -r '\s+' | where { |w| $w != '' } | length)
    let dense = ($nsil_query and ($nsil_words >= ($NAMES | length)))

    mut nsil_decision = 'CONFIRM'
    mut nsil_act = $nsil_fired
    mut lane = $lane0
    mut lens = $lens0
    mut boost = ''
    if ($nsil_fired | length) >= 2 {
        $nsil_decision = 'FUSE'
        # NSIL is the NOVA Sovereign Intent Layer: a fusion is something Nova
        # DID, so her bit is 1 by construction. Idempotent.
        if not ('Nova' in $nsil_fired) {
            $nsil_act = ($NAMES | where { |n| ($n == 'Nova') or ($n in $nsil_fired) })
        }
        # OVERRIDE -- "the words mislead", on section 3's own worked example:
        # `fix our relationship` routes EMPATHIC, not CLINICAL. Implemented as
        # a REFINEMENT OF FUSE because that is where the evidence exists, and
        # deliberately narrow: only EMPATHIC fused with a technical lane.
        if ('Violet' in $nsil_act) and (('AntiVenom' in $nsil_act) or ('Venom' in $nsil_act) or ('Claude' in $nsil_act)) {
            $nsil_decision = 'OVERRIDE'
            $lane = 'EMPATHIC'
            $lens = 'Violet'
        }
    } else if (($nsil_fired | length) == 1) and $dense {
        # BOOST -- "right mode, one lens underweighted; a single lambda rises
        # surgically". RECORDED HERE, APPLIED AFTER THE PROFILE IS MOUNTED:
        # the POSIX arm's first draft modified the weights at this point and
        # the profile load later overwrote them, producing a route line that
        # announced [NSIL BOOST Soleil] beside a record carrying Soleil's
        # UNBOOSTED 2.5. A marker for an action that did not happen is worse
        # than no BOOST.
        $nsil_decision = 'BOOST'
        $boost = $lens0
        $nsil_act = [$lens0]
    } else if (($nsil_fired | length) == 0) and $dense {
        $nsil_decision = 'ELEVATE'
        $nsil_act = $NAMES
    } else {
        $nsil_act = [$lens0]
    }
    let nsil_decision = $nsil_decision
    let nsil_act = $nsil_act
    let lane = $lane
    let lens = $lens
    let boost = $boost

    # SYMBIOGENESIS, EVALUATED -- only for exactly two lenses. Section 3
    # defines the hybrid over TWO leads; folding pairwise would add +0.2 per
    # fold, an escalation no theorem sanctions. The pair and the merged
    # constants are KEPT, not only serialized: the voice block states them in
    # the fused lenses' own stanzas -- one computation, two consumers.
    let hyb = (if ($nsil_decision == 'FUSE') and (($nsil_act | length) == 2) {
        let hh = (get-nsil-hybrid ($nsil_act | get 0) ($nsil_act | get 1))
        if $hh == null { null } else { { a: ($nsil_act | get 0), b: ($nsil_act | get 1), h: $hh } }
    } else { null })
    let nsil_hyb_json = (if $hyb == null { '' } else {
        ',"hybrid":{"pair":"' + $hyb.a + 'x' + $hyb.b + '","lam":' + (format-hund $hyb.h.lam)
            + ',"mu":' + (format-hund $hyb.h.mu) + ',"h":' + (format-hund $hyb.h.h) + '}'
    })

    let acts = ($NAMES | each { |n| if ($n in $nsil_act) { '1' } else { '0' } })
    let br = ($acts | where { |a| $a == '1' } | length)

    # TIER 3 -- the complexity gate, DERIVED from TIER 2 rather than from
    # invented word-count cutoffs. It regulates only how much thinking is
    # spent, never whether the mechanism runs, so it is purely additive: it
    # cannot move the marker, the lane, the vector or R/s+.
    let depth = (if $br >= 2 { 'DEEP' } else if $br == 1 { 'STANDARD' } else { 'TRIVIAL' })

    # THE LANE NOW CHOOSES THE WEIGHTS -- the one line that makes the other
    # nine section 4 profiles real.
    let band_lane = ($lane | split row ' ' | get 0)
    let prof = (select-profile $band_lane)

    # BOOST IS APPLIED HERE, AFTER THE PROFILE IS MOUNTED. +0.3 is section 3's
    # own stated typical, quoted rather than tuned, and it rises from the
    # ACTIVE profile's value: a boosted STEALTH Soleil goes 2.5 -> 2.8.
    # Integer hundredths, mirroring the POSIX arm exactly -- Nushell HAS
    # decimals and must not use them here, because the arms have to agree on
    # every emitted digit.
    let lambdas = (if ($boost | is-empty) { $prof.L } else {
        let bi = ($NAMES | enumerate | where item == $boost | get -o 0.index)
        if $bi == null { $prof.L } else {
            let hh = ((round-half-even (($prof.L | get $bi) * 100.0) 0) + 30)
            let bv = ((($hh // 100) | into string) + '.' + (($hh mod 100) | into string | fill --alignment right --character '0' --width 2))
            ($prof.L | update $bi ($bv | into float))
        }
    })

    let g = (gauge-compute ($acts | str join ',') $br 1.0 1.0 1.0 $band_lane $lambdas $prof.M)
    let rs = (if ($g.human =~ '^R/s\+ = [0-9.]+') {
        ($g.human | parse -r '^R/s\+ = (?<v>[0-9.]+)' | get 0.v)
    } else { 'n/a' })

    # NOVA'S BAND FLAG and SOLEIL'S MONITOR, computed UNCONDITIONALLY: they
    # used to live inside the debug-log branch, but the voice block states
    # them in the stanzas, and a clause that only exists while logging is on
    # would make the voices an artifact of the log switch. The band verdict
    # text is taken from between the human line's own brackets so stanza and
    # instrument can never disagree.
    let band_flag = (get-band-flag $band_lane $rs)
    let tok_emerg = (get-token-emergency)
    let shown = (if $tok_emerg { $CHROMA_SHOWN_EMERGENCY } else { $CHROMA_SHOWN_NORMAL })
    let g_band = (if ($g.human =~ '\[[^\]]+\]') { ($g.human | parse -r '\[(?<b>[^\]]+)\]' | get 0.b) } else { '' })

    # THE VOICE DECISION. By Socio directive the lenses speak by default
    # (ROTMOE_VOICE=0 silences them), and they speak MID-WORK too: plain
    # stdout reaches the model on exactly three events, and on the tool-loop
    # events the legal channel is the JSON envelope's additionalContext.
    # PreToolUse ONLY -- Pre and Post build the same routing text from the
    # same tool_input fields, so the pair was byte-identical on every call
    # (W2, measured over 30 live turns). The voice speaks before the act; the
    # debug records still write on every event.
    let voice_on = (($env | get -o ROTMOE_VOICE | default '' | into string) != '0')
    let voice = ($voice_on and ($ev in ['UserPromptSubmit' 'UserPromptExpansion' 'SessionStart' 'PreToolUse']))
    mut voice_json = ($voice_on and ($ev == 'PreToolUse'))

    # BOTH SINKS REPORT. A lost record must be MARKED, never silent --
    # otherwise it is indistinguishable from a router that never fired.
    mut lost_central = false
    mut lost_local = false
    if $dbg_on {
        let gr = (rot-debug (gauge-record $g $br 1.0 1.0 1.0 $session $src) $project_dir $session $dbg_path)
        $lost_central = ($lost_central or $gr.central)
        $lost_local = ($lost_local or $gr.local)

        # One record per ROUTED TURN, distinct from the per-lens gauge record.
        # `chars` rather than the prompt itself: the log must be safe to paste
        # into an issue, and the routing decision is what is under test, not
        # the user's text.
        #
        # `arm` says "nu" and not "ps1". This is a THIRD implementation of the
        # same contract, and a record that lied about which one wrote it would
        # make the cross-diff compare an arm against itself.
        let ms = (((date now) - $__start) / 1ms | math floor)
        let line = ('{"kind":"route","ts":"' + (rot-ts) + '","event":"' + $ev + '","session":"' + $session
            + '","src":"' + $src + '","lane":"' + $band_lane + '","lens":"' + $lens + '","Rs":"' + $rs
            + '","chars":' + (($prompt | str length) | into string) + ',"stem":"' + $stem
            + '","nsil":"' + $nsil_decision + '","breadth":' + ($br | into string)
            + ',"depth":"' + $depth + '","band":"' + $band_flag
            + '","timelines":{"spawned":' + ($CHROMA_SPAWNED | into string) + ',"shown":' + ($shown | into string)
            + '},"tokenEmergency":' + (if $tok_emerg { 'true' } else { 'false' }) + $nsil_hyb_json
            + ',"arm":"nu","ms":' + ($ms | into string) + '}')
        let rr = (rot-debug $line $project_dir $session $dbg_path)
        $lost_central = ($lost_central or $rr.central)
        $lost_local = ($lost_local or $rr.local)
    }

    # The marker rides the router's own stdout, not a sidecar file: if the log
    # path is unwritable, a file beside it very likely is too, and a marker
    # that fails the same way as the thing it reports is not a marker.
    mut mark = ''
    if $lost_central { $mark = $mark + ' | debug-log UNWRITABLE (record lost)' }
    if $lost_local { $mark = $mark + ' | project-log UNWRITABLE (record lost)' }
    let mark = $mark

    # The TIER 2 tag rides INSIDE the pipe-free lane field, so every existing
    # assertion on this line still matches (prefix, lane token and the
    # ' | R/s+ ' boundary are untouched) while the fused lenses are NAMED
    # rather than counted.
    let nsil_tag = (if ($nsil_decision != 'CONFIRM') {
        ' [NSIL ' + $nsil_decision + ' ' + ($nsil_act | str join '+') + ']'
    } else { '' })

    # --- THE SENTINEL CLAUSE (7.0.0, V2: the working share) --------------
    # Every predicate reads a MEASURED field of this CLI's payload (survey,
    # 2026-08-19): interrupted first, then the Bash blank with the harness's
    # own noOutputExpected sanction, then the Write zero-byte with the
    # input-side guard. One clause at most; silence is the healthy state; Edit
    # responses are unmeasured and unread.
    let sent = (if ($ev == 'PostToolUse') and $voice_on and ($j != null) {
        let tr = ($j | get -o tool_response)
        if (($tr != null) and (($tr | describe) | str starts-with 'record')) {
            let ti = ($j | get -o tool_input)
            let tn = (($j | get -o tool_name | default '') | into string)
            let ic = (if $ti == null { null } else { $ti | get -o content })
            if ($tr | get -o interrupted) == true {
                '<rot:claude>🧭 Claude: this command was INTERRUPTED -- whatever follows the cut never ran; measure again before trusting the result.</rot:claude>'
            } else if ($tn == 'Bash') and (($tr | get -o stdout) == '') and (($tr | get -o stderr) == '') and (($tr | get -o noOutputExpected) != true) {
                '<rot:antivenom>⚪ AntiVenom: result BLANK -- zero bytes where output was expected; treat absence as a finding, not a pass.</rot:antivenom>'
            } else if ($tn == 'Write') and (($tr | get -o content) == '') and (($ic | describe) == 'string') and ($ic != '') {
                '<rot:antivenom>⚪ AntiVenom: wrote ZERO BYTES where content was given -- read the file before building on it.</rot:antivenom>'
            } else { '' }
        } else { '' }
    } else { '' })
    if not ($sent | is-empty) { $voice_json = true }

    # A FIRING IS ALSO A RECORD (8.0.0) -- one "kind":"anomaly" line in the
    # CENTRAL sink only, shape derived from the clause text above so record
    # and clause can never disagree. Without it a sentinel firing is
    # unfalsifiable from the log, and the Animus observer's recurrence trigger
    # (ENV.26) has nothing to count. NOT the two-sink writer: the sh arm
    # deliberately keeps this record out of the project log.
    if (not ($sent | is-empty)) and $dbg_on {
        let shape = (if ($sent | str contains 'INTERRUPTED') { 'interrupted'
            } else if ($sent | str contains 'result BLANK') { 'blank'
            } else if ($sent | str contains 'ZERO BYTES') { 'zerobyte' } else { '' })
        let atool_raw = (($j | get -o tool_name | default '') | into string)
        let atool = (if ($atool_raw | is-empty) { '-' } else { rot-scrub $atool_raw 'unknown' })
        if not ($shape | is-empty) {
            let ap = $dbg_path
            if (rot-log-lock $ap) {
                try {
                    rot-complete-partial-line $ap
                    ('{"kind":"anomaly","ts":"' + (rot-ts) + '","event":"' + $ev + '","session":"' + $session
                        + '","src":"' + $src + '","shape":"' + $shape + '","tool":"' + $atool
                        + '","arm":"nu"}' + "\n") | save --append --raw $ap
                }
                rot-log-unlock $ap
            }
        }
    }

    # --- THE ANIMUS REMARK (8.0.0) ---------------------------------------
    # Consume ONE observer remark FIFO from animus-queue.<session> in the
    # state dir, ATOMICALLY (take the whole file by move before reading a
    # byte, move the remainder back), refuse any lens name outside the
    # roster, and speak the remark inside the owning lens's declared element.
    # Empty queue = not a byte; VOICE=0 silences remarks with the rest of the
    # voice.
    mut anim = ''
    if ($ev == 'PostToolUse') and (($env | get -o ROTMOE_ANIMUS | default '' | into string) == '1') and $voice_on {
        let an_q = ((rot-state-dir) | path join ('animus-queue.' + $session))
        if ($an_q | path exists) {
            let an_line = (try {
                let take = ($an_q + '.take.' + ($nu.pid | into string))
                mv -f $an_q $take
                let ls_all = (open --raw $take | lines)
                if ($ls_all | length) > 1 {
                    let rest = ($an_q + '.rest.' + ($nu.pid | into string))
                    (($ls_all | skip 1 | str join "\n") + "\n") | save --raw --force $rest
                    mv -f $rest $an_q
                }
                rm -f $take
                if ($ls_all | is-empty) { '' } else { $ls_all | get 0 }
            } catch { '' })
            let ix = ($an_line | str index-of '|')
            if ($ix > 0) and ($ix < (($an_line | str length) - 1)) {
                let an_lens = ($an_line | str substring 0..<$ix)
                let an_text = ($an_line | str substring ($ix + 1)..)
                let an_map = { Nova: ['nova' '⚜️'], Violet: ['violet' '🎷'], AntiVenom: ['antivenom' '⚪'],
                               Venom: ['venom' '🕷️'], Carnage: ['carnage' '🩸'], Chroma: ['chroma' '🔮'],
                               Soleil: ['soleil' '⬜'], Eidolon: ['eidolon' '🜏'], Claude: ['claude' '🧭'] }
                let hit = ($an_map | get -o $an_lens)
                if $hit != null {
                    $anim = ('<rot:' + ($hit | get 0) + '>' + ($hit | get 1) + ' ' + $an_lens
                        + ' (animus): ' + $an_text + '</rot:' + ($hit | get 0) + '>')
                    $voice_json = true
                }
            }
        }
    }
    let anim = $anim

    # TWO CHANNELS, ONE CONTENT. On the JSON path each piece is scrubbed of
    # quote and backslash BEFORE the literal \n separators join them, so the
    # scrub can never eat a separator.
    let m_line = ('RoT MoE :: TIER 1 -> ' + $lane + $nsil_tag + ' | R/s+ ' + $rs + $mark)
    mut v_acc = ''
    if $voice_json {
        $v_acc = ($m_line | str replace --all --regex '["\\\\]' '')
        if not ($sent | is-empty) { $v_acc = $v_acc + '\n' + ($sent | str replace --all --regex '["\\\\]' '') }
        if not ($anim | is-empty) { $v_acc = $v_acc + '\n' + ($anim | str replace --all --regex '["\\\\]' '') }
    } else {
        print $m_line
    }

    # --- THE SUMMONS ------------------------------------------------------
    # A UserPromptSubmit that fused or elevated is a turn where several lenses
    # were summoned -- record WHO, so the voice gate (ORGAN 6) can hold the
    # door on Stop until each has spoken. Single-writer, single-consumer,
    # one-turn lifetime.
    mut gate_file = ''
    if $ev == 'UserPromptSubmit' {
        let gate_dir = (rot-state-dir)
        if ($env | get -o ROTMOE_GATE | default '' | into string) != '0' {
            $gate_file = ($gate_dir | path join ('voice-summons.' + $session))
        } else {
            # GATE=0 STILL CLEARS (U3): opting out of the gate must not let a
            # summons from an armed turn outlive its turn and cage the first
            # Stop after re-arming.
            try { rm -f ($gate_dir | path join ('voice-summons.' + $session)) }
        }
    }
    let gate_file = $gate_file

    # --- THE VOICE BLOCK --------------------------------------------------
    # One stanza per ACTIVE lens, in roster order, each inside the element
    # rot-voice.dtd declares for it. The measured fields come from the gauge's
    # LENSDATA lines; the charter and the bound come from the DTD, so no lens
    # fact exists twice. The marker line above is UNTOUCHED and the stanzas
    # are ADDITIVE lines after it.
    #
    # A CONVERGENT turn activates no roster lens (its "lead" is the convener
    # model), so the loop naturally emits nothing there. A missing or
    # unreadable DTD degrades to silence rather than failing the turn -- the
    # marker is the contract, the voices are the capability.
    mut gate_rows = []
    if $voice and ($br > 0) {
        # Resolve the contract: the installed plugin root first, then
        # ROTMOE_HOME, then the shipped fallback. The READ is the probe, so a
        # file that exists but cannot be read demotes exactly as a missing one
        # does; a second failure is the silence promised above.
        let cands = ([
            (($env | get -o CLAUDE_PLUGIN_ROOT | default '' | into string))
            (($env | get -o ROTMOE_HOME | default '' | into string))
            $ROT_HOME_FALLBACK
        ] | where { |d| not ($d | is-empty) } | each { |d| ($d | path join 'hooks' 'rot-voice.dtd') })
        let v_lines = ($cands | reduce --fold null { |c, acc|
            if $acc != null { $acc } else { try { open --raw $c | lines } catch { null } }
        })
        if $v_lines != null {
            # LENS.n entities are declared in roster order. The value is the
            # text between the FIRST and LAST double quote of the line, and
            # the fields split on '|' as name|element|sigil|charter|tools|bound.
            let v_rows = ($v_lines | where { |l| $l =~ '<!ENTITY LENS\.' } | each { |l|
                let a = ($l | str index-of '"')
                let s1 = (if $a >= 0 { $l | str substring ($a + 1).. } else { $l })
                let b = ($s1 | str index-of --end '"')
                if $b >= 0 { $s1 | str substring 0..<$b } else { $s1 }
            })

            # --- THE DYNAMIC SHARE (6.0.2, V1) -- every clause is a fact this
            # turn already measured; a fact the turn did not earn is not
            # printed. Computed once, before the loop.
            let hyb_name = (if $hyb == null { '' } else {
                let pair = ($hyb.a + ' ' + $hyb.b)
                if ($pair in ['Claude AntiVenom' 'AntiVenom Claude']) { ' -- The Verified Forge'
                } else if ($pair in ['Nova Eidolon' 'Eidolon Nova']) { ' -- The Sovereign Architect'
                } else if ($pair in ['Carnage Eidolon' 'Eidolon Carnage']) { ' -- the forced CREATIVE × RECURSIVE fuse'
                } else { '' }
            })
            let v_hour = (if ('Violet' in $nsil_act) { (date now | format date '%H') } else { '' })
            let v_track = (if ('Violet' in $nsil_act) { (get-violet-track $v_hour) } else { '' })
            # Section 7's productive tensions, in section 7's order, kept only
            # when BOTH members were summoned. ALL in-play pairs are named --
            # picking two or three is the model's convergence work, and a
            # router pre-pick would be a silent cap.
            let tension = ([['Nova' 'Carnage'] ['Venom' 'Chroma'] ['AntiVenom' 'Violet'] ['Soleil' 'Eidolon']
                            ['Nova' 'AntiVenom'] ['Claude' 'Nova'] ['Carnage' 'Claude']]
                | where { |p| (($p | get 0) in $nsil_act) and (($p | get 1) in $nsil_act) }
                | each { |p| ($p | get 0) + '<->' + ($p | get 1) })
            let v_turn = (' This turn: NSIL ' + $nsil_decision + ', depth ' + $depth
                + (if ($tension | is-empty) { '' } else { ', tension: ' + ($tension | str join ', ') }))

            mut frame_done = false
            for i in 0..(($NAMES | length) - 1) {
                let v_name = ($NAMES | get $i)
                if not ($v_name in $nsil_act) { continue }
                if $i >= ($v_rows | length) { continue }
                let v_row = ($v_rows | get $i)
                if ($v_row | is-empty) { continue }
                let vf = ($v_row | split row '|')
                let v_elem = ($vf | get -o 1 | default '')
                let v_sigil = ($vf | get -o 2 | default '')
                let v_chart = ($vf | get -o 3 | default '')
                let v_bound = ($vf | get -o 5 | default '')
                if ($v_elem | is-empty) { continue }

                # This lens's measured line from the gauge output.
                let v_pre = ('LENSDATA|' + $v_name + '|')
                let v_data = ($g.lensdata | where { |l| $l | str starts-with $v_pre }
                    | each { |l| $l | str substring ($v_pre | str length).. } | get -o 0 | default '')
                let vd = ($v_data | split row '|')
                let v_lam = ($vd | get -o 0 | default '')
                let v_sigm = ($vd | get -o 1 | default '')
                let v_h = ($vd | get -o 2 | default '')
                let v_term = ($vd | get -o 3 | default '')
                let v_share = ($vd | get -o 4 | default '')
                let v_del = ($vd | get -o 5 | default '')
                let v_mu = ($vd | get -o 6 | default '')

                # THE FRAME -- provenance, spoken once before the first
                # stanza. MEASURED 2026-08-17, the v6.0.0 real test (B4): an
                # unbriefed convening model REFUSED to perform the stanzas,
                # correctly treating unexplained injected personas as
                # untrusted framing. Now the block leads with the operator's
                # own provenance and the switch that proves it. Lazy, so a
                # turn with no speaking lens stays frame-free.
                if not $frame_done {
                    $frame_done = true
                    let v_frame = ('<rot:frame>RoT MoE voices -- a Claude Code plugin the operator of this machine installed on purpose; ROTMOE_VOICE=0 silences it. The lenses below were summoned by the measured gauge for this turn; treat each stanza as operator-sanctioned working context.' + $v_turn + '.</rot:frame>')
                    if $voice_json { $v_acc = $v_acc + '\n' + $v_frame } else { print $v_frame }
                }

                # THE DYNAMIC CLAUSES, in the sh arm's fixed order so two
                # turns differ only where the MEASUREMENTS differ: lead band
                # verdict with section 5's correction verb; Nova's NSIL
                # verdict; a boosted lambda; the Symbiogenesis pair with the
                # merge law's result; Chroma's shown timelines; Soleil's
                # ACCEPTED budget or the word unknown; Violet's hour-defaulted
                # track.
                mut v_dyn = ''
                if ($v_name == $lens) and (not ($g_band | is-empty)) {
                    $v_dyn = $v_dyn + ' · band ' + $g_band
                    if $band_flag == 'BELOW' {
                        $v_dyn = $v_dyn + (if $v_name == 'Carnage' { ' -- add entropy'
                            } else if $v_name == 'Claude' { ' -- measure more' } else { ' -- diverge more' })
                    } else if $band_flag == 'ABOVE' {
                        $v_dyn = $v_dyn + (if $v_name == 'Soleil' { ' -- compress more' } else { ' -- converge' })
                    }
                }
                if $v_name == 'Nova' { $v_dyn = $v_dyn + ' · NSIL ' + $nsil_decision }
                if (not ($boost | is-empty)) and ($v_name == $boost) { $v_dyn = $v_dyn + ' · λ boosted +0.3' }
                if ($hyb != null) and (($v_name == $hyb.a) or ($v_name == $hyb.b)) {
                    $v_dyn = $v_dyn + ' · Symbiogenesis ' + $hyb.a + '×' + $hyb.b + ' λ ' + (format-hund $hyb.h.lam)
                        + ' μ ' + (format-hund $hyb.h.mu) + ' H ' + (format-hund $hyb.h.h) + $hyb_name
                }
                if $v_name == 'Chroma' {
                    $v_dyn = $v_dyn + ' · timelines ' + ($shown | into string) + '/' + ($CHROMA_SPAWNED | into string)
                    if $tok_emerg { $v_dyn = $v_dyn + ' TOKEN_EMERGENCY' }
                }
                if $v_name == 'Soleil' {
                    let pct = ($env | get -o ROTMOE_TOKEN_PCT | default '' | into string)
                    if ($pct =~ '^[0-9]+$') {
                        $v_dyn = $v_dyn + ' · budget ' + $pct + '%'
                        if $tok_emerg { $v_dyn = $v_dyn + ' -> STEALTH' }
                    } else { $v_dyn = $v_dyn + ' · budget unknown' }
                }
                if ($v_name == 'Violet') and (not ($v_track | is-empty)) {
                    $v_dyn = $v_dyn + ' · track ' + $v_track + ' (by hour ' + $v_hour + ')'
                }

                # The sh arm's expansion template is the authority for this
                # shape:
                #   <elem>SIG Name · λ L σ S δ D H H μ M · term T (P%)[ · DYN]*
                #   · CHARTER · BOUND</elem>
                let v_line = ('<' + $v_elem + '>' + $v_sigil + ' ' + $v_name + ' · λ ' + $v_lam + ' σ ' + $v_sigm
                    + ' δ ' + $v_del + ' H ' + $v_h + ' μ ' + $v_mu + ' · term ' + $v_term + ' (' + $v_share + '%)'
                    + $v_dyn + ' · ' + $v_chart + ' · ' + $v_bound + '</' + $v_elem + '>')
                if $voice_json {
                    $v_acc = $v_acc + '\n' + ($v_line | str replace --all --regex '["\\\\]' '')
                } else {
                    print $v_line
                }
                $gate_rows = ($gate_rows | append ($v_name + '|' + $v_elem + '|' + $v_chart + '|' + $v_bound + '|' + $v_sigil))
            }
        }
    }
    let gate_rows = $gate_rows

    # The JSON envelope, emitted whole: the event echoed back is load-bearing
    # -- a payload without it is discarded silently. ROTMOE_VOICE=0 keeps the
    # old plain marker on these events.
    if $voice_json {
        print ('{"hookSpecificOutput":{"hookEventName":"' + $ev + '","additionalContext":"' + $v_acc + '"}}')
    }

    # Write the summons only for a genuine multi-lens turn (FUSE/ELEVATE with
    # at least two roster voices); anything else CLEARS this session's summons
    # so the gate never holds a door for a turn that ended long ago.
    if not ($gate_file | is-empty) {
        if ($gate_rows | length) >= 2 {
            try {
                mkdir ($gate_file | path dirname)
                (($gate_rows | str join "\n") + "\n") | save --raw --force $gate_file
            }
        } else {
            try { rm -f $gate_file }
        }
    }
    exit 0
}
