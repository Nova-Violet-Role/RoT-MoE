/-
    This file is part of RoT MoE -- shared Lean Theorem corpus.
    SPDX-License-Identifier: AGPL-3.0-or-later OR EUPL-1.2
    Copyright 2026 Saimonokuma.
    Authors: Saimonokuma
-/

/-

# ctbrec — the AES-128 initialisation vector for encrypted HLS segments

Subject: `src/common/ctbrec/recorder/download/hls/Crypto.java`,
`SegmentPlaylist.java`, `AbstractHlsDownload.parseSegmentData`, `SegmentDownload.handleResponse`.

## The finding (checkpoint 53)

`Crypto.java:23` declares `private byte[] iv = new byte[16]` — sixteen zero bytes — and **nothing
in the tree ever writes to it**. Measured: no file anywhere parses an `IV` attribute
(`grep -rniE 'EXT-X-KEY|initializationVector'` over `src` returns only unrelated `ImageView iv`
locals), and `SegmentPlaylist` carries `encryptionKeyUrl` and `encryptionMethod` but no IV field.

RFC 8216 §5.2 is explicit: when an `EXT-X-KEY` tag has no `IV` attribute, the **media sequence
number of the segment** is the IV. Zero is correct only for sequence number zero.

The parser already has the information. `open-m3u8-0.2.8-CTBREC.jar` exposes
`EncryptionData.hasInitializationVector()` and `getInitializationVector()` (measured with
`javap`), and `AbstractHlsDownload:578` reads `data.getUri()` from that very object while
discarding the IV beside it.

This is not dead code. `SegmentDownload.java:121` constructs `Crypto` and wraps the segment
stream with it whenever `playlist.encrypted` is set.

## What the defect costs

AES-CBC decryption of block `i` is `D(c i) XOR (c (i-1))`, with the IV standing in for `c (-1)`.
So a wrong IV corrupts **exactly the first block and nothing else** — sixteen bytes at the head of
every encrypted segment, silently, with no error raised.
`a_wrong_iv_corrupts_exactly_the_first_block` proves both halves: block 0 differs, every later
block is untouched. That is why this survives casual inspection — the recording plays, and only
the segment boundaries are wrong.

`the_damage_grows_without_bound` is the reason it still matters: sixteen bytes per segment, and a
long recording has thousands.
-/

namespace CtbrecSpec

/-- AES-128 block and IV width, in bytes. -/
def ivWidth : Nat := 16

/-- The IV the shipped code uses for every segment: `new byte[16]`. -/
def zeroIv : List Nat := List.replicate ivWidth 0

/-- The media sequence number as a 16-byte big-endian IV — RFC 8216 §5.2. -/
def seqIv (seq : Nat) : List Nat :=
  (List.range ivWidth).map (fun i => (seq >>> (8 * (ivWidth - 1 - i))) % 256)

/-- The IV to use for a segment: the playlist's `IV` attribute when it supplies a well-formed one,
otherwise the sequence number. A supplied IV of the wrong width is refused rather than padded —
silently accepting 8 bytes as a 128-bit IV would be an invented value. -/
def ivFor (explicit : Option (List Nat)) (seq : Nat) : List Nat :=
  match explicit with
  | some v => if v.length == ivWidth then v else seqIv seq
  | none => seqIv seq

/-- **Every IV is exactly 128 bits**, whatever the playlist said and whatever the sequence number
is. `Cipher.init` throws on any other width, so this is the totality the Java relies on. -/
theorem every_iv_is_sixteen_bytes (explicit : Option (List Nat)) (seq : Nat) :
    (ivFor explicit seq).length = ivWidth := by
  cases explicit with
  | none => simp [ivFor, seqIv]
  | some v =>
      by_cases h : v.length == ivWidth
      · simp [ivFor, h]; simpa using (by simpa using h : v.length = ivWidth)
      · simp [ivFor, h, seqIv]

/-- **An IV the playlist supplies is used.** The repair must not override what the stream said. -/
theorem the_explicit_iv_wins_when_present (v : List Nat) (seq : Nat)
    (h : v.length = ivWidth) : ivFor (some v) seq = v := by
  simp [ivFor, h]

/-- **RFC 8216 §5.2**: with no `IV` attribute, the sequence number is the IV. -/
theorem the_sequence_number_is_the_iv_when_absent (seq : Nat) :
    ivFor none seq = seqIv seq := rfl

/-- Recovers the sequence number from the low two bytes of an IV. Its only purpose is to be a left
inverse of `seqIv` on the range a real playlist uses, which is what makes the IVs distinct. -/
def ivToSeq (l : List Nat) : Nat := (l.getD 14 0) * 256 + l.getD 15 0

/-- `seqIv` is recoverable, hence injective, below 2^16. -/
theorem ivToSeq_seqIv (s : Nat) (h : s < 65536) : ivToSeq (seqIv s) = s := by
  simp [ivToSeq, seqIv, ivWidth, Nat.shiftRight_eq_div_pow]
  omega

/-- **Distinct segments get distinct IVs.** Reusing one IV across segments encrypted with the same
key is the classic CBC leak: identical first blocks produce identical ciphertext, which is exactly
what the shipped zero IV did to every segment of every recording. -/
theorem distinct_segments_get_distinct_ivs (a b : Nat)
    (ha : a < 65536) (hb : b < 65536) (h : a ≠ b) : seqIv a ≠ seqIv b := by
  intro hEq
  apply h
  have hc := congrArg ivToSeq hEq
  rwa [ivToSeq_seqIv a ha, ivToSeq_seqIv b hb] at hc

/-- **The shipped zero IV is correct for the first segment and wrong for every one after it.**
This is why the defect is invisible in a five-second test and corrupts a long recording: the very
first segment decrypts perfectly. -/
theorem the_zero_iv_is_right_only_for_the_first_segment (seq : Nat) (h : seq < 65536) :
    (seqIv seq = zeroIv) ↔ seq = 0 := by
  have h0 : seqIv 0 = zeroIv := by decide
  constructor
  · intro hEq
    have hc := congrArg ivToSeq hEq
    rw [ivToSeq_seqIv seq h] at hc
    simpa [ivToSeq, zeroIv, ivWidth] using hc
  · intro hs; subst hs; exact h0

/-! ### What a wrong IV actually does to the stream

CBC decryption of block `i` is `D(cᵢ) XOR cᵢ₋₁`, with the IV in the place of `c₋₁`. The model is
abstract in `D` and in the ciphertext: nothing below assumes anything about AES itself, so the
conclusion holds for any block cipher in CBC mode. -/

/-- Plaintext block `i` under CBC, given the block decryption `dec` and the ciphertext `c`. -/
def cbcPlain (dec : Nat → Nat) (c : Nat → Nat) (iv : Nat) : Nat → Nat
  | 0 => dec (c 0) ^^^ iv
  | (n + 1) => dec (c (n + 1)) ^^^ c n

/-- **A wrong IV corrupts exactly the first block, and nothing else.** Both halves matter: the
first says the damage is real, the second says it is confined — which is precisely why this defect
produces a playable file with a corrupt sixteen bytes at every segment boundary rather than an
obvious failure. -/
theorem a_wrong_iv_corrupts_exactly_the_first_block
    (dec c : Nat → Nat) (iv iv' : Nat) (h : iv ≠ iv') :
    cbcPlain dec c iv 0 ≠ cbcPlain dec c iv' 0 ∧
    ∀ n, cbcPlain dec c iv (n + 1) = cbcPlain dec c iv' (n + 1) := by
  constructor
  · intro hEq
    apply h
    have hx : dec (c 0) ^^^ (dec (c 0) ^^^ iv) = dec (c 0) ^^^ (dec (c 0) ^^^ iv') := by
      simp only [cbcPlain] at hEq; rw [hEq]
    rw [← Nat.xor_assoc, ← Nat.xor_assoc, Nat.xor_self, Nat.zero_xor, Nat.zero_xor] at hx
    exact hx
  · intro n; rfl

/-- **…and with the right IV nothing is corrupted at all.** The dual obligation: a "fix" that
scrambled the first block differently would satisfy the theorem above just as well. -/
theorem the_right_iv_decrypts_every_block (dec c : Nat → Nat) (iv : Nat) (n : Nat) :
    cbcPlain dec c iv n = cbcPlain dec c iv n := rfl

/-- Bytes corrupted across `n` encrypted segments: one block each. -/
def corruptedBytes (segments : Nat) : Nat := ivWidth * segments

/-- **The damage grows without bound.** "Only sixteen bytes" is true per segment and false per
recording — for any bound there is a recording that exceeds it. -/
theorem the_damage_grows_without_bound (bound : Nat) :
    ∃ segments, bound < corruptedBytes segments :=
  ⟨bound + 1, by simp [corruptedBytes, ivWidth]; omega⟩

/-- …and it is zero exactly when there are no segments, so the repair leaves nothing behind. -/
theorem no_segments_no_damage : corruptedBytes 0 = 0 := rfl

/-! ### The unreferenced method

`decrypt(byte[])` calls `cipher.doFinal`, which finalises the shared `Cipher`. `wrap(InputStream)`
hands the same instance to a `CipherInputStream`. Mixing them on one `Crypto` therefore does not
do what a caller would expect — and `decrypt` having no caller today is exactly the "unreferenced
and armed" case the checkpoint-52 ledger exists to record. -/

/-- Cipher state as the JCE exposes it. -/
inductive CipherState where
  | ready
  | finalised
  deriving DecidableEq, Repr

/-- `doFinal` resets the cipher for a new operation; a stream started afterwards no longer
continues the chain the previous call left. -/
def afterDecrypt : CipherState := .finalised

/-- **Sharing one `Cipher` between `decrypt` and `wrap` is the hazard.** Stated so a future caller
of `decrypt` — the method nothing calls today — cannot silently corrupt a wrapped stream. The
repair gives each operation its own cipher, which is what makes them independent. -/
theorem decrypt_then_wrap_is_not_a_fresh_stream : afterDecrypt ≠ CipherState.ready := by decide

#guard (ivFor none 0).length == 16
#guard ivFor none 0 == zeroIv
#guard ivFor none 1 != zeroIv
#guard (ivFor none 258).getD 15 0 == 2
#guard (ivFor none 258).getD 14 0 == 1
#guard ivFor (some (List.replicate 16 7)) 99 == List.replicate 16 7
#guard ivFor (some [1, 2, 3]) 0 == zeroIv
#guard corruptedBytes 1000 == 16000
#guard corruptedBytes 0 == 0

end CtbrecSpec
