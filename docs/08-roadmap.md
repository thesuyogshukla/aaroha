# 08 — Roadmap

Each milestone has acceptance criteria. A milestone is done when the owner has used it in real riyaz and the criteria hold, not just when the code exists.

## M0 — Test build (kept as the base of the real app)

Goal: prove the audio path on a real Android phone with real flutes before building the rest.

- Monorepo scaffold (`app/`, `packages/aaroha_core`, `packages/aaroha_audio`, `tools/`, `fixtures/`).
- C++ core (miniaudio): open mic in unprocessed mode, run YIN, push pitch frames to Dart.
- Simple synthesized drone in the same engine.
- Debug screen: live Hz, cents from Sa, nearest swar, confidence, loudness; Sa entry; drone on/off.
- **Raw recording button** that saves the exact mic stream as WAV (used to build fixtures).
- Host build of the C++ core plus a fixture runner CLI.

Status (2026-10-25): everything above is built. Synthetic self-test passes; the app runs on the owner's moto g(9) with live readings. Remaining: the on-device acceptance checks below and the first fixture session.

Device check, moto g45 5G (Android 15), 2026-10-30: AAudio at 48 kHz; Android's recording monitor shows source UNPROCESSED with no effects on the client or device (no echo cancellation or noise suppression). Capture was moved from the low-latency path to the normal one (perfMode 12 → 10), which adds input latency; that only matters for rhythm scoring and is covered by M3's latency calibration. Playback got a fast track. iOS/macOS build glue is deferred (decisions.md D20).

Acceptance:
- Live readings on a held note jitter less than ±5 cents (steady player).
- No octave jumps on held madhya and taar notes on at least the G and D# flutes.
- Drone through the phone speaker does not take over detection while the flute is playing (or the problem is measured and a mitigation chosen).
- First fixture session recorded and labelled (see 07).

## M1 — v0.1: daily-use basics

- Flute profiles + calibration flow.
- Practice: single swar and short phrase modes, turn-taking (call, then listen).
- Synthesized flute voice for the call.
- Verdict with detail; retry/replay/next; first-try tracking.
- Notation rendering (Latin and Devanagari) and display setting.
- Sessions, summary, attempt history stored locally.
- Settings from 01 that apply to these modes.

Acceptance: the owner does a 15-minute riyaz with it for a week without needing a workaround. Fixture suite passes.

Status (2026-11-02): everything above is built and installed on the moto g45. Covered by checks: notation parser and printer, judging, target generation, segmenter (with real G-flute fixtures), and the flute voice reading back in tune on all 8 flutes. Not yet done: the owner's real practice rounds on the phone (to tune the end-of-attempt timings and the call's loudness), and the D# fixtures. The notation parser, listed under M2, is done already.

## M2 — v0.2: hands-free, ear-only, adaptive, real material

Planned with the owner on 2026-11-22 (decisions.md D32). Built in this order; each piece ends with a short real session (on the flute, or by ear for B) before the next starts.

Already done ahead of M2: the notation parser (docs/03) and all three octaves within the flute's range.

### A. Hands-free practice
- **After a miss** setting: *Wait for me* (today) or *Try again automatically*: the verdict shows, then "Listening again in 3… 2… 1…", then listening resumes. A tap anywhere during the countdown pauses it.
- **Replay before retrying** (on/off): replay the call before each automatic retry, or just listen again.
- **Give up after N misses** (default 3): reveal the answer and, with auto-advance on, move to the next round. Together with auto-advance after a pass, a session can run without touching the phone.
- **Show the target** setting, replacing "Show the notes": *always*, *when the round ends* (passed or given up), *never*. With "after a miss, show: the answer", a miss reveals it too (as the old "after attempt" did); a *Reveal* button peeks at any time; giving up always reveals it.
- **After a miss, show**: *the answer* (today: "You played Ma, not Ga"), *a hint only*, or *nothing* (just ✗).
  - A hint gives direction and size, no names: "A little low/high" (right swar, out of tune), "Too low/high" (one swar off), "Much too low/high" (further). For phrases, one arrow per note position (↑ ↓ ✓), plus "one note too many" or "a note is missing".

Acceptance: a 20-round session runs with both hands on the flute; hints never reveal a swar name.

### B. Listen & name (ear only, no mic)
- The drone plays and the app plays a swar or short phrase. The player taps swar buttons; for a phrase, the notes in order. Each tap gets an instant ✓/✗.
- The buttons show only the swars in the chosen set (Latin or Devanagari). A mandra / madhya / taar switch appears only when the session uses more than one octave.
- A "hear Sa" button replays the reference. The same hint, give-up and auto-advance settings as A apply.
- No microphone, no recording: usable anywhere with headphones. It counts as a separate mode in history; answers feed the same confusion stats as flute practice (C).

As built: the keypad is live from the start of the call; tapped swars fill the "?" slots and turn green or red as they are tapped. After a miss a tap simply starts the next try (no countdown: the hands are free); with "retry by itself" and "replay before retrying", the call replays first. *Hear Sa* replaces *Try again*. After a pass the next round starts in 1 s. The engine runs playback only, so the mic is never opened and no permission is asked. Naming sessions show as "named" in History.

Acceptance: a 20-round naming session takes under 5 minutes; confusions show up in the same stats as flute sessions.

### C. Smart drilling
- **Confusion grid** in stats (target × answered, first tries, both modes) and per-flute intonation (docs/05 §7).
- **Adaptive targets** (docs/05 §8): weight swars and phrases by recent first-try errors; sometimes play a confused pair back to back as a contrast drill (e.g. Ga then Ma).

As built: a *Your ear* screen (the chart icon on Home) shows right first time per swar, the *Heard as* grid and intonation on the selected flute. Targets are weighted by each swar's last 40 first tries with a floor and a "not seen lately" boost; one target in five is a contrast drill when a pair has been confused twice or more. A *Focus on swars you miss* switch (on) turns it off. See D35.

### D. Real material
- **Alankars**: pattern definitions applied to any swar set (docs/06), walked up and down within the flute's range.
- **Raga mode**: aaroh, avaroh, pakad and chalan phrases for 8 starter ragas: Bhupali, Yaman, Bilawal, Kafi, Bhairav, Durga, Khamaj, Des. Raga files live in `content/`, reviewed by the owner, with the drone's first string set per raga.
- Longer phrases (5–8 notes): revisit the call's pace and the end-of-attempt timings (D27) with real sessions.

### E. Pitch trace on the verdict
- After an attempt, the player's pitch curve is drawn against the target notes, showing *how* a note was off: scooped attack, sagging tail, wavering, a crack.
- Never shown live while playing: that would turn ear training into reading a tuner.

## M3 — v0.3: rhythm

- Durations in the notation (matras, holds, subdivisions).
- Metronome; then tabla theka for keherwa, dadra, teentaal, rupak.
- Output-to-input latency calibration.
- Onset detection and timing scores (docs/05).

## M4 — v0.4: depth

- Generated raga phrases following each raga's rules.
- Ornaments: kan and meend (notation + contour comparison).
- User-entered tunes/compositions.
- Sampled bansuri voice for the call; better tanpura.

## M5 — Publishing

- iOS audio session work and testing.
- Onboarding, empty states, help.
- Licensing check for every bundled sound and content file.
- Store listings, privacy statement (no data collected).
- Web build: evaluate whether the C++ core compiles to WebAssembly with acceptable latency.
