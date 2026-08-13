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
  @{ Mode = 'EMPATHIC';   Lead = 'Violet';    Stems = @('emot','feel','grief','lonel','soul','story','human','tired','lost') },
  @{ Mode = 'STRATEGIC';  Lead = 'Nova';      Stems = @('strateg','plan','goal','roadmap','priorit','legal','recommend','analyz') },
  @{ Mode = 'CREATIVE';   Lead = 'Carnage';   Stems = @('creativ','chaos','surreal','disrupt','paradox','dream','invent') },
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
$Lambdas = @(1.4, 0.6, 1.9, 1.2, 0.6, 1.0, 1.0, 1.2, 2.3)
$Mus     = @(1.05, 0.85, 1.10, 1.05, 0.90, 1.10, 0.95, 1.10, 1.15)

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
      $lines = @(Get-Content -LiteralPath $p -ErrorAction Stop)
      if ($lines.Count -gt $cap) {
        $keep = $lines[($lines.Count - $cap)..($lines.Count - 1)]
        Set-Content -LiteralPath $p -Value $keep -Encoding utf8 -ErrorAction Stop
      }
    }
  } catch {
    # Rotation is best effort. A log that could not be trimmed is still a log,
    # and this must never escalate into failing the turn.
  }
}

function Invoke-Gauge([string] $Vec, [int] $Br, [double] $M, [double] $C, [double] $T) {
  $acts = @($Vec -split ',' | ForEach-Object { [double]$_ })
  $K = $acts.Count
  $mean = 0.0; foreach ($a in $acts) { $mean += $a }
  $mean = $mean / $K

  $sum = 0.0
  $active = New-Object System.Collections.Generic.List[string]
  $terms  = New-Object System.Collections.Generic.List[string]
  for ($i = 0; $i -lt $K; $i++) {
    $a = $acts[$i]
    if ($a -gt 0) { $active.Add($Names[$i]) }
    $d = [Math]::Abs($a - $mean)
    $s = 1.0 / (1.0 + [Math]::Exp(-4.0 * ($d - 0.5)))
    $H = if ($Br -gt 0) { $a / [double]$Br } else { 0.0 }
    if ($H -gt 1.0) { $H = 1.0 }
    $term = $Lambdas[$i] * $s * (1.0 + $H) * $Mus[$i] * $M * $C * $T
    $sum += $term
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
  $band = if ($R -lt 0.9) { 'BELOW RANGE' } elseif ($R -gt 1.8) { 'ABOVE RANGE' } else { 'IN RANGE (0.9-1.8)' }
  $lenses = if ($active.Count) { $active -join ',' } else { 'none' }
  return ('R/s+ = {0} [{1}] mean={2} breadth={3} K={4} lenses={5}' -f `
          (Format-Num $R 2), $band, (Format-Num $mean 3), $Br, $K, $lenses)
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

if ($Route)  { $r = Split-Routed (Invoke-Route $Route); Write-Output $r[0]; exit 0 }
if ($Vector) { Write-Output (Invoke-Gauge $Vector $Breadth $M $C $T); exit 0 }

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
if ([Console]::IsInputRedirected) {
  try { $payload = [Console]::In.ReadToEnd() } catch { $payload = '' }
}

if ([string]::IsNullOrWhiteSpace($payload)) {
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

# README.md:77 promises this line carries a named lane AND A GAUGE READING. See
# the long note at the same point in rot-router.sh: the vector is the ROUTING
# DECISION expressed one-hot -- the lead lens of the fired lane at 1, the rest
# at 0 -- which is measured, not invented. A CONVERGENT turn fires no lens, so
# its vector is all zeros with breadth 0, and the gauge is defined there too.
# M, C and T are the neutral element 1.0 because one stateless hook call cannot
# measure memory residue, confidence or recency; that is stated, not hidden.
# The index comes from $Names so a roster change moves both arms together.
$__routed = Invoke-Route $prompt
$__rparts = Split-Routed $__routed
$lane  = $__rparts[0]
$stem  = $__rparts[1]
$lens  = ($lane -split ' ')[1]

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
} elseif ($nsilAct.Count -eq 0 -and $nsilWords -ge $Names.Count) {
  $nsilDecision = 'ELEVATE'
  $nsilAct = @($Names)
} else {
  $nsilAct = @($lens)
}

$acts  = @()
$br    = 0
foreach ($n in $Names) {
  if ($nsilAct -contains $n) { $acts += '1'; $br = $br + 1 } else { $acts += '0' }
}
$g  = Invoke-Gauge ($acts -join ',') $br 1 1 1
$rs = if ($g -match '^R/s\+ = ([0-9.]+)') { $Matches[1] } else { 'n/a' }

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
  $evName = '-'
  if ($j -and $j.hook_event_name) {
    $cand = [string]$j.hook_event_name
    if ($cand -match '^[A-Za-z]+$') { $evName = $cand }
  }
  Write-RotDebug ('{{"kind":"route","ts":"{0}","event":"{7}","session":"{8}","src":"{9}","lane":"{1}","lens":"{2}","Rs":"{3}","chars":{4},"stem":"{5}","nsil":"{10}","breadth":{11},"arm":"ps1","ms":{6}}}' -f `
    (Get-Date -Format 'o'), (($lane -split ' ')[0]), $lens, $rs, $prompt.Length, $stem, $ms, $evName, $script:RotSession, $script:RotSrc, $nsilDecision, $br)
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
$nsilTag = ''
if ($nsilDecision -ne '' -and $nsilDecision -ne 'CONFIRM') { $nsilTag = ' [NSIL ' + $nsilDecision + ' ' + ($nsilAct -join '+') + ']' }
Write-Output ("RoT MoE :: TIER 1 -> " + $lane + $nsilTag + " | R/s+ " + $rs + $mark)
exit 0
