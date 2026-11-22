# 01 — Product

## The problem

A bansuri player can have good finger technique and still not recognise notes by ear. Hearing a note and finding it today takes trial and error. That trial and error is exactly what trains the ear, but it needs someone to:

1. keep playing fresh notes and phrases,
2. tell you honestly when you were wrong, because a note that is close can feel correct,
3. raise the difficulty as you improve.

Traditionally that someone is the guru. Aaroha does the repetitive part of that role.

## Who it's for

- **First:** the owner, for daily riyaz on their own flutes.
- **Later, if it works well:** other bansuri players, published on Play Store and App Store.

## Principles

1. **Relative to Sa, always.** Hindustani hearing is relative. Every note is heard against a tanpura drone and judged in cents from the flute's Sa.
2. **First-try accuracy is the real score.** Hunting for the note is allowed and useful, but progress is measured by getting it right the first time.
3. **Honest, specific feedback.** Not just pass/fail: "you played Ma, the note was Ga" is different from "right note, 30 cents flat".
4. **Real material over random notes.** Random notes are only the first rung. Alankars, raga phrases and compositions train the ear and teach reusable phrases.
5. **Calm, riyaz-friendly UI.** Big, simple, usable with a flute in your hands. Few taps between rounds.
6. **Offline and private.** No account, no network, audio never leaves the phone.

## Training modes

| Mode | What the app plays | First version |
|---|---|---|
| **Single swar** | One note from a chosen set | v0.1 |
| **Short phrase** | 2–4 notes, equal length, pitch judged only | v0.1 |
| **Alankar** | Classic patterns (paltas) generated over a chosen scale | v0.2 |
| **Raga** | Aaroh, avaroh, pakad and chalan phrases of a raga | v0.2 (fixed phrases), v0.4 (generated) |
| **Rhythm** | Phrases with different note lengths, in a taal, over metronome or theka | v0.3 |
| **Composition** | Lines of a bandish/gat or a user-entered tune | v0.4 |
| **Name the swar** *(bonus)* | One note or a short phrase; you tap the swar names instead of playing | v0.4 |

### A round

1. Drone is playing (pitched to the selected flute's Sa).
2. Optional count-in.
3. The app plays the target (the *call*).
4. The app listens (the *response*). A visual ring/indicator shows it's listening.
5. Verdict: pass or fail, with detail (which swar you played, cents off, and for phrases which note went wrong).
6. Options: **Retry** (counts as a further attempt), **Replay the call**, **Next**. Auto-advance on pass is a setting.

A **session** is a set of rounds (default 20) ending in a summary: first-try accuracy, slowest/most-confused swars, intonation notes.

### Difficulty dimensions

Difficulty is raised along separate axes, not a single level number:

- **Swar set:** Sa–Pa only → all shuddha → add komal/tivra → full chromatic
- **Range:** madhya only → add mandra → add taar
- **Length:** 1 note → 2–4 → 5–8 → full lines
- **Rhythm:** equal lengths → mixed lengths → in taal
- **Material:** random → alankar → raga → compositions
- **Notation:** shown → shown after attempt → hidden
- **Tolerance:** ±35 cents → ±25 → ±15

Presets ("Level 1", "Level 2"…) bundle these. Each axis can also be set by hand. An optional **auto-progress** suggests the next step when first-try accuracy stays above ~85% over the last 2 sessions.

## Flutes

The user has several flutes. Each has a **profile** (name, nominal Sa, calibrated Sa, range). You pick a flute before a session. Calibration is saved, with a quick 2-second "play Sa" check offered at session start. See [02-music-model.md](02-music-model.md).

## Settings

| Setting | Default | Notes |
|---|---|---|
| Pitch tolerance | ±25 cents | Per-session override |
| Octave must match | On | Off = judge pitch class only (easier) |
| Tuning | Equal temperament | Or just intonation; see 02 |
| Notation display | Shown | Shown / After attempt / Hidden |
| Notation script | Latin (S R G) | Or Devanagari (सा रे ग) |
| Drone | On, octave below Sa | Pa / Ma / Ni tuning per raga; volume |
| Duck drone while listening | Off | Turn on if drone bleed hurts detection |
| Tempo | 60 matras/min | Rhythm modes |
| Count-in | On | |
| Auto-advance on pass | On | |
| Rounds per session | 20 | |
| Max attempts per round | Unlimited | |

## Screens (v0.1)

1. **Home:** current flute (tap to switch), mode picker, preset/level, Start.
2. **Flutes:** list of profiles; add/edit; calibrate.
3. **Calibration:** "play Sa and hold" → live meter → saved Hz with a sanity check against the nominal key.
4. **Practice:** notation area (or hidden), listening indicator, verdict, simple pitch trace, Retry / Replay / Next.
5. **Session summary:** first-try %, per-swar results, confusions.
6. **Stats:** confusion grid (target vs played), per-flute intonation, history over time.
7. **Settings.**

## Out of scope for now

Accounts, cloud sync, social features, teacher/student mode, video, in-app purchases, Carnatic music.
