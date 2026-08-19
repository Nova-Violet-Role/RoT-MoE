# This file is part of RoT MoE.
# SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
# Copyright 2026 Saimonokuma.
#
# =============================================================================
# rot-router.ps1 -- the RoT MoE router, Windows arm.
#
# This is the SAME router as hooks/rot-router.sh, and "same" here has a
# mechanical meaning rather than a moral one: checker/cross-diff.sh runs both
# over one corpus and requires BYTE-IDENTICAL output on every row. Two
# implementations that agree is a truth a single green cannot fake -- a shared
# bug has to be made twice, in two languages, by hand.
#
# InvariantCulture on every number, exactly as rot-lean-inject.ps1:406-415 does.
# Under a comma-decimal locale "0.09" renders "0,09", the decimal separator
# collides with the field separator, and the emitted vector stops parsing. The
# POSIX arm gets the same guarantee from LC_NUMERIC=C. This is the single most
# likely place for the two arms to silently diverge, which is why the cross-diff
# compares the formatted STRING and not the number.
# =============================================================================

[CmdletBinding()]
param(
  [string] $Vector,
  [int]    $Breadth = 0,
  [double] $M = 1.05,
  [double] $C = 1.0,
  [double] $T = 1.0,
  # THE PROFILE IS SAYABLE OUT LOUD, mirroring the POSIX arm's --profile. Empty
  # means "use the default", which is CONVERGENT -- the convener. Anything that
  # needs a specific table asks for it by name, so the weights behind a number
  # are never implicit again.
  [string] $Profile,
  [string] $Lane,
  [string] $Route,
  [switch] $Version
)

$ErrorActionPreference = 'Stop'
$inv = [System.Globalization.CultureInfo]::InvariantCulture

# Start of THIS invocation, used only by the debug log's per-turn `ms` field.
# Taken here rather than later so the figure includes the routing work itself,
# not just the tail of it -- a latency number that excludes the thing being
# measured is worse than none.
$__rotStart = Get-Date

if ($Version) { Write-Output 'rot-router.ps1 1.0.0'; exit 0 }

# --- TIER 1 ------------------------------------------------------------------
# Stems quoted from rot-lean.md section 3. `code` and `art` are deliberately
# absent -- see the POSIX arm for the reasoning; both arms must delete the same
# two or the cross-diff will catch it.
#
# ORDER IS THE CONTRACT. route_exact in lean/Proofs/RotRoute.lean characterises
# every lane in both directions against exactly this order, so a reordering here
# is a proved defect rather than a matter of taste.
$Tier1 = @(
  @{ Mode = 'FORGE';      Lead = 'Claude';    Stems = @('run','build','install','deploy','reproduce','ship','lake','theorem','tactic','sorry','mathlib','.lean','prove','proof','lemma','lean','qed') },
  @{ Mode = 'CLINICAL';   Lead = 'AntiVenom'; Stems = @('debug','error','bug','fix','secur','audit','verif','test','cve','segfault','crash','panic','leak','regress','traceback') },
  @{ Mode = 'EXECUTIVE';  Lead = 'Venom';     Stems = @('decid','urgenc','strike','direct','declar','now','conclud') },
  @{ Mode = 'EMPATHIC';   Lead = 'Violet';    Stems = @('emot','feel','grief','lonel','soul','story','human','tired','lost','relation') },
  @{ Mode = 'STRATEGIC';  Lead = 'Nova';      Stems = @('strateg','plan','goal','roadmap','priorit','legal','recommend','analyz') },
  @{ Mode = 'CREATIVE';   Lead = 'Carnage';   Stems = @('creativ','chaos','surreal','disrupt','paradox','dream','invent','brainstorm','ideat','imagin','tagline') },
  @{ Mode = 'PREDICTIVE'; Lead = 'Chroma';    Stems = @('futur','scenar','predict','trend','forec','likel','horizon','next') },
  @{ Mode = 'STEALTH';    Lead = 'Soleil';    Stems = @('encod','optim','token','compress','concise','byte','distill') },
  @{ Mode = 'RECURSIVE';  Lead = 'Eidolon';   Stems = @('evolv','recurs','meta','architect','refactor','ontolog','hybrid') }
)

# CONVERGENT is the only lane with no lead LENS -- by design, all nine
# co-reason and none leads. It used to print the literal 'none', which reads as
# a null: as though the router failed to decide, rather than decided that
# nobody leads. What convenes the nine is the MODEL the user chose, so that is
# what gets named.
#
# MEASURED (live UserPromptSubmit payload, 2026-08-03): the payload carries
# session_id, transcript_path, cwd, prompt_id, permission_mode, hook_event_name
# and prompt -- and NO model key. It is therefore read from the settings file
# the client itself writes, degrading at every step rather than failing:
# env override -> settings.json -> the literal 'model'. Never 'none', never
# empty; a hook that emits an empty lead is worse than one that emits a
# generic word.
function Get-Convener {
  if ($env:ROTMOE_MODEL) { return $env:ROTMOE_MODEL }
  $cfgDir = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $HOME '.claude' }
  $cfg = Join-Path $cfgDir 'settings.json'
  if (Test-Path -LiteralPath $cfg) {
    try {
      $j = Get-Content -LiteralPath $cfg -Raw | ConvertFrom-Json
      if ($j.model) { return [string] $j.model }
    } catch { }
  }
  return 'model'
}

# A STEM MUST START A WORD -- the POSIX arm's `fired`, character for character.
# See hooks/rot-router.sh for the full note and lean/Proofs/RotStem.lean for the
# proof; the short version is that `prove` cannot be a substring stem because
# "improve" contains it, and neither can `lemma` ("dilemma") or `lean`
# ("cleaning"). The same flaw was already live for `fix` ("prefix"), `now`
# ("known") and `test` ("latest").
#
# Written with an index scan rather than a regex ON PURPOSE. A regex would need
# every stem escaped, and `.lean` -- a stem that begins with a metacharacter --
# is exactly the case that would silently become "any character followed by
# lean". The dot is also why the punctuation-led fallback exists: "basic.lean"
# has no word boundary before it.
function Test-WordChar([char] $c) {
  return ([char]::IsLetterOrDigit($c))
}

function Test-StemFires([string] $p, [string] $stem) {
  if ([string]::IsNullOrEmpty($stem)) { return $false }
  if (-not (Test-WordChar $stem[0])) { return $p.Contains($stem) }   # ".lean"
  $i = $p.IndexOf($stem, [System.StringComparison]::Ordinal)
  while ($i -ge 0) {
    if ($i -eq 0 -or -not (Test-WordChar $p[$i - 1])) { return $true }
    $i = $p.IndexOf($stem, $i + 1, [System.StringComparison]::Ordinal)
  }
  return $false
}

# MATCHED_STEM -- the POSIX arm's `MATCHED_STEM`, and it must stay identical.
#
# The debug log records `chars`, never the prompt: a log has to be safe to paste
# into an issue. The cost, measured by trying to diagnose a mis-route from one:
# the lane is recorded and the REASON is not. A stem is the missing datum and it
# is safe to emit -- stems come from a CLOSED SET defined in this file, so it
# leaks nothing beyond which fixed vocabulary word appeared, which IS the
# routing decision.
#
# `Invoke-Route` therefore returns "<LANE LENS>|<stem>" exactly as the POSIX
# `route` does, and `--route` prints the lane alone so that output is unchanged.
# Splitting on the LAST `|` keeps a convener model name containing one intact.
function Invoke-Route([string] $Prompt) {
  $p = $Prompt.ToLowerInvariant()
  foreach ($lane in $Tier1) {
    foreach ($stem in $lane.Stems) {
      if (Test-StemFires $p $stem) { return "$($lane.Mode) $($lane.Lead)|$stem" }
    }
  }
  return "CONVERGENT $(Get-Convener)|"
}

# --- TIER 2: NSIL -- FUSE and ELEVATE ----------------------------------------
# The POSIX arm's `nsil_active_lenses`, decision for decision. See the long note
# in hooks/rot-router.sh: FUSE fires when >= 2 DISTINCT lanes match, ELEVATE
# when none match and the prompt carries at least one word per lens. The density
# floor is $Names.Count -- derived from the roster, not written down as 9 -- and
# it is a MODELLING CHOICE rather than a measurement, said plainly in both arms.
#
# Lenses come back in ROSTER order, never match order, so the two arms cannot
# disagree about bit order in the activity vector.
function Get-NsilActiveLenses([string] $Prompt) {
  $p = $Prompt.ToLowerInvariant()
  $hit = @()
  foreach ($lane in $Tier1) {
    foreach ($stem in $lane.Stems) {
      if (Test-StemFires $p $stem) { $hit += $lane.Lead; break }
    }
  }
  $out = @()
  foreach ($n in $Names) { if ($hit -contains $n) { $out += $n } }
  # `return $out`, NOT `return ,$out`. The unary comma wraps the result in an
  # OUTER array, so `@(Get-NsilActiveLenses ...)` at the call site came back with
  # Count = 1 for every prompt -- including one that fired no lane at all. Every
  # turn therefore fell to the single-lane branch and this whole layer was dead
  # code that printed the old line. Caught by arm-vs-arm parity, which is exactly
  # what that gate is for: the POSIX arm said FUSE and this one said nothing.
  return $out
}

# Split the two fields on the LAST separator, so a model name containing `|`
# cannot eat the stem. Used by both callers; a second inline split would be a
# second source of truth for the same contract.
function Split-Routed([string] $Routed) {
  $i = $Routed.LastIndexOf('|')
  if ($i -lt 0) { return @($Routed, '') }
  return @($Routed.Substring(0, $i), $Routed.Substring($i + 1))
}

# --- THE GAUGE ---------------------------------------------------------------
# LENS ORDER is fixed and load-bearing: corpus, POSIX arm and this file must
# agree on which slot is which lens. FORGE weights quoted from rot-lean.md
# section 4, never re-derived.
$Names   = @('Nova','Violet','AntiVenom','Venom','Carnage','Chroma','Soleil','Eidolon','Claude')
# THE TEN SECTION 4 PROFILES -- the lane chooses the weights. Until 2026-08-13
# both arms carried only the FORGE table and used it for every lane, so nine of
# the ten profiles were documentation: a CLINICAL turn scored Anti-Venom at
# 1.9/1.10 instead of her CLINICAL 2.5/1.20. Roster order throughout.
#
# ONE PRINCIPLED SUBSTITUTION, DISCLOSED, IDENTICAL TO THE POSIX ARM. Section 4
# comes from the OMEGA codex, which ships eight symbiotes; the ninth lens
# (Claude) and FORGE come from CLAUDE.md, so the nine non-FORGE profiles say
# nothing about Claude. Every profile silent about a lens uses that lens's
# SECTION 2 DEFAULT -- Claude 1.5/1.05 -- sourced, not guessed.
$Profiles = @{
  CONVERGENT = @{ L = @(1.6,1.3,1.5,1.7,1.1,1.2,0.8,1.4,1.5); M = @(1.00,0.95,1.00,1.05,1.20,1.25,0.90,1.10,1.05) }
  CLINICAL   = @{ L = @(1.4,0.7,2.5,1.0,0.5,1.0,1.2,1.3,1.5); M = @(1.00,0.90,1.20,1.00,0.80,1.10,1.00,1.10,1.05) }
  EXECUTIVE  = @{ L = @(1.5,0.8,1.3,2.4,0.7,1.1,1.0,1.0,1.5); M = @(1.05,0.90,1.00,1.20,1.00,1.10,0.90,1.00,1.05) }
  EMPATHIC   = @{ L = @(0.8,2.3,0.9,0.8,1.8,1.4,0.7,1.0,1.5); M = @(0.90,1.15,0.95,0.90,1.30,1.20,0.85,1.00,1.05) }
  STRATEGIC  = @{ L = @(2.2,0.9,1.8,1.6,0.7,1.5,0.6,1.3,1.5); M = @(1.15,0.95,1.00,1.10,1.20,1.25,0.90,1.10,1.05) }
  CREATIVE   = @{ L = @(1.0,1.6,0.8,0.7,2.5,1.2,0.9,1.5,1.5); M = @(1.00,1.15,0.90,1.00,1.35,1.10,0.85,1.15,1.05) }
  PREDICTIVE = @{ L = @(1.4,1.0,1.2,1.2,0.9,2.4,0.8,1.3,1.5); M = @(1.10,1.00,1.00,1.05,1.00,1.25,0.90,1.10,1.05) }
  STEALTH    = @{ L = @(0.7,0.6,1.5,0.8,0.5,0.7,2.5,1.0,1.5); M = @(0.90,0.85,1.10,0.90,0.80,0.90,1.20,1.00,1.05) }
  RECURSIVE  = @{ L = @(1.5,1.0,1.6,0.8,1.1,1.2,0.9,2.3,1.5); M = @(1.10,1.00,1.10,0.95,1.20,1.15,0.90,1.20,1.05) }
  FORGE      = @{ L = @(1.4,0.6,1.9,1.2,0.6,1.0,1.0,1.2,2.3); M = @(1.05,0.85,1.10,1.05,0.90,1.10,0.95,1.10,1.15) }
}

# NOVA'S BAND FLAG -- section 5's per-lens optimal R/s+ ranges, in hundredths,
# mirroring the POSIX arm. The band is PER LANE: Soleil's STEALTH range is
# 0.5-1.2 and Carnage's CREATIVE range is 1.5-3.5, so one global range would
# flag a lane permanently through no fault of its own. CONVERGENT and STRATEGIC
# share 1.0-2.0 because section 5 lists Nova once, for "Convergent/Strategic".
$Bands = @{
  CONVERGENT = @(100,200); STRATEGIC  = @(100,200); EMPATHIC = @(120,250)
  CLINICAL   = @( 80,150); EXECUTIVE  = @( 70,180); CREATIVE = @(150,350)
  PREDICTIVE = @(100,220); STEALTH    = @( 50,120); RECURSIVE = @( 80,150)
  FORGE      = @( 90,180)
}

# A FLAG, never a veto -- section 5 is explicit that out-of-range is a correction
# signal, not a refusal. Nothing branches on the result.
function Get-BandFlag {
  param([string]$Lane, [string]$Rs)
  if ($Rs -eq 'n/a') { return 'IN' }
  $b = if ($Bands.ContainsKey($Lane)) { $Bands[$Lane] } else { $Bands['FORGE'] }
  $v = [int][math]::Round([double]::Parse($Rs, $inv) * 100)
  if     ($v -lt $b[0]) { return 'BELOW' }
  elseif ($v -gt $b[1]) { return 'ABOVE' }
  else                  { return 'IN' }
}

# SOLEIL'S TOKEN_EMERGENCY_MONITOR, coupled to CHROMA'S TIMELINES. section 2:
# Soleil is "budget < 20% -> STEALTH"; Chroma "spawns 12 timelines; 5 shown, 3
# under TOKEN_EMERGENCY".
#
# THE BUDGET IS ACCEPTED, NEVER GUESSED. The UserPromptSubmit payload was
# measured to carry no token budget, and inferring one from prompt length would
# be inventing a reading and then acting on it. `ROTMOE_TOKEN_PCT` carries the
# percentage REMAINING when a caller knows it; absent means unknown, and unknown
# is NOT an emergency -- an alarm with no sensor attached must stay quiet.
$ChromaSpawned        = 12
$ChromaShownNormal    = 5
$ChromaShownEmergency = 3
$TokenFloorPct        = 20

function Get-TokenEmergency {
  $pct = $env:ROTMOE_TOKEN_PCT
  if ([string]::IsNullOrEmpty($pct)) { return $false }
  $n = 0
  if (-not [int]::TryParse($pct, [ref]$n)) { return $false }
  return ($n -lt $TokenFloorPct)
}

# VIOLET'S JAZZ TRACKS -- section 2's five names in charter order, mirroring
# the POSIX arm's VIOLET_TRACKS and its full reasoning: her charter selects
# by the query's EMOTIONAL FREQUENCY, which no shell can read; the clock is
# what the router CAN measure, the five names are themselves named for hours,
# so the stanza offers the hour's track as a DEFAULT and says so in as many
# words. checker/voice-contract.sh D11 holds the .sh list against her formula
# YAML; cross-arm agreement holds this copy against the .sh one.
$VioletTracks = @('MORNING_BLUES', 'AFTERNOON_SWING', 'NIGHT_SAXOPHONE', 'MIDNIGHT_RAIN', 'DAWN_ECHOES')

function Get-VioletTrack {
  param([string]$HH)
  $h = 0
  if (-not [int]::TryParse($HH, [ref]$h)) { return '' }
  if     ($h -ge 5  -and $h -le 11) { return $VioletTracks[0] }   # MORNING_BLUES
  elseif ($h -ge 12 -and $h -le 17) { return $VioletTracks[1] }   # AFTERNOON_SWING
  elseif ($h -ge 18 -and $h -le 22) { return $VioletTracks[2] }   # NIGHT_SAXOPHONE
  elseif ($h -eq 23 -or  $h -le 3)  { return $VioletTracks[3] }   # MIDNIGHT_RAIN
  elseif ($h -eq 4)                 { return $VioletTracks[4] }   # DAWN_ECHOES
  else                              { return '' }
}

# Unknown lane -> CONVERGENT, which section 3 already names as the default with
# no trigger, so the fallback is the spec's own answer rather than a shrug.
function Select-Profile {
  param([string]$Lane)
  $p = if ($Profiles.ContainsKey($Lane)) { $Profiles[$Lane] } else { $Profiles['CONVERGENT'] }
  $script:Lambdas = $p.L
  $script:Mus     = $p.M
  $script:RotProfile = $Lane
}

# THE DEFAULT IS CONVERGENT, LED BY NOVA -- not FORGE. Corrected 2026-08-13.
# CONVERGENT is the convening model itself: the lane that fires when the model
# takes the various lenses' responses and makes one answer out of them. When
# every lens holds a point of view and a solution is formed from them, that is
# the R/s+ CONVERGENCE POINT, the fulcrum of the engine. Section 3 already said
# "default with no trigger: CONVERGENT"; both arms were starting from FORGE,
# which is the hand's profile, not the convener's.
$Lambdas = $Profiles['CONVERGENT'].L
$Mus     = $Profiles['CONVERGENT'].M
$RotProfile = 'CONVERGENT'

# THE SECTION 2 DEFAULT ROSTER -- the table Symbiogenesis is defined over.
# $Lambdas/$Mus above are the FORGE PROFILE (section 4) and score the turn; they
# are NOT the operands of the merge law, which rot-lean.md section 3 defines over
# these defaults. nova_violet_hybrid in RotEigenform.lean is 33/20 =
# (1.6 + 1.3)/2 + 0.2, using Nova 1.6 and Violet 1.3 -- not the FORGE 1.4/0.6.
#
# HUNDREDTHS AS INTEGERS, matching the POSIX arm byte for byte. PowerShell has
# decimals and could compute this directly, and that is exactly why it must not:
# the two arms have to agree on every emitted digit, and floating point is where
# they would silently stop agreeing. Every value is an exact multiple of 0.01 and
# every lambda a multiple of 0.10, so integer hundredths reproduce the Lean
# rationals exactly, in both arms, with no rounding rule to keep in sync.
# H is the UPPER bound of each section 2 range (nova 7/20, violet 9/20).
$DefLam = @(160, 130, 150, 170, 110, 120,  80, 140, 150)
$DefMu  = @(100,  95, 100, 105, 120, 125,  90, 110, 105)
$DefH   = @( 35,  45,  30,  28,  55,  38,  22,  38,  30)

function Get-NsilHybrid {
  param([string]$A, [string]$B)
  $i = [Array]::IndexOf($Names, $A); $j = [Array]::IndexOf($Names, $B)
  if ($i -lt 0 -or $j -lt 0 -or $i -eq $j) { return $null }
  @{
    lam = [int]((($DefLam[$i] + $DefLam[$j]) / 2) + 20)
    mu  = [Math]::Max($DefMu[$i], $DefMu[$j])
    h   = [Math]::Max($DefH[$i],  $DefH[$j]) + 5
  }
}

# hundredths -> the same decimal string the POSIX arm's printf produces.
function Format-Hund { param([int]$V) '{0}.{1:d2}' -f [math]::Floor($V / 100), ($V % 100) }

# Mirrors ToString('0.##') / ('0.###'): round, then drop trailing zeros and a
# bare trailing dot. Written explicitly rather than relying on the format
# string, so that the rounding rule is visible next to the awk one it must match.
function Format-Num([double] $x, [int] $d) {
  $s = [Math]::Round($x, $d).ToString(('F' + $d), $inv)
  if ($s.Contains('.')) { $s = $s.TrimEnd('0').TrimEnd('.') }
  if ($s -eq '' -or $s -eq '-') { $s = '0' }
  return $s
}

# --- DEBUG LOG ---------------------------------------------------------------
# Set ROTMOE_DEBUG_LOG=<path> and every routing decision appends ONE JSON line
# carrying the whole computation: the lane, the lead lens, and for each of the
# nine lenses its lambda, mu, activity, delta, sigma, H and the resulting term.
#
# This exists because "the router works" was, until now, a claim backed by the
# router's own one-line summary. A summary cannot show you that lens 5 was
# multiplied by the wrong mu, or that a lens never participated at all. The log
# can, because it prints every factor that went into the sum -- so the reported
# R/s+ is reproducible by hand from the record.
#
# Failure here must never break a turn: the hook's job is to route, not to log.
# Every write is wrapped, and a failed write is silently dropped.
# Governed by lean/Proofs/RotDebugLog.lean. The tolerance below is deliberate
# and stays -- `catch { }` is what keeps a debug file from failing a user's
# turn. What was WRONG was that the tolerance was total: a dropped write left
# no trace, so "the router never fired" and "the router fired and the log was
# unwritable" produced identical evidence (`silent_channel_is_ambiguous`).
# One marker bit per channel fixes that (`lost_evidence_is_always_marked`),
# and the bit must be able to stay false (`marker_is_not_always_set`) or it
# would distinguish nothing.
$script:RotDebugLost = $false

# --- SESSION IDENTITY AND THE PER-SESSION PROJECT LOG ----------------------
#
# Measured 2026-08-09: the record schema had no session field, so two concurrent
# sessions interleaved into one file and could not be told apart. 185 live route
# records from at least two sessions were indistinguishable.
#
# The scrubber below is the EXECUTABLE TWIN of `sanitiseSession` in
# lean/Proofs/RotSessionLog.lean, and checker/session-log.sh compares the two so
# they cannot drift. It is not cosmetic: this value is interpolated into a
# FILENAME. A session id of "../../.ssh/authorized_keys" would otherwise make
# the router append JSONL outside the project, silently, because the router is
# contractually forbidden from throwing. The Lean proofs no_forward_slash,
# no_backslash and no_dot are what make that impossible -- traversal is removed
# by deleting the characters, never by blacklisting the ".." spelling.
$script:RotSession    = 'unknown'
$script:RotProjectDir = ''
$script:RotLocalLost  = $false
# RotSrc BELONGS IN THIS BLOCK and was missing from it.
#
# MEASURED 2026-08-09 on the shipped 1.0.1 log: 228 gauge records carried
# src:"" -- a value lean/Proofs/RotSessionLog.lean:classify makes
# unrepresentable, so no reader could interpret them. Cause: Invoke-Gauge
# formats $script:RotSrc, and the --Vector / --Route dispatch exits before the
# assignment further down ever runs. PowerShell has no `set -u`, so an unset
# variable does not fail -- it interpolates as the empty string and the record
# is written looking valid.
#
# The POSIX arm never had this defect because `set -u` FORCED the author to
# declare the default up front (see rot-router.sh, same block). The safety one
# arm gets from its shell, the other arm must state explicitly. Cross-arm
# parity is the property; identical source is not.
$script:RotSrc        = 'cli'

function Get-RotSessionName([string] $Raw) {
  if (-not $Raw) { return 'unknown' }
  $kept = ($Raw -replace '[^A-Za-z0-9-]', '')
  if ($kept.Length -gt 64) { $kept = $kept.Substring(0, 64) }
  if (-not $kept) { return 'unknown' }
  return $kept
}

# TERMINATE A PARTIAL LINE BEFORE APPENDING -- `RotLogAtomicity.appendSafe`.
#
# This arm is the larger contributor to the corruption that motivated the fix:
# of 409 unparseable lines in the live log, 248 carried a fractional-second `ts`
# (this writer) against 114 whole-second (the sh arm). `Add-Content` is not
# atomic, and a writer killed between its bytes leaves a line with no newline.
#
# The next append then lands ON those bytes. `naive_loses_the_next_record`
# proves the recovered-record count does not rise at all in that case: the
# interrupted process costs its SUCCESSOR a perfectly good record. Closing the
# line first isolates the fragment and keeps the new record --
# `safe_keeps_the_next_record`, +1.
#
# NO-OP on a healthy file: `identical_on_the_healthy_path` proves the two
# writers are the same function when nothing is pending.
#
# The last byte is read through a share-mode ReadWrite handle so this never
# blocks the other arm, and any exception propagates to the caller's existing
# catch -- which sets the lost-evidence flag. That is deliberate: if the file
# cannot be inspected it very likely cannot be appended either, and a silent
# `catch {}` here would be an alarm that cannot fire.
# MUTUAL EXCLUSION -- `RotLogLock.exclusion_forbids_a_split`, and the sh arm's
# `_rot_lock_acquire` is the SAME algorithm on purpose: one lock protocol, two
# implementations, so the two arms exclude EACH OTHER and not merely themselves.
#
# `Directory.CreateDirectory` is not usable for this -- it succeeds when the
# directory already exists, which is precisely the answer a lock must never
# give. `[System.IO.Directory]::CreateDirectory` returning an existing handle
# would hand the lock to every caller at once. `mkdir` semantics are obtained
# from `IOException` on collision instead, which is the atomic primitive both
# arms share.
#
# Measured 2026-08-11: 265 of 5000 live lines unparseable, torn=0. Nothing was
# truncated -- writer B injected its newline-repair INSIDE writer A's record.
function Get-RotLogLock([string] $Path) {
  if (-not $Path) { return $false }
  $lk = $Path + '.lock'
  # `New-Item -ItemType Directory` creates INTERMEDIATE directories, unlike the
  # sh arm's `mkdir` with no -p. Without this guard the lock would materialise
  # the parent of an unwritable log path, the append would then succeed, and a
  # path the user never created would be silently populated -- and the
  # lost-record marker would stop firing because nothing was lost any more.
  # Measured: checker/debug-channel.sh phase 2 went red on exactly that.
  # Refusing here keeps both arms on the same semantics: no parent, no write,
  # and the loss is MARKED (`a_refusal_is_visible`).
  #
  # `Split-Path -LiteralPath $Path -Parent` CANNOT BE USED: -LiteralPath and
  # -Parent are different parameter sets and PowerShell throws
  # "Parameter set cannot be resolved". The throw escaped this function, killed
  # the whole write, and turned the channel dead while reporting a marker on a
  # successful write. Measured, not reasoned. `[IO.Path]::GetDirectoryName` is
  # a pure string operation with no provider semantics and no parameter sets.
  $parent = [System.IO.Path]::GetDirectoryName($Path)
  if ($parent -and -not (Test-Path -LiteralPath $parent -PathType Container)) { return $false }
  for ($i = 0; $i -lt 50; $i++) {
    try {
      # `New-Item -ItemType Directory` WITHOUT -Force is the mkdir semantic: it
      # throws when the directory already exists. That throw IS the lock. The
      # token is THE DIRECTORY ITSELF, identical to the sh arm's `mkdir "$lk"`,
      # so the two arms contend for the same object and exclude each other.
      #
      # `[System.IO.Directory]::CreateDirectory` must NOT be used here: it
      # succeeds on an existing directory, which would hand the lock to every
      # caller at once -- `admitting_two_holders_restores_the_defect`.
      New-Item -ItemType Directory -Path $lk -ErrorAction Stop | Out-Null
      return $true
    } catch {
      # A holder that died leaves the directory behind and would silence logging
      # forever. Break it only when demonstrably older than any real write --
      # writes take milliseconds, so 30 s is four orders of magnitude of margin.
      try {
        if (Test-Path -LiteralPath $lk) {
          $age = (Get-Date) - (Get-Item -LiteralPath $lk).LastWriteTime
          if ($age.TotalSeconds -gt 30) {
            Remove-Item -LiteralPath $lk -Force -Recurse -ErrorAction Stop
          }
        }
      } catch { }
      Start-Sleep -Milliseconds 20
    }
  }
  return $false
}

function Remove-RotLogLock([string] $Path) {
  if (-not $Path) { return }
  try { Remove-Item -LiteralPath ($Path + '.lock') -Force -Recurse -ErrorAction SilentlyContinue } catch { }
}

function Complete-RotPartialLine([string] $Path) {
  if (-not (Test-Path -LiteralPath $Path)) { return }
  $fs = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open,
                               [System.IO.FileAccess]::Read,
                               [System.IO.FileShare]::ReadWrite)
  try {
    if ($fs.Length -eq 0) { return }
    [void]$fs.Seek(-1, [System.IO.SeekOrigin]::End)
    $last = $fs.ReadByte()
  } finally { $fs.Dispose() }
  if ($last -ne 10) {
    [System.IO.File]::AppendAllText($Path, "`n", (New-Object System.Text.UTF8Encoding($false)))
  }
}

# The SECOND log: one file per session, inside the project being worked on, so a
# session can be inspected beside the code that produced it. Independent of the
# central sink on purpose -- a user who never sets ROTMOE_DEBUG_LOG can still opt
# in with ROTMOE_DEBUG_LOCAL=1, and a user who has a central log can opt OUT with
# ROTMOE_DEBUG_LOCAL=0. Enablement is specified in RotSessionLog.localEnabled.
function Write-RotDebugLocal([string] $Line) {
  $mode = $env:ROTMOE_DEBUG_LOCAL
  if ($mode -eq '0') { return }
  if (-not ($mode -eq '1' -or $env:ROTMOE_DEBUG_LOG)) { return }
  $root = $script:RotProjectDir
  if (-not $root) { return }
  try {
    $d = Join-Path $root '.rot-moe'
    if (-not (Test-Path -LiteralPath $d)) {
      New-Item -ItemType Directory -Path $d -Force -ErrorAction Stop | Out-Null
      # A self-ignoring directory. The router writes into someone else's
      # repository; leaving it to pollute their `git status` would be rude and
      # would eventually get the whole log committed by accident.
      Set-Content -LiteralPath (Join-Path $d '.gitignore') -Value '*' -Encoding utf8 -ErrorAction Stop
    }
    $f = Join-Path $d ('rot-route-' + $script:RotSession + '.jsonl')
    # The lock spans the repair AND the append. Splitting them is the defect:
    # a reader that repairs while a writer is mid-record splits that record.
    if (-not (Get-RotLogLock $f)) { $script:RotLocalLost = $true; return }
    try {
      Complete-RotPartialLine $f
      Add-Content -LiteralPath $f -Value $Line -Encoding utf8 -ErrorAction Stop
    } finally { Remove-RotLogLock $f }
  } catch {
    # Never fails the turn. Recorded so the marker can say so.
    $script:RotLocalLost = $true
  }
}

function Write-RotDebug([string] $Line) {
  # Both sinks are attempted. The local one is NOT behind the central one's
  # early return -- that ordering was the bug in the first draft: with
  # ROTMOE_DEBUG_LOG unset, the per-session log could never be created at all.
  Write-RotDebugLocal $Line
  $p = $env:ROTMOE_DEBUG_LOG
  if (-not $p) { return }
  try {
    # Same discipline on the central sink. On contention we REFUSE and mark it:
    # `refusing_beats_writing_unlocked` (a refusal costs 1 record, an unlocked
    # write destroys 2) and `a_refusal_is_visible` (the loss must be recorded,
    # never silent -- otherwise it is indistinguishable from a router that never
    # fired, the same absence-is-not-evidence defect as scoring by a missing
    # error string).
    if (-not (Get-RotLogLock $p)) { $script:RotDebugLost = $true; return }
    try {
      Complete-RotPartialLine $p
      Add-Content -LiteralPath $p -Value $Line -Encoding utf8 -ErrorAction Stop
    } finally { Remove-RotLogLock $p }
  } catch {
    $script:RotDebugLost = $true
    return
  }
  # Bound the file, discarding the OLDEST -- `rotate_keeps_the_newest`. Keeping
  # the front instead is refuted by `taking_the_front_loses_the_newest`, and the
  # hazard is measured, not theoretical: ~/.claude holds a 1.4 GB and a 1.1 GB
  # log grown by exactly this append pattern with no bound.
  try {
    $capRaw = $env:ROTMOE_DEBUG_LOG_MAX
    $cap = 5000
    if ($capRaw -and ($capRaw -match '^\d+$')) { $cap = [int]$capRaw }
    if ($cap -gt 0) {
      # TRIM TO A LOW-WATER MARK, NOT BACK TO THE CAP -- the POSIX arm's rule,
      # for the same measured reason. Trimming to exactly $cap leaves the file
      # AT the cap, so the next append exceeds it by one and rewrites the whole
      # file again to drop that single line. Past the cap, that is every turn
      # forever, and it is invisible because the bound is always respected.
      #
      # Measured on the POSIX arm (2026-08-14): the sink was found at EXACTLY
      # 5000 lines holding 4 412 009 B -- the fingerprint of per-turn trimming --
      # and rotating it by hand moved bench-router from 521.5 ms to 474.6 ms per
      # turn. This arm reads the file into an ARRAY first, so it pays even more.
      #
      # Keeping 80 % turns a rewrite-every-turn into a rewrite once per ~20 % of
      # the cap. The file stays bounded by $cap, which was the actual promise.
      $lines = @(Get-Content -LiteralPath $p -ErrorAction Stop)
      if ($lines.Count -gt $cap) {
        $keepN = [int]([math]::Floor($cap * 8 / 10))
        if ($keepN -le 0) { $keepN = $cap }
        $keep = $lines[($lines.Count - $keepN)..($lines.Count - 1)]
        Set-Content -LiteralPath $p -Value $keep -Encoding utf8 -ErrorAction Stop
      }
    }
  } catch {
    # Rotation is best effort. A log that could not be trimmed is still a log,
    # and this must never escalate into failing the turn.
  }
}

# NO SECOND BAND TABLE. $Bands is declared once above, for Get-BandFlag, and
# this function reads THAT -- the first draft of this change transcribed the ten
# pairs again here, which is a second place for the same constants to drift and
# exactly what the POSIX arm refuses to do in its gauge.
# -Voice is the sh arm's optional 7th gauge argument: it turns on the per-lens
# LENSDATA lines the voice block consumes (hooks/rot-voice.dtd is where those
# numbers get their names). It is passed ONLY by hook mode's voice path: the
# CLI and every corpus runner call this without it, so -Vector output stays
# byte-identical to every earlier release and the cross-diff corpus keeps
# comparing the same string it always did.
function Invoke-Gauge([string] $Vec, [int] $Br, [double] $M, [double] $C, [double] $T, [string] $Lane = 'FORGE', [switch] $Voice) {
  $acts = @($Vec -split ',' | ForEach-Object { [double]$_ })
  $K = $acts.Count
  $mean = 0.0; foreach ($a in $acts) { $mean += $a }
  $mean = $mean / $K

  $sum = 0.0
  $active = New-Object System.Collections.Generic.List[string]
  $terms  = New-Object System.Collections.Generic.List[string]
  # Per-lens factors for the voice path's LENSDATA lines. Never populated
  # without -Voice, so the CLI path pays nothing and emits nothing new.
  $sArr = New-Object System.Collections.Generic.List[double]
  $hArr = New-Object System.Collections.Generic.List[double]
  $tArr = New-Object System.Collections.Generic.List[double]
  $dArr = New-Object System.Collections.Generic.List[double]
  for ($i = 0; $i -lt $K; $i++) {
    $a = $acts[$i]
    if ($a -gt 0) { $active.Add($Names[$i]) }
    $d = [Math]::Abs($a - $mean)
    $s = 1.0 / (1.0 + [Math]::Exp(-4.0 * ($d - 0.5)))
    $H = if ($Br -gt 0) { $a / [double]$Br } else { 0.0 }
    if ($H -gt 1.0) { $H = 1.0 }
    $term = $Lambdas[$i] * $s * (1.0 + $H) * $Mus[$i] * $M * $C * $T
    $sum += $term
    if ($Voice) { $sArr.Add($s); $hArr.Add($H); $tArr.Add($term); $dArr.Add($d) }
    if ($env:ROTMOE_DEBUG_LOG) {
      $terms.Add(('{{"lens":"{0}","lambda":{1},"mu":{2},"a":{3},"delta":{4},"sigma":{5},"H":{6},"term":{7}}}' -f `
        $Names[$i], (Format-Num $Lambdas[$i] 3), (Format-Num $Mus[$i] 3), (Format-Num $a 3), `
        (Format-Num $d 4), (Format-Num $s 4), (Format-Num $H 4), (Format-Num $term 5)))
    }
  }
  if ($env:ROTMOE_DEBUG_LOG) {
    Write-RotDebug ('{{"kind":"gauge","ts":"{0}","session":"{11}","src":"{12}","K":{1},"mean":{2},"breadth":{3},"M":{4},"C":{5},"T":{6},"sum":{7},"Rs":{8},"active":"{9}","lenses":[{10}]}}' -f `
      (Get-Date -Format 'o'), $K, (Format-Num $mean 4), $Br, (Format-Num $M 3), (Format-Num $C 3), (Format-Num $T 3), `
      (Format-Num $sum 5), (Format-Num ($sum / $K) 5), ($(if ($active.Count) { $active -join ',' } else { 'none' })), ($terms -join ','), $script:RotSession, $script:RotSrc)
  }
  $R = $sum / $K
  # Was `-lt 0.9 / -gt 1.8` for EVERY lane -- the FORGE range used as if it were
  # universal, so a CREATIVE turn at 1.4 read IN RANGE while its own band starts
  # at 1.5 and the correct signal was ADD ENTROPY. An unknown lane falls back to
  # FORGE, matching the POSIX arm exactly rather than guessing separately.
  $bb = if ($Bands.ContainsKey($Lane)) { $Bands[$Lane] } else { $Bands['FORGE'] }
  $lo = $bb[0] / 100.0; $hi = $bb[1] / 100.0
  $bandTxt = '(' + $lo.ToString('0.##', [Globalization.CultureInfo]::InvariantCulture) + '-' + $hi.ToString('0.##', [Globalization.CultureInfo]::InvariantCulture) + ')'
  $band = if ($R -lt $lo) { "BELOW RANGE $bandTxt" } elseif ($R -gt $hi) { "ABOVE RANGE $bandTxt" } else { "IN RANGE $bandTxt" }
  $lenses = if ($active.Count) { $active -join ',' } else { 'none' }
  $human = ('R/s+ = {0} [{1}] mean={2} breadth={3} K={4} lenses={5}' -f `
          (Format-Num $R 2), $band, (Format-Num $mean 3), $Br, $K, $lenses)
  if (-not $Voice) { return $human }
  # The voice path only: one machine-readable line per lens, AFTER the human
  # line so every existing consumer keeps matching what it always matched.
  # Fields are the same factors the debug record carries -- the stanza is
  # BLOCK 10 contributions redirected to the context, and it must be
  # recomputable from these lines by hand. Precisions match the sh awk:
  # lambda 2, sigma 4, H 4, term 5, share 0 (share = 100*term/sum), and the
  # 6.0.2 pair APPENDED so the first six positions never move: delta 4,
  # mu 3 -- the debug record's own precisions, one arithmetic for both
  # streams.
  $out = @($human)
  for ($i = 0; $i -lt $K; $i++) {
    $shr = if ($sum -gt 0) { 100.0 * $tArr[$i] / $sum } else { 0.0 }
    $out += ('LENSDATA|{0}|{1}|{2}|{3}|{4}|{5}|{6}|{7}' -f `
      $Names[$i], (Format-Num $Lambdas[$i] 2), (Format-Num $sArr[$i] 4), `
      (Format-Num $hArr[$i] 4), (Format-Num $tArr[$i] 5), (Format-Num $shr 0), `
      (Format-Num $dArr[$i] 4), (Format-Num $Mus[$i] 3))
  }
  return $out
}

# THE DECLARATION IS READ ON EVERY PATH, not only in hook mode -- the exact
# counterpart of the block in rot-router.sh. Both CLI dispatches below exit
# immediately, so without this a harness that exported ROTMOE_DEBUG_SRC=test
# and called --Vector had its gauge written as live CLI traffic. Hook mode
# re-resolves after parsing the payload (infer, THEN declare), so an explicit
# value still wins there. Proved: src_declaration_wins_on_every_path.
switch ($env:ROTMOE_DEBUG_SRC) {
  'test'  { $script:RotSrc = 'test' }
  'cli'   { $script:RotSrc = 'cli' }
  'hook'  { $script:RotSrc = 'hook' }
}

# W8: -Route no longer exits here. When ROTMOE_DEBUG_LOG points at a file it
# FALLS THROUGH into the hook body so the same straight-line NSIL + record
# code runs (one body, two callers -- the sh arm factored the same way) and
# the CLI writes the same gauge+route pair a hook turn writes. Three
# contracts, mirrored from the sh arm: stdout stays the PRE-NSIL lane,
# byte-identical; logging stays OPT-IN here ('' or '0' writes nothing, and
# takes the old direct-exit path below); CLI text IS a human-typed query, so
# the density verdicts apply. The cli-mode guards downstream skip the
# payload read, the rot.env load, the W7 default, and every marker/voice
# emission -- the record is the only new observable.
$CliRoute = $null
if ($Route) {
  if ($env:ROTMOE_DEBUG_LOG -and $env:ROTMOE_DEBUG_LOG -ne '0') {
    $CliRoute = $Route
  } else {
    $r = Split-Routed (Invoke-Route $Route); Write-Output $r[0]; exit 0
  }
}
if ($Vector) {
  if ($Profile) { Select-Profile $Profile }
  $laneArg = if ($Lane) { $Lane } else { 'FORGE' }
  Write-Output (Invoke-Gauge $Vector $Breadth $M $C $T $laneArg); exit 0
}

# --- HOOK MODE, and the defect it exists to fix ------------------------------
# This script previously ENDED at Write-Error. ARM_ROUTER registers it as a hook
# command with no arguments, so every real invocation reached that line and
# exited 2 -- the hook fired on every turn and did nothing but complain.
#
# Every other instrument was green while that was true: the build, the kernel
# re-check, a 49-row byte-identical cross-diff, a byte-identical installer round
# trip, 10/10 mutants killed. None of them invokes the hook the way Claude Code
# invokes it. A live session found it in one run.
#
# Claude Code sends the invoking event as JSON on stdin -- measured in the
# shipped hook at rot-lean-inject.ps1:119-128. IsInputRedirected is the guard
# that keeps a manual run from blocking forever on a terminal; reading stdin
# unconditionally would hang.
$payload = ''
if (-not $CliRoute -and [Console]::IsInputRedirected) {
  try { $payload = [Console]::In.ReadToEnd() } catch { $payload = '' }
}

if (-not $CliRoute -and [string]::IsNullOrWhiteSpace($payload)) {
  Write-Error 'rot-router.ps1: hook mode expects a JSON payload on stdin. Try -Route "some text".'
  exit 2
}

$prompt = ''
try {
  $j = $payload | ConvertFrom-Json
  # MEASURED DEFECT, 2026-08-03 -- see the same note in rot-router.sh. Reading
  # only the tool NAME made every PreToolUse firing route to CONVERGENT, because
  # "Bash", "Edit", "Read" and "Grep" match no stem. The autonomous half of the
  # router was inert and looked healthy. Route on what the tool is DOING.
  if ($j.prompt)         { $prompt = [string]$j.prompt }
  elseif ($j.tool_name)  {
    $ti = $j.tool_input
    $act = @()
    if ($ti) {
      foreach ($f in 'command','file_path','path','pattern','description') {
        $v = $ti.$f
        if ($v -is [string] -and $v) { $act += $v }
      }
    }
    if ($act.Count -gt 0) { $prompt = ([string]$j.tool_name) + ' ' + ($act -join ' ') }
    else                  { $prompt = [string]$j.tool_name }
  }
} catch {
  # A payload that does not parse is not a reason to fail the user's turn. Route
  # the raw text: the routing decision degrades, the session does not break.
  $prompt = $payload
}

# WHICH SESSION PRODUCED THIS RECORD. `$j` is absent when the payload did not
# parse, so both reads are guarded; an unidentifiable session degrades to
# 'unknown' rather than losing the record, which is the same honesty rule the
# event field follows.
try {
  if ($j -and $j.session_id) { $script:RotSession = Get-RotSessionName ([string]$j.session_id) }
} catch { }
try {
  if ($j -and $j.cwd) { $script:RotProjectDir = [string]$j.cwd }
  else                { $script:RotProjectDir = (Get-Location).Path }
} catch { $script:RotProjectDir = '' }

# ORGAN 7 -- the environment layer. Parsed never sourced, declared-only,
# unset-only; the sh arm is the reference. A missing library is a no-op.
if (-not $CliRoute) {
  try {
    $rotEnvLib = Join-Path $PSScriptRoot 'rot-env.ps1'
    if (Test-Path -LiteralPath $rotEnvLib) {
      . $rotEnvLib
      Invoke-RotEnvLoad $script:RotProjectDir
    }
  } catch { }
}

# THE DEBUG CHANNEL DEFAULTS ON IN HOOK MODE -- W7; the sh arm carries the
# full reasoning. PowerShell cannot express a set-but-empty environment
# variable ($env:X = '' REMOVES it), so '0' is the canonical off switch on
# both arms; the DTD's ENV.5 says so. Bounded twice: each file by the
# existing ROTMOE_DEBUG_LOG_MAX trim, the file count by a once-per-session
# janitor (only when this session's file does not exist yet). An unwritable
# state dir degrades to OFF, never to a failed turn. CLI stays opt-in.
if (-not $CliRoute -and -not $env:ROTMOE_DEBUG_LOG) {
  $dlDir = if ($env:ROTMOE_STATE_DIR) { $env:ROTMOE_STATE_DIR }
           elseif ($env:XDG_STATE_HOME) { Join-Path $env:XDG_STATE_HOME 'rot-moe' }
           else { Join-Path $HOME '.local/state/rot-moe' }
  try {
    $dlPath = Join-Path $dlDir ("rot-debug." + $script:RotSession + ".jsonl")
    if (-not (Test-Path -LiteralPath $dlPath)) {
      New-Item -ItemType Directory -Force -Path $dlDir -ErrorAction Stop | Out-Null
      Get-ChildItem -LiteralPath $dlDir -Filter 'rot-debug.*.jsonl' -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTimeUtc -lt (Get-Date).ToUniversalTime().AddDays(-7) } |
        Remove-Item -Force -ErrorAction SilentlyContinue
    }
    $env:ROTMOE_DEBUG_LOG = $dlPath
  } catch { }
}
if ($env:ROTMOE_DEBUG_LOG -eq '0') { $env:ROTMOE_DEBUG_LOG = $null }

# THE PAYLOAD SURVEY (7.0.0) -- the sh arm's instrument, reason stated there
# in full: KEYS ONLY (top-level, tool_input, tool_response), never a value,
# opt-in via ROTMOE_DEBUG_PAYLOAD=1, its own per-session sink, degrades to
# silence. The ship-what-you-measure prerequisite for V2's result clauses.
if (-not $CliRoute -and $env:ROTMOE_DEBUG_PAYLOAD -eq '1') {
  try {
    $psDir = if ($env:ROTMOE_STATE_DIR) { $env:ROTMOE_STATE_DIR }
             elseif ($env:XDG_STATE_HOME) { Join-Path $env:XDG_STATE_HOME 'rot-moe' }
             else { Join-Path $HOME '.local/state/rot-moe' }
    New-Item -ItemType Directory -Force -Path $psDir -ErrorAction Stop | Out-Null
    $pj = $payload | ConvertFrom-Json -ErrorAction Stop
    $kf = { param($o) if ($null -ne $o -and $o -is [pscustomobject]) { @($o.PSObject.Properties.Name | Sort-Object) } else { @() } }
    $trType = if ($null -eq $pj.tool_response) { 'absent' }
              elseif ($pj.tool_response -is [System.Array]) { 'array' }
              elseif ($pj.tool_response -is [pscustomobject]) { 'object' }
              else { 'scalar' }
    $line = (@{ kind = 'payload'
                event = [string]($pj.hook_event_name); tool = [string]($pj.tool_name)
                keys = (& $kf $pj); toolInputKeys = (& $kf $pj.tool_input)
                toolResponseKeys = (& $kf $pj.tool_response); toolResponseType = $trType } |
             ConvertTo-Json -Compress -Depth 4)
    [System.IO.File]::AppendAllText((Join-Path $psDir ("rot-payload." + $script:RotSession + ".jsonl")), $line + "`n")
  } catch { }
}

# PROVENANCE -- `classify` in lean/Proofs/RotSessionLog.lean.
#
# Measured 2026-08-09: seven checkers (bench-router, debug-channel, cross-diff,
# log-replay, release-install, release-longsession, release-session) feed the
# router synthetic payloads and write into the same log. 738 of 955 sh records
# were theirs, and nothing in the schema said so, so every "live router health"
# figure computed from this log silently mixed real traffic with replayed
# traffic. The field below is what makes live records countable again.
#
# An unrecognised ROTMOE_DEBUG_SRC is IGNORED, never believed:
# unknown_declaration_falls_back proves a typo demotes to inference rather than
# inventing a fourth class.
$script:RotSrc = 'cli'
try {
  $hasEvent = [bool]($j -and $j.hook_event_name)
  switch ($env:ROTMOE_DEBUG_SRC) {
    'test'  { $script:RotSrc = 'test' }
    'cli'   { $script:RotSrc = 'cli' }
    'hook'  { $script:RotSrc = 'hook' }
    default { $script:RotSrc = $(if ($hasEvent) { 'hook' } else { 'cli' }) }
  }
} catch { $script:RotSrc = 'cli' }

# WHICH EVENT FIRED -- extracted HERE, before TIER 2, because the density
# verdicts read it ($nsilQuery below). The voice decision and the debug
# record further down read this same value. Same parse, same charset guard.
$evName = '-'
if ($j -and $j.hook_event_name) {
  $cand = [string]$j.hook_event_name
  if ($cand -match '^[A-Za-z]+$') { $evName = $cand }
}
# DENSITY IS A PROPERTY OF A QUERY, NOT OF A COMMAND LINE -- see the long
# note at the same point in rot-router.sh (W3): tool-event text is the tool
# name plus command/path/pattern, routinely nine-plus words, and the floor
# read it as a dense query. The density verdicts (BOOST, ELEVATE) fire only
# on the events where a human typed the words; every stem-based verdict
# (CONFIRM, FUSE, OVERRIDE) is untouched on tool events.
$nsilQuery = (($null -ne $CliRoute) -or (@('UserPromptSubmit','UserPromptExpansion') -ccontains $evName))

# README.md:77 promises this line carries a named lane AND A GAUGE READING. See
# the long note at the same point in rot-router.sh: the vector is the ROUTING
# DECISION expressed one-hot -- the lead lens of the fired lane at 1, the rest
# at 0 -- which is measured, not invented. A CONVERGENT turn fires no lens, so
# its vector is all zeros with breadth 0, and the gauge is defined there too.
# M, C and T are the neutral element 1.0 because one stateless hook call cannot
# measure memory residue, confidence or recency; that is stated, not hidden.
# The index comes from $Names so a roster change moves both arms together.
if ($CliRoute) { $prompt = [string]$CliRoute }
$__routed = Invoke-Route $prompt
$__rparts = Split-Routed $__routed
$lane  = $__rparts[0]
$stem  = $__rparts[1]
$lens  = ($lane -split ' ')[1]
# W8: the CLI prints the PRE-NSIL lane -- saved before OVERRIDE can move it.
$cliOut = $lane

# TIER 2 (NSIL). BREADTH IS COUNTED, NOT ASSIGNED -- see the note in the POSIX
# arm. The old line set `$br = 1` beside the bit it had just written, making the
# field an assertion about the vector instead of a measurement of it.
$nsilAct   = @(Get-NsilActiveLenses $prompt)
$nsilWords = @($prompt -split '\s+' | Where-Object { $_ -ne '' }).Count
# NOVA ADJUDICATES EVERY TURN: the default verdict is CONFIRM ("the TIER 1 lead
# stands"), never an empty field. An empty field would say the layer never ran.
$nsilDecision = 'CONFIRM'
if ($nsilAct.Count -ge 2) {
  $nsilDecision = 'FUSE'
  # NSIL is the NOVA Sovereign Intent Layer: a fusion is something Nova DID, so
  # her bit is 1 by construction. Idempotent -- if STRATEGIC fired, the set is
  # unchanged and breadth 2 stays reachable.
  if ($nsilAct -notcontains 'Nova') {
    $withNova = @()
    foreach ($n in $Names) { if ($n -eq 'Nova' -or $nsilAct -contains $n) { $withNova += $n } }
    $nsilAct = $withNova
  }

  # OVERRIDE -- "the words mislead", on section 3's own worked example:
  # `fix our relationship` routes EMPATHIC, not CLINICAL.
  #
  # Implemented as a REFINEMENT OF FUSE, because that is where the evidence
  # exists: such a prompt fires a technical stem AND a human one, so it is
  # already a two-lane turn, and section 3 says the human reading WINS rather
  # than blending. A CLINICAL x EMPATHIC hybrid would be a router splitting the
  # difference on a prompt whose meaning is not divided. Deliberately narrow --
  # only EMPATHIC fused with a technical lane; every other pair stays a FUSE.
  if ($nsilAct -contains 'Violet' -and
      (($nsilAct -contains 'AntiVenom') -or ($nsilAct -contains 'Venom') -or ($nsilAct -contains 'Claude'))) {
    $nsilDecision = 'OVERRIDE'
    $lane = 'EMPATHIC'
    $lens = 'Violet'
    # The lead CHANGES, so the weights follow it. An OVERRIDE that left the
    # technical profile mounted would be the same defect fixed one layer up.
    Select-Profile 'EMPATHIC'
  }
} elseif ($nsilAct.Count -eq 1 -and $nsilQuery -and $nsilWords -ge $Names.Count) {
  # BOOST -- "right mode, one lens underweighted; a single λ rises surgically".
  # The mode is confirmed (exactly one lane fired) and the prompt is dense by
  # the same derived floor ELEVATE uses.
  #
  # RECORDED HERE, APPLIED AFTER THE PROFILE IS MOUNTED -- never before it. The
  # POSIX arm's first draft modified the weights at this point and Select-Profile
  # later reloaded them, producing a route line that announced `[NSIL BOOST
  # Soleil]` beside a record carrying Soleil's unboosted 2.5. The marker is
  # evidence; a marker for an action that did not happen is worse than no BOOST.
  $nsilDecision = 'BOOST'
  $script:NsilBoost = $lens
  $nsilAct = @($lens)
} elseif ($nsilAct.Count -eq 0 -and $nsilQuery -and $nsilWords -ge $Names.Count) {
  $nsilDecision = 'ELEVATE'
  $nsilAct = @($Names)
} else {
  $nsilAct = @($lens)
}

# SYMBIOGENESIS, EVALUATED -- only for exactly two lenses. rot-lean.md section 3
# defines the hybrid over TWO leads; folding pairwise would add +0.2 per fold
# (+0.4 at three, +0.6 at four), an escalation no theorem sanctions. Staying
# silent above two is the honest answer until the Socio decides the n-way rule.
$nsilHyb = ''
# The pair and the merged constants are KEPT (not only serialized) because the
# voice block below states them in the fused lenses' own stanzas -- one
# computation, two consumers, mirroring the sh arm's HYB_* survival.
$hybA = ''; $hybB = ''; $hybObj = $null
if ($nsilDecision -eq 'FUSE' -and $nsilAct.Count -eq 2) {
  $h = Get-NsilHybrid $nsilAct[0] $nsilAct[1]
  if ($null -ne $h) {
    $hybA = $nsilAct[0]; $hybB = $nsilAct[1]; $hybObj = $h
    $nsilHyb = ',"hybrid":{{"pair":"{0}x{1}","lam":{2},"mu":{3},"h":{4}}}' -f `
      $nsilAct[0], $nsilAct[1], (Format-Hund $h.lam), (Format-Hund $h.mu), (Format-Hund $h.h)
  }
}

$acts  = @()
$br    = 0
foreach ($n in $Names) {
  if ($nsilAct -contains $n) { $acts += '1'; $br = $br + 1 } else { $acts += '0' }
}
# TIER 3 -- the complexity gate, DERIVED from TIER 2 rather than from invented
# word-count cutoffs. rot-lean.md section 3 says it regulates only how much
# thinking is spent, never whether the mechanism runs, so it is purely additive:
# it cannot move the marker, the lane, the vector or R/s+.
#   breadth 0 -> TRIVIAL   nothing engaged
#   breadth 1 -> STANDARD  one lens carries the turn
#   breadth 2+ -> DEEP     several lenses contribute a point of view
$nsilDepth = if ($br -ge 2) { 'DEEP' } elseif ($br -eq 1) { 'STANDARD' } else { 'TRIVIAL' }

# THE LANE NOW CHOOSES THE WEIGHTS -- the one line that makes the other nine
# section 4 profiles real, mirroring the POSIX arm exactly.
Select-Profile (($lane -split ' ')[0])

# BOOST IS APPLIED HERE, AFTER THE PROFILE IS MOUNTED. +0.3 is section 3's own
# stated typical, quoted rather than tuned, and it rises from the ACTIVE
# profile's value: a boosted STEALTH Soleil goes 2.5 -> 2.8.
if ($script:NsilBoost) {
  $i = [Array]::IndexOf($Names, $script:NsilBoost)
  if ($i -ge 0) {
    $bl = @($Lambdas)
    # Integer hundredths, mirroring the POSIX arm exactly. PowerShell HAS
    # decimals and must not use them here -- the arms have to agree on every
    # emitted digit, so both do the same integer arithmetic.
    #
    # THE CASTS ARE LOAD-BEARING. `{1:d2}` is an INTEGER format specifier;
    # [math]::Floor and % return [double], and handing a double to :d2 throws
    # "Error formatting a string: Format specifier was invalid" at runtime --
    # measured, and it took the whole ps1 arm down while the POSIX arm was fine.
    # A parity check is what caught it, which is the argument for having one.
    $h = [int][math]::Round($bl[$i] * 100) + 30
    $bl[$i] = [double]("{0}.{1:d2}" -f [int][math]::Floor($h / 100), [int]($h % 100))
    $script:Lambdas = $bl
  }
}

# WHICH EVENT FIRED -- `$evName` is extracted at the TOP of the turn now,
# before TIER 2, because the density verdicts read it ($nsilQuery). The voice
# decision below and the debug record read the same value; the extraction
# moved, its parse and charset guard did not.

# THE VOICE DECISION. By Socio directive the lenses speak by default
# (ROTMOE_VOICE=0 silences them), and they speak MID-WORK too: plain stdout
# reaches the model on exactly three events, and on the tool-loop events the
# legal channel is the JSON envelope's additionalContext -- the shape
# prover-remind has always used there, event echoed back or the payload is
# discarded. The sh arm is the reference, decision for decision.
# Schema gate for the JSON channel: only the measured accepting set
# (lean/Proofs/RotInject.lean) may carry additionalContext. The sh arm's
# CTX_EVENTS is the reference; PostToolUseFailure is deliberately absent.
# PreToolUse ONLY -- Pre and Post build the same routing text from the same
# tool_input fields, so the pair was byte-identical on every call (W2,
# measured over 30 live turns). The voice speaks before the act; the debug
# records still write on every event. See the sh arm's comment in full.
$ctxEvents = @('PreToolUse')
$voice = $false
$voiceJson = $false
if ($env:ROTMOE_VOICE -ne '0') {
  if (@('UserPromptSubmit','UserPromptExpansion','SessionStart') -ccontains $evName) { $voice = $true }
  elseif ($ctxEvents -ccontains $evName) { $voice = $true; $voiceJson = $true }
}

# The voice path passes -Voice, so the gauge also returns one LENSDATA line
# per lens AFTER the human R/s+ line; every other path calls it exactly as
# before. Full output is captured either way, and R/s+ is still parsed from
# the human line, which stays first.
if ($voice) { $g = Invoke-Gauge ($acts -join ',') $br 1 1 1 ($lane -split ' ')[0] -Voice }
else        { $g = Invoke-Gauge ($acts -join ',') $br 1 1 1 ($lane -split ' ')[0] }
$gLines = @($g)
$gHead  = [string]$gLines[0]
$rs = if ($gHead -match '^R/s\+ = ([0-9.]+)') { $Matches[1] } else { 'n/a' }

# NOVA'S BAND FLAG and SOLEIL'S MONITOR, computed once the score exists --
# UNCONDITIONALLY now (6.0.2): they used to live inside the debug-log branch,
# but the voice block below states them in the stanzas, and a clause that
# only exists while logging is on would make the voices an artifact of the
# log switch. Pure lookups, no cost moved. The band verdict text is taken
# from between the human line's own brackets so stanza and instrument can
# never disagree.
$bandFlag = Get-BandFlag (($lane -split ' ')[0]) $rs
$tokEmerg = Get-TokenEmergency
$shown    = if ($tokEmerg) { $ChromaShownEmergency } else { $ChromaShownNormal }
$gBand    = if ($gHead -match '\[([^\]]+)\]') { $Matches[1] } else { '' }

# One record per ROUTED TURN, distinct from the per-lens gauge record above.
# `chars` rather than the prompt itself: the log must be safe to paste into an
# issue, and the routing decision is what is under test, not the user's text.
if ($env:ROTMOE_DEBUG_LOG) {
  $ms = [int]((Get-Date) - $__rotStart).TotalMilliseconds
  # WHICH EVENT PRODUCED THIS RECORD -- added 2026-08-08, mirroring the POSIX
  # arm. The reasoning is written out in full at the same point in
  # rot-router.sh: with eleven registrations, a log that does not name the event
  # makes the wiring unfalsifiable from its own evidence.
  #
  # The charset guard is the same and is load-bearing for the same reason: this
  # value goes into a JSON record, and a quote or brace arriving in that field
  # would emit a malformed line that breaks every downstream reader. Anything
  # not plain letters is recorded as "-", which honestly says "a record was
  # written and the event was not identifiable".
  # `$evName` is extracted ABOVE the gauge call now (the voice block needs
  # the event on every path, logging on or off); the guard and the semantics
  # are unchanged and the comment above still describes them.
  # {12} is $nsilHyb, already a finished string with LITERAL braces -- `-f`
  # substitutes argument values verbatim and only parses braces in the FORMAT
  # string, so it must not be double-escaped a second time here.
  # `band` is Nova's self-correction flag against section 5's per-lane range;
  # `timelines` is Chroma's 12 spawned with 5 shown, or 3 when Soleil's monitor
  # has an actual budget reading below 20%. Both RECORDED, never acted on.
  Write-RotDebug ('{{"kind":"route","ts":"{0}","event":"{7}","session":"{8}","src":"{9}","lane":"{1}","lens":"{2}","Rs":"{3}","chars":{4},"stem":"{5}","nsil":"{10}","breadth":{11},"depth":"{13}","band":"{14}","timelines":{{"spawned":{15},"shown":{16}}},"tokenEmergency":{17}{12},"arm":"ps1","ms":{6}}}' -f `
    (Get-Date -Format 'o'), (($lane -split ' ')[0]), $lens, $rs, $prompt.Length, $stem, $ms, $evName, $script:RotSession, $script:RotSrc, $nsilDecision, $br, $nsilHyb, $nsilDepth, `
    $bandFlag, $ChromaSpawned, $shown, $(if ($tokEmerg) { 'true' } else { 'false' }))
}

# The marker rides the router's own stdout, not a sidecar file: if the log path
# is unwritable, a file beside it very likely is too, and a marker that fails
# the same way as the thing it reports is not a marker. Byte-identical to the
# sh arm's line so cross-diff keeps comparing the same string.
# BOTH SINKS REPORT. RotLocalLost was set and never read -- an alarm that cannot
# fire. The central marker stays byte-identical to the sh arm's so cross-diff
# keeps comparing the same string; the project marker is an additive suffix,
# emitted in the same order and wording by both arms.
$mark = ""
if ($script:RotDebugLost) { $mark = $mark + " | debug-log UNWRITABLE (record lost)" }
if ($script:RotLocalLost) { $mark = $mark + " | project-log UNWRITABLE (record lost)" }
# The TIER 2 tag rides INSIDE the pipe-free lane field, so every existing
# assertion on this line still matches (prefix, lane token and the ` | R/s+ `
# boundary are untouched) while the fused lenses are NAMED rather than counted.
# W8: cli mode ends here -- the record is written, the marker and the voice
# belong to hook turns alone. Output is the saved pre-NSIL lane, byte-identical
# to the old direct-exit path.
if ($CliRoute) { Write-Output $cliOut; exit 0 }

$nsilTag = ''
if ($nsilDecision -ne '' -and $nsilDecision -ne 'CONFIRM') { $nsilTag = ' [NSIL ' + $nsilDecision + ' ' + ($nsilAct -join '+') + ']' }
# --- THE SENTINEL CLAUSE (7.0.0, V2: the working share) ----------------------
# The sh arm carries the full reasoning and the Socio's order verbatim. Every
# predicate reads a MEASURED field of this CLI's payload (survey, 2026-08-19):
# interrupted first, then the Bash blank with the harness's own
# noOutputExpected sanction, then the Write zero-byte with the input-side
# guard. One clause at most; silence is the healthy state; Edit responses
# are unmeasured and unread; element tags are held against the DTD by
# checker/voice-contract.sh.
$sent = ''
if ($evName -eq 'PostToolUse' -and $env:ROTMOE_VOICE -ne '0') {
  try {
    $sj = $payload | ConvertFrom-Json -ErrorAction Stop
    $tr = $sj.tool_response
    if ($null -ne $tr -and $tr -is [pscustomobject]) {
      $ti = $sj.tool_input
      if ($tr.interrupted -eq $true) {
        $sent = '<rot:claude>🧭 Claude: this command was INTERRUPTED -- whatever follows the cut never ran; measure again before trusting the result.</rot:claude>'
      } elseif ($sj.tool_name -eq 'Bash' -and $tr.stdout -eq '' -and $tr.stderr -eq '' -and $tr.noOutputExpected -ne $true) {
        $sent = '<rot:antivenom>⚪ AntiVenom: result BLANK -- zero bytes where output was expected; treat absence as a finding, not a pass.</rot:antivenom>'
      } elseif ($sj.tool_name -eq 'Write' -and $tr.content -eq '' -and $null -ne $ti -and ($ti.content -is [string]) -and $ti.content -ne '') {
        $sent = '<rot:antivenom>⚪ AntiVenom: wrote ZERO BYTES where content was given -- read the file before building on it.</rot:antivenom>'
      }
    }
  } catch { $sent = '' }
  if ($sent) { $voiceJson = $true }
}

# TWO CHANNELS, ONE CONTENT -- the sh arm's rule, decision for decision. On
# the JSON path each piece is scrubbed of quote and backslash BEFORE the
# literal \n separators join them, so the scrub can never eat a separator.
$mLine = "RoT MoE :: TIER 1 -> " + $lane + $nsilTag + " | R/s+ " + $rs + $mark
$vAcc = ''
if ($voiceJson) {
  $vAcc = ($mLine -replace '["\\]', '')
  if ($sent) { $vAcc += ('\n' + ($sent -replace '["\\]', '')) }
} else {
  Write-Output $mLine
}

# --- THE VOICE BLOCK ---------------------------------------------------------
# One stanza per ACTIVE lens, in roster order, each inside the element
# hooks/rot-voice.dtd declares for it. The measured fields come from the
# gauge's LENSDATA lines (the same factors the debug record carries); the
# charter and the bound come from the DTD, so no lens fact exists twice.
# The marker line above is UNTOUCHED -- every checker that matches it keeps
# matching -- and the stanzas are ADDITIVE lines after it, on the three
# context-bearing events only (see the voice decision above).
#
# A CONVERGENT turn activates no roster lens (its "lead" is the convener
# model), so the loop naturally emits nothing there: the nine stand down
# and the marker already names who convenes. A missing or unreadable DTD
# degrades to silence rather than failing the turn -- the marker is the
# contract, the voices are the capability.
# THE SUMMONS. A UserPromptSubmit that fused or elevated is a turn where
# several lenses were summoned -- record who, so the voice gate (ORGAN 6,
# hooks/rot-voice-gate.ps1 / .sh) can hold the door on Stop until each has
# spoken. Same single-writer, single-consumer, one-turn lifetime as the sh
# arm; ROTMOE_GATE=0 opts out; the write degrades silently.
$gateRows = @()
$gateFile = ''
if ($evName -eq 'UserPromptSubmit') {
  $gateDir = $env:ROTMOE_STATE_DIR
  if ([string]::IsNullOrEmpty($gateDir)) {
    $xdg = $env:XDG_STATE_HOME
    if ([string]::IsNullOrEmpty($xdg)) { $xdg = Join-Path $HOME '.local/state' }
    $gateDir = Join-Path $xdg 'rot-moe'
  }
  if ($env:ROTMOE_GATE -ne '0') {
    $gateFile = Join-Path $gateDir ("voice-summons." + $script:RotSession)
  } else {
    # GATE=0 STILL CLEARS (U3) -- the .sh arm's rule, reason stated there in
    # full: opting out of the gate must not let a summons from an armed turn
    # outlive its turn and cage the first Stop after re-arming.
    try { Remove-Item -LiteralPath (Join-Path $gateDir ("voice-summons." + $script:RotSession)) -Force -ErrorAction SilentlyContinue } catch { }
  }
}
if ($voice -and $br -gt 0) {
  # Resolve the contract: the installed plugin root first, then this script's
  # own directory -- the sh arm's `$CLAUDE_PLUGIN_ROOT/hooks` then `${0%/*}`
  # order. The READ is the probe (sh tests `-r`, not existence), so a file
  # that exists but cannot be read demotes to the fallback the same way a
  # missing one does; a second failure is the silence promised above.
  $vDtd = Join-Path $PSScriptRoot 'rot-voice.dtd'
  if ($env:CLAUDE_PLUGIN_ROOT) { $vDtd = Join-Path (Join-Path $env:CLAUDE_PLUGIN_ROOT 'hooks') 'rot-voice.dtd' }
  $vLines = $null
  try { $vLines = @(Get-Content -LiteralPath $vDtd -Encoding utf8 -ErrorAction Stop) } catch { $vLines = $null }
  if ($null -eq $vLines) {
    $vDtd = Join-Path $PSScriptRoot 'rot-voice.dtd'
    try { $vLines = @(Get-Content -LiteralPath $vDtd -Encoding utf8 -ErrorAction Stop) } catch { $vLines = $null }
  }
  if ($null -ne $vLines) {
    # LENS.n entities are declared in roster order, which
    # checker/voice-contract.sh is positioned to keep true. The value is the
    # text between the FIRST and LAST double quote of the line -- the sh
    # arm's `${_vl#*\"}` then `${_vrow%\"*}`, each a no-op with no quote --
    # and the fields split on `|` as name|element|sigil|charter|tools|bound.
    $vRows = @()
    foreach ($vl in $vLines) {
      if ($vl -like '*<!ENTITY LENS.*') {
        $vr = [string]$vl
        $q = $vr.IndexOf('"')
        if ($q -ge 0) { $vr = $vr.Substring($q + 1) }
        $q = $vr.LastIndexOf('"')
        if ($q -ge 0) { $vr = $vr.Substring(0, $q) }
        $vRows += $vr
      }
    }
    # THE FRAME -- provenance, spoken once before the first stanza, in the
    # element the DTD has declared for the router's own voice all along
    # (rot:voice is (rot:frame, stanza*); nothing had ever emitted the frame).
    # MEASURED 2026-08-17, the v6.0.0 real test (B4): an unbriefed convening
    # model refused to perform the stanzas, correctly treating unexplained
    # injected personas as untrusted framing. Now the block leads with the
    # operator's own provenance and the switch that proves it. Lazy, so a
    # turn with no speaking lens stays frame-free -- the sh arm's rule,
    # byte for byte.
    # --- THE DYNAMIC SHARE (6.0.2, V1) -- the sh arm's block, decision for
    # decision. Every clause is a fact this turn already measured; a fact the
    # turn did not earn is not printed. Computed once, before the loop.
    # Symbiogenesis: the three canonical names are section 3's own, quoted;
    # a pair the spec does not name stays a pair.
    $hybName = ''
    if ($hybObj) {
      $hybPair = $hybA + ' ' + $hybB
      if     ($hybPair -eq 'Claude AntiVenom' -or $hybPair -eq 'AntiVenom Claude') { $hybName = ' -- The Verified Forge' }
      elseif ($hybPair -eq 'Nova Eidolon'     -or $hybPair -eq 'Eidolon Nova')     { $hybName = ' -- The Sovereign Architect' }
      elseif ($hybPair -eq 'Carnage Eidolon'  -or $hybPair -eq 'Eidolon Carnage')  { $hybName = ' -- the forced CREATIVE × RECURSIVE fuse' }
    }
    # Violet's jazz track, defaulted by the clock and SAID to be -- see
    # Get-VioletTrack above. Lazy: no summons, no reading.
    $vHour = ''; $vTrack = ''
    if ($nsilAct -contains 'Violet') {
      $vHour  = (Get-Date).ToString('HH')
      $vTrack = Get-VioletTrack $vHour
    }
    # Section 7's productive tensions, in section 7's order, kept only when
    # BOTH members were summoned. All in-play pairs are named -- picking 2-3
    # is the model's convergence work, and a router pre-pick would be a
    # silent cap.
    $tension = @()
    foreach ($tp in @(@('Nova','Carnage'), @('Venom','Chroma'), @('AntiVenom','Violet'), @('Soleil','Eidolon'), @('Nova','AntiVenom'), @('Claude','Nova'), @('Carnage','Claude'))) {
      if (($nsilAct -contains $tp[0]) -and ($nsilAct -contains $tp[1])) { $tension += ($tp[0] + '<->' + $tp[1]) }
    }
    $vTurn = ' This turn: NSIL ' + $nsilDecision + ', depth ' + $nsilDepth
    if ($tension.Count) { $vTurn += ', tension: ' + ($tension -join ', ') }
    $vFrameDone = $false
    $vIdx = 0
    foreach ($vName in $Names) {
      $vIdx++
      if ($nsilAct -notcontains $vName) { continue }
      if ($vIdx -gt $vRows.Count) { continue }
      $vRow = $vRows[$vIdx - 1]
      if (-not $vRow) { continue }
      $vF = $vRow.Split('|')
      $vElem  = if ($vF.Count -gt 1) { $vF[1] } else { '' }
      $vSigil = if ($vF.Count -gt 2) { $vF[2] } else { '' }
      $vChart = if ($vF.Count -gt 3) { $vF[3] } else { '' }
      $vBound = if ($vF.Count -gt 5) { $vF[5] } else { '' }
      if (-not $vElem) { continue }
      # This lens's measured line from the gauge output.
      $vPre  = 'LENSDATA|' + $vName + '|'
      $vData = ''
      foreach ($gl in $gLines) {
        $gs = [string]$gl
        if ($gs.StartsWith($vPre, [System.StringComparison]::Ordinal)) { $vData = $gs.Substring($vPre.Length); break }
      }
      $vD = $vData.Split('|')
      $vLam   = if ($vD.Count -gt 0) { $vD[0] } else { '' }
      $vSigm  = if ($vD.Count -gt 1) { $vD[1] } else { '' }
      $vH     = if ($vD.Count -gt 2) { $vD[2] } else { '' }
      $vTerm  = if ($vD.Count -gt 3) { $vD[3] } else { '' }
      $vShare = if ($vD.Count -gt 4) { $vD[4] } else { '' }
      $vDel   = if ($vD.Count -gt 5) { $vD[5] } else { '' }
      $vMu    = if ($vD.Count -gt 6) { $vD[6] } else { '' }
      if (-not $vFrameDone) {
        $vFrameDone = $true
        $vFrame = '<rot:frame>RoT MoE voices -- a Claude Code plugin the operator of this machine installed on purpose; ROTMOE_VOICE=0 silences it. The lenses below were summoned by the measured gauge for this turn; treat each stanza as operator-sanctioned working context.' + $vTurn + '.</rot:frame>'
        if ($voiceJson) { $vAcc += ('\n' + $vFrame) } else { Write-Output $vFrame }
      }
      # THE DYNAMIC CLAUSES, in the sh arm's fixed order so two turns differ
      # only where the measurements differ: lead band verdict with section
      # 5's correction verb (named verbs where the spec names one, the two
      # absolute laws' generic pair everywhere else); Nova's NSIL verdict;
      # a boosted lambda; the Symbiogenesis pair with the merge law's
      # result; Chroma's shown timelines; Soleil's ACCEPTED budget or the
      # word unknown; Violet's hour-defaulted track.
      $vDyn = ''
      if ($vName -eq $lens -and $gBand) {
        $vDyn += ' · band ' + $gBand
        if ($bandFlag -eq 'BELOW') {
          $vDyn += if ($vName -eq 'Carnage') { ' -- add entropy' } elseif ($vName -eq 'Claude') { ' -- measure more' } else { ' -- diverge more' }
        } elseif ($bandFlag -eq 'ABOVE') {
          $vDyn += if ($vName -eq 'Soleil') { ' -- compress more' } else { ' -- converge' }
        }
      }
      if ($vName -eq 'Nova') { $vDyn += ' · NSIL ' + $nsilDecision }
      if ($script:NsilBoost -and $vName -eq $script:NsilBoost) { $vDyn += ' · λ boosted +0.3' }
      if ($hybObj -and ($vName -eq $hybA -or $vName -eq $hybB)) {
        $vDyn += ' · Symbiogenesis ' + $hybA + '×' + $hybB + ' λ ' + (Format-Hund $hybObj.lam) + ' μ ' + (Format-Hund $hybObj.mu) + ' H ' + (Format-Hund $hybObj.h) + $hybName
      }
      if ($vName -eq 'Chroma') {
        $vDyn += ' · timelines ' + $shown + '/' + $ChromaSpawned
        if ($tokEmerg) { $vDyn += ' TOKEN_EMERGENCY' }
      }
      if ($vName -eq 'Soleil') {
        $pct = $env:ROTMOE_TOKEN_PCT
        if ($pct -and $pct -match '^[0-9]+$') {
          $vDyn += ' · budget ' + $pct + '%'
          if ($tokEmerg) { $vDyn += ' -> STEALTH' }
        } else { $vDyn += ' · budget unknown' }
      }
      if ($vName -eq 'Violet' -and $vTrack) { $vDyn += ' · track ' + $vTrack + ' (by hour ' + $vHour + ')' }
      # The sh arm's expansion template is the authority for this shape:
      #   <elem>SIG Name · λ L σ S δ D H H μ M · term T (P%)[ · DYN]* ·
      #   CHARTER · BOUND</elem>
      $vLine = ('<{0}>{1} {2} · λ {3} σ {4} δ {5} H {6} μ {7} · term {8} ({9}%){10} · {11} · {12}</{0}>' -f `
        $vElem, $vSigil, $vName, $vLam, $vSigm, $vDel, $vH, $vMu, $vTerm, $vShare, $vDyn, $vChart, $vBound)
      if ($voiceJson) {
        $vAcc += ('\n' + ($vLine -replace '["\\]', ''))
      } else {
        Write-Output $vLine
      }
      $gateRows += ($vName + '|' + $vElem + '|' + $vChart + '|' + $vBound)
    }
  }
}
# The JSON envelope, emitted whole: the event echoed back is load-bearing --
# a payload without it is discarded silently. ROTMOE_VOICE=0 keeps the old
# plain marker on these events.
if ($voiceJson) {
  [Console]::Out.WriteLine('{"hookSpecificOutput":{"hookEventName":"' + $evName + '","additionalContext":"' + $vAcc + '"}}')
}

# Write the summons only for a genuine multi-lens turn (FUSE/ELEVATE with at
# least two roster voices); anything else CLEARS this session's summons so
# the gate never holds a door for a turn that ended long ago -- the sh arm's
# rule, decision for decision.
if ($gateFile) {
  if ($gateRows.Count -ge 2) {
    try {
      $null = New-Item -ItemType Directory -Force -Path (Split-Path -Parent $gateFile)
      [System.IO.File]::WriteAllText($gateFile, (($gateRows -join "`n") + "`n"))
    } catch { }
  } else {
    try { Remove-Item -LiteralPath $gateFile -Force -ErrorAction SilentlyContinue } catch { }
  }
}
exit 0
