# 05 — Evaluation

How an attempt is judged. Input: the `PitchFrame`s captured during the listen window, the target `Phrase`, the flute's calibrated Sa and the session settings. Output: an `AttemptResult`. All of this is pure Dart in `aaroha_core/lib/src/eval`.

All defaults below are starting points, to be tuned against fixtures (docs/07). Changes go into decisions.md.

## 1. Frame cleanup

1. **Voicing:** a frame is voiced if `hz > 0`, `confidence ≥ 0.85` and `rms ≥ noiseFloor × 3`. The noise floor is measured from ~0.5 s of silence when a session starts (and refreshed during quiet gaps).
2. **Cents:** `cents = 1200 × log2(hz / saHz)` for voiced frames.
3. **Smoothing:** 5-frame median filter on cents (removes single-frame spikes).
4. **Octave-jump repair:** a frame that differs from both neighbours by 1200 ± 50 cents is folded back to their octave.

## 2. Quantising to swars

For each voiced frame, find the nearest pitch `(swar, saptak)` in the active tuning table, and the deviation in cents from it. Use **hysteresis**: a frame only switches to a new swar if it is closer to the new one by more than 15 cents, so a note hovering near a boundary doesn't flicker.

## 3. Segmenting into notes

A **note** is a run of voiced frames on the same quantised swar lasting at least **120 ms**. Shorter runs between notes are treated as transitions (slides, finger movements) and dropped. So are runs under **250 ms** whose pitch wobbles by more than ±20 cents (standard deviation): a real short note is steady, an unstable moment in the tone is not.

**Faint, unclear notes** are breaths, not notes: in an attempt with more than one note, a note whose median level is more than ~16.5 dB below the attempt's typical note *and* whose median confidence is under 0.9 is dropped. On such a sound the tracker can lock onto half the pitch (decisions.md D29). A faint but clear note stays, and a single note is never compared with itself.

**Octave flips** under **200 ms** on the same swar as a touching note, in another octave and with no re-articulation between them, become part of that note (its cracked attack or a release slipping down). The following note is preferred. Longer flips, like a 320 ms overblow into taar Ga, stay as their own note and get judged (decisions.md D22).

For each note:
- `onset` = engine time of its first frame
- `duration`
- `stableCents` = median cents of the note **excluding the first 80 ms** (the attack/breath transient) and the last 40 ms
- `stability` = standard deviation of cents in that stable part

**Repeated swars** (S S S) produce no pitch change. Split a run into separate notes when:
- a **quiet** gap of unvoiced frames ≥ 40 ms appears (tonguing, breath articulation; quiet = rms below 40% of the recent peak), or
- the level **dips ≥ 16 dB** below the recent peak (the last 300 ms) for at least 20 ms **and then comes back** to within 6 dB of it. The next note starts where the level recovers.

Frames inside a dip are the note's **tail**: they extend its duration but don't count toward its pitch and can't start a new note. A dip that never recovers (a fade at the end of a breath) just ends the note. A dip lasting over 400 ms is taken as the player's new level, not an articulation.

The 16 dB depth comes from real recordings: the owner's breath pulse swings the level 10–12 dB two or three times a second while the pitch stays steady, and the earlier 8 dB rule split those notes into many. Repeated-note splitting is still a known weak spot: check it with the `repeats` fixtures.

**Loud unvoiced frames are bridged.** When frames go unvoiced but the level stays up (rms ≥ 40% of the note's peak), something is masking the flute rather than the player stopping. A drone pluck does this for 50–100 ms. Such stretches only end a note after 150 ms. Without this rule, each drone pluck split a held note in two (found by the synthetic self-test, decisions.md D17).

## 4. Judging pitch

### Single swar

Take the first note of at least 300 ms in the listen window.

| Outcome | Condition |
|---|---|
| **Pass** | right swar (and octave, if "octave must match" is on), and `|stableCents − targetCents| ≤ tolerance` |
| **Out of tune** | right swar, deviation beyond tolerance |
| **Wrong swar** | a different swar |
| **Wrong octave** | right swar, wrong saptak, octave must match |
| **No note** | nothing usable before timeout |

The result always carries what was heard: swar, saptak, deviation in cents, stability. The UI shows "Ga, 32 cents flat" rather than just "fail".

**Which outcomes pass the attempt:** *Pass* and, unless **strict intonation** is on, *Out of tune*: the ear got the swar right, so the round is passed and the cents are shown (amber) and tracked in the intonation stats. Wrong swar, wrong octave and no note always fail (decisions.md D31). Deviations are measured in the session's tuning, just intonation by default.

**Deviation is measured from the target pitch.** With `dev = stableCents − targetCents` (after the octave rule):

- `|dev| ≤ tolerance` → pass
- `tolerance < |dev| < 50` → out of tune: the right swar, but flat or sharp
- `|dev| ≥ 50` → wrong swar: report the nearest swar plus its own deviation ("komal Ga, +8")

The 50-cent line is half a semitone, the natural midpoint between neighbouring swars.

### Phrase (pitch only, v0.1–v0.2)

1. Segment the attempt into notes (step 3).
2. Merge back-to-back played notes on the same pitch, unless the target itself repeats a pitch back to back. A note split by an extra breath then counts once.
3. Align the played sequence with the targets by **edit distance**. A pair costs 0 when the played note is within 50 c of its target (in or out of tune), else 1; a missing or extra note costs 1. On ties, notes match the earliest targets they can ("S S R" played as "S R" misses the second S), but a substitution beats missing + extra.
4. Each matched pair is judged as in single-swar mode.
5. **Pass** = every target matched with the right swar, no extra notes. With **strict intonation** on, every note must also be in tune.

Result: per-note verdicts, so the UI can colour each note of the notation.

### Ending an attempt (v0.1)

The call reaches the mic one **round trip** late (output latency + room + input latency; ~430 ms on the moto g45). The app measures it from every call: the first tracker frame at the call's pitch, minus the call's scheduled start. It keeps the median of the last 9 measurements, saved between runs (450 ms until measured). The listening window opens at **call end + round trip + 150 ms**, once the call's echo has passed. Only frames inside it count. The attempt is judged when:

| Mode | Judged when |
|---|---|
| Single swar | a note ≥ 300 ms exists and the player has been quiet 500 ms, or that note has lasted 1.5 s |
| Phrase | at least as many notes as targets and 600 ms quiet, or any notes and 1.5 s quiet |
| Both | the window times out: twice the call's length + 4 s (8 s for "Try again") |

"Try again" listens again without replaying; "Replay" plays the call, then listens. Every judged listen is an attempt; attempt 1 is the first try.

### Hints (M2-A)

When "after a miss, show" is set to *a hint*, each note's verdict becomes a hint that never names a swar (`aaroha_core/lib/src/eval/hint.dart`). The direction comes from the played pitch minus the target, in the session's tuning:

| Verdict | Hint |
|---|---|
| Pass | Right |
| Out of tune | Right note, a little flat / sharp |
| Wrong swar, up to 250 c away | Too low / high |
| Wrong swar, further | Much too low / high |
| Wrong octave | Right note, an octave too low / high |
| Missing / extra (phrases) | A note is missing / One note too many |

For phrases, a row of arrows shows which way to move each note: ↑ (play higher), ↓ (play lower), ✓, `·` (missing), `+` (extra).

## 5. Judging rhythm (v0.3)

- **Expected onsets** come from the phrase and the tempo, offset from the listen window's start. The player starts after a count-in, so the downbeat is known. Alternatively ("free start" setting) the first played onset anchors the phrase.
- **Played onsets** = note onsets from step 3, minus the measured loopback latency, refined with an energy-based onset detector (spectral flux) for notes that start from silence.
- **Timing error** per note = played − expected onset, as a fraction of a matra. Default tolerance ±15% of a matra.
- **Duration error** = played vs expected duration ratio; default tolerance ±25%. Releases are less precise than onsets on flute, so duration counts less than onset.
- **Tempo drift:** fit a line through (expected, played) onsets. The slope shows rushing or dragging. Report it rather than failing on it at first.

## 6. Ornaments (v0.4)

Ornaments are judged on the **pitch curve**, not on segmented notes:
- Render the target phrase (with kan/meend) into an expected cents-over-time curve.
- Align the played curve to it with **DTW** (dynamic time warping), constrained to a band around the expected timing.
- Score = mean absolute cents error along the path, plus checks that a kan's peak appears and a meend passes through intermediate pitches rather than jumping.

## 7. Stats

Recorded per attempt; computed from the `attempts` table.

- **First-try accuracy** per session, per swar, per mode. The headline number.
- **Confusion matrix:** target pitch × played pitch, first attempts only. Shown as a grid. Highlights pairs like Ga↔Ma, Dha↔komal Dha.
- **Intonation per flute:** for each flute and swar, mean and spread of the deviation in passing *and* out-of-tune attempts. If a swar is off on one flute but fine on the others, it's likely the flute's hole; if it's off on all of them, it's the player.
- **Attempts to correct** and **time to correct** per round, as a secondary measure.

As built (M2-C, *Your ear* screen): stats use each swar's **last 40 first tries**, from flute sessions and Listen & name alike, pooled across flutes (hearing is relative to Sa). A first try counts as right when the swar was right, in tune or not (D31); *missing* counts as a miss but not as a confusion, and out-of-tune right swars are not confusions; nor is a note 50 c or more off whose nearest allowed swar is still the target (a miss, not a mix-up). The screen shows right-first-time per swar, the *Heard as* grid (wrong swars and wrong octaves), and mean intonation per swar on the selected flute, in the current tuning, from flute attempts on the right swar only (tapped answers say nothing about intonation). Played cents are rebuilt from each stored deviation in that session's own tuning, so just and equal-tempered sessions line up. Extra notes in a phrase have no target and are left out.

## 8. Adaptive target picking

When choosing the next target from the allowed set (single swar, or which phrase to drill):

```
weight(swar) = (0.15 + (misses + 1) / (firstTries + 2))      # smoothed miss rate, plus a floor
             × (1 + min(daysSinceLastSeen / 7, 1))            # up to ×2 if not seen for a week
```

Counts are over the swar's last 40 first tries (§7); a swar never practised counts as unseen for a week. The floor keeps well-known swars coming up. Pick randomly in proportion to weight, never the same swar twice in a row. Phrases start from a weighted swar, then walk by steps as before.

**Contrast drills:** a confused pair is one seen at least twice recently (target → answered). 20% of targets are a contrast drill from the three most confused pairs within the allowed set: the two swars as two single rounds back to back, or, in phrase practice, as one two-note phrase. History loads when a session starts and each first try is added as it happens, so the session adapts as it goes. The *Focus on swars you miss* setting (on by default) turns all this off for plain random targets. Later: spaced repetition for phrases.

## Defaults summary

| Parameter | Default |
|---|---|
| Voicing confidence | ≥ 0.85 |
| Voicing loudness | ≥ 3 × noise floor |
| Median filter | 5 frames |
| Swar hysteresis | 15 cents |
| Min note length | 120 ms |
| Unstable short run (transition) | < 250 ms and > ±20 cents |
| Quiet gap that ends a note | 40 ms (below 40% of recent peak) |
| Loud unvoiced gap that ends a note | 150 ms |
| Re-articulation dip | ≥ 16 dB for ≥ 20 ms, recovering to −6 dB |
| Recent-peak window | 300 ms |
| Longest dip still treated as a dip | 400 ms |
| Faint note dropped | < 0.15 × typical level (≈ −16.5 dB) and confidence < 0.9 |
| Attack excluded | 80 ms |
| Single-swar min note | 300 ms |
| Pitch tolerance | ±25 cents |
| Onset tolerance | ±15% of a matra |
| Duration tolerance | ±25% |
| End-of-attempt silence | 600 ms |
