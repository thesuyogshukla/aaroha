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

## M2 — v0.2: real material

- Notation parser complete for pitch (docs/03), content files loaded from `content/`.
- Alankar generator.
- Raga mode with fixed phrases for a starter set of ragas (docs/06).
- All three octaves within flute range.
- Live pitch trace over target notes.
- Confusion grid and adaptive drilling of weak swars.

## M3 — v0.3: rhythm

- Durations in the notation (matras, holds, subdivisions).
- Metronome; then tabla theka for keherwa, dadra, teentaal, rupak.
- Output-to-input latency calibration.
- Onset detection and timing scores (docs/05).

## M4 — v0.4: depth

- Generated raga phrases following each raga's rules.
- Ornaments: kan and meend (notation + contour comparison).
- Name-the-swar mode.
- User-entered tunes/compositions.
- Sampled bansuri voice for the call; better tanpura.

## M5 — Publishing

- iOS audio session work and testing.
- Onboarding, empty states, help.
- Licensing check for every bundled sound and content file.
- Store listings, privacy statement (no data collected).
- Web build: evaluate whether the C++ core compiles to WebAssembly with acceptable latency.
