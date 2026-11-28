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

As built: *What the app plays* gains **Alankar** (with an alankar and a scale picker: a swar set or any raga) and **Raga** (a raga picker). A line above the target names what is practised ("Yaman · Pakad"); targets longer than 4 notes are drawn smaller; in Listen & name, the keypad offers the session's own swars. History names alankar and raga sessions. The 8 raga files are drafts awaiting the owner's review (each file's `notes` says what to check). See D36.

### Phrase length that grows (added after D)
- Phrases in every mode start at 2–4 notes and grow a note at a time as the player gets them right first time (docs/05 §9, D38). Asked for by the owner after the first raga sessions: longer phrases were hard to follow as a beginner.

### E. Pitch trace on the verdict
- After an attempt, the player's pitch curve is drawn against the target notes, showing *how* a note was off: scooped attack, sagging tail, wavering, a crack.
- Never shown live while playing: that would turn ear training into reading a tuner.

As built: the trace appears under the target once the verdict is in (docs/05 §10, D39), with a *Pitch trace after each try* switch (on). It was designed without the phone, from the owner's recorded sessions: `fixture_runner export` writes each attempt's frames, and `app/test/trace_preview_test.dart` draws them to PNG sheets with the app's own widget. Still to check on the phone: how it fits the verdict screen, and whether 1.5 s after a pass is long enough to read it.

## M3 — v0.3: rhythm

Planned with the owner on 2026-11-23 (decisions.md D42). Built in this order; as in M2, each piece ends with a short real session before the next starts.

Already done ahead of M3: the notation parser reads durations (holds `-`, rests `_`, several notes in a matra, vibhag bars, taal checks; docs/03). What is missing is everything after it. Practice turns a phrase into a plain list of swars, the call gives every note the same length (0.8 s), and the sargam display shows no rhythm.

### A. Timed phrases, end to end
- A practice target keeps its written timing from the content file to the call. The call plays it at a **tempo** in matras per minute. A phrase with no durations is one matra per note, so today's phrases sound the same at 75 per minute (single swars keep their longer note).
- The sargam display draws rhythm the Bhatkhande way: holds as `ऽ` (or `-` in Latin), an arc under the notes that share a matra, vibhag bars.
- Pitch judging doesn't change: the timing is heard and seen, not judged yet.
- Mac: the call's schedule is unit-tested and the display is checked with PNG previews, as for the pitch trace. Phone: hear the calls.

Acceptance: a phrase like `S - RG m | P - DP mG ||` plays and reads as written; existing modes sound as before.

As built: every round's target is now a timed phrase, from the material to the call, the screen, the stored round and the session log (D43). Untimed material gets one matra per note, so it sounds and looks as before; content can now be written with durations, and raga phrases cut to the phrase level keep theirs. *Tempo of the call* on Home (50–110, default 75) sets the call's speed. The sargam display draws holds, rests, arcs under shared matras, bars and breaks; `app/test/notation_preview_test.dart` draws a PNG sheet of examples in both scripts. Still to check on the phone: hearing calls at each tempo. No shipped content uses durations yet; Rhythm mode (E) brings the first.

### B. Metronome and count-in
- A click on every matra, accented on sam (the first matra) and lighter on khali, following the taal's vibhags (keherwa 4+4, dadra 3+3, teentaal 4×4, rupak 3+2+2). Without a taal it's a plain beat.
- **How to start** is a setting with both options, as the owner asked: **count-in** (a bar of clicks before the call and before the response, so the player knows where the first matra falls) or **free start** (no count-in; the player's first note sets where the first matra falls, and the rest is judged from there). Both let rhythm be judged later (docs/05 §5).
- Tempo and click volume are settings; the click plays alongside the drone.

Acceptance: a 10-minute session with the metronome on, at a steady tempo, with no drift against the call.

As built (D44): Home gains, for played phrases, *How you start* (*When ready*, the free start, or *Count-in*), a *Metronome* switch, a *Taal* picker (no taal, keherwa, dadra, teentaal, rupak) and *Click volume*. All are off by default, so practice is unchanged until they're turned on. With a count-in, the call starts on sam after a count-in of the taal's last vibhag (at least 3 matras, 4 without a taal), and a second count-in leads into the player's turn, which starts on a new sam. With a free start, the metronome's cycle carries on from the call into the turn. Clicks are on the engine clock with the call, so they can't drift from it. Single swars and naming never click. The session log records where the clicks, the call and the turn fall, for rhythm judging later. Checked on the Mac: click plans per taal, clicks and call notes on the same frames, no drift over 200 matras, and the self-test and `clickcheck` above. A **beat strip** under *Listen…* and *Your turn* shows the taal's matras as dots, grouped by vibhag and marked × 0 2 3 as in taal notation. Each dot lights as its click is heard (D49). Without a taal there is one dot that flashes. *Your turn* says where to come in: *Start on any sam* with a free start, *Come in on sam* after a count-in (without a taal, *Start on any click* or *Come in after the count-in*). This was added after the owner's first metronome session (36), where a free start left them unsure when to begin. Still to check on the phone: how the clicks sound and whether the accents read clearly on the speaker, the click level against the flute in the mic, and a 10-minute session.

### C. Latency calibration
- The app plays a few clicks and hears them back through the mic. The delay between the two is measured and stored per output. Only rhythm judging needs it (docs/04, Clock).
- The **phone speaker** comes first: it is how the owner practises. Wired headphones follow (the click can't reach the mic through them, so they need another way to measure, or a typical value).
- Bluetooth output is too slow and too variable to judge rhythm on. The app says so and turns rhythm judging off on it, rather than guessing.

Acceptance: three calibrations in a row on the moto g45 speaker agree within 5 ms.

As built (D45): a *Sound delay* row under the rhythm settings on Home (when the metronome or count-in is on) and in Test tools shows the current output and its stored delay, with *Measure*. A measurement plays 6 clicks a second apart with the drone silenced, records the mic, and finds each click. It is saved only when at least 5 clicks are heard and agree within 5 ms. Headphones and Bluetooth are detected through Android's audio devices and explained rather than measured. On the moto g45 speaker: 422.8, 422.8 and 422.7 ms in three runs from a stopped engine, each run's clicks within 0.2 ms. The older echo-based estimate the app uses to time its listening (D28) was 421 ms, so the two agree. Not yet used: rhythm judging (E) will subtract it from played onsets.

### D. Onsets from the flute
- Find where each played note starts. The pitch segmenter gives a rough onset; an energy-based detector (spectral flux) in the C++ core refines notes that start from silence or a tongued attack. (Not needed in the end: see As built.)
- Repeated swars (`S S R R`) are split by articulation. This is today's weak spot (docs/05 §3), and rhythm depends on it.
- New labelled fixtures: the owner plays known rhythms to the metronome at two tempos, including repeated swars. The detector is tuned on the Mac against these and against synthetic notes in the self-test.

Acceptance: onsets within 30 ms of the labels on the new fixtures; repeated swars split correctly at least 9 times in 10.

Recording tool (D46): the recording tool and the measuring stick. Test tools has five rhythm takes in keherwa (docs/07, Rhythm takes), each with a tempo choice of 60 or 90, *Hear it*, and *Record with count-in*, which plays the metronome while recording, stops by itself and labels where sam and every click fell. `fixture_runner rhythm` scores each take's detected onsets against that timing and the stored sound delay. A dry run on the moto g45, without the flute, found all 22 clicks in the recording exactly where the label put them, 421 ms late, matching the measured sound delay. Waiting on: the owner recording the ten takes. The onset detector is tuned on those.

As built (D52): no separate onset detector. The owner's ten takes (2026-11-27) showed the segmenter's onsets are already close: a median 8–25 ms from where each note's own pitch rises in the audio, on every take. An energy or spectral-flux detector would have been worse: the clicks reach the mic about 20 dB above the flute, so it locks onto them and every note played on the beat looks perfect. Repeated swars split correctly in all 52 tongued notes. One take per shape and tempo is now a fixture, and `check` holds the onsets to the pitch rise (median within 30 ms, 90% within 100 ms) with every written note found. `fixture_runner rhythm` also fits the player's tempo, so a take that rushes or drags still checks the detector. The acceptance above assumed a player exactly on the click; measured against the pitch rise, it is met. What's left of "played minus written", a median 40–90 ms on steady takes, is the player's timing. That is what Rhythm practice (E) will report.

### E. Rhythm practice
- A **Rhythm** mode: phrases with mixed note lengths in keherwa and dadra, then teentaal and rupak. Alankars gain rhythmic forms (for example `S- RG m- PD`).
- Judging follows docs/05 §5: each note's onset against where it should fall, in fractions of a matra (±15% to start), and tempo drift reported as "rushing" or "dragging".
- Ear-first, as with pitch (D31): timing is reported per note and does not fail the round. A **strict rhythm** switch (off by default) makes it count. Hints in the M2 style: "early", "late", "held too short". (The owner left this call to the build; reasons: the owner is a beginner, the ±15% tolerance is a guess until D's fixtures exist, and a verdict that fails on timing too early would bury the pitch feedback.)

Acceptance: the owner can tell from a verdict which note was early or late, and agrees with it.

As built (D53): *Rhythm* is a fifth mode on Home, with a *Lesson* picker (docs/06, Rhythm lessons: six keherwa lessons and two each in dadra, teentaal and rupak (D54), 88 phrases written for Aaroha, the alankars in rhythm among them). It always clicks every matra in the lesson's taal, is always played, and keeps *Tempo*, *How you start* and *Click volume*; phrase length doesn't apply. The player may come in on any sam of their turn: the phrase is timed from the sam that fits. Each verdict adds a line of timing ("In time", "R, P early", "S held too short", "Rushing: you got ahead of the click") and a **timing strip**: the phrase's matras with vibhag marks, the written notes as pale bars, and what was played under them, from where each note started to where it stopped, in the main colour when on time and the in-between colour when not. Timing doesn't fail the round unless *Strict rhythm* is on; an off-time pass gets the in-between icon, as an out-of-tune one does. The summary adds the first tries' notes on time, early and late, and *Your ear* adds a Timing section over the last 200 timed notes, with which way the player leans. Stored attempts keep each note's offset, and the session log keeps the grid, so `fixture_runner session` replays timing too. Timing is judged on the phone speaker only: on headphones or Bluetooth practice says why it isn't. Checked on the Mac: the rhythm judge's unit tests, the lessons' parsing and range, the turn's sams for count-in, free start and retries, and on the ten rhythm fixtures, where steady takes come out 75–100% on time and the drifting ones as rushing, dragging or early throughout. First Rhythm sessions (2026-11-28, sessions 45–53): steady keherwa with a count-in came out mostly on time, but the player often came in on another matra: straight after the call with *When ready*, or a vibhag late. Every note then read several matras early or late, so the entry is now judged on its own (D58).

### Questions for the owner
Answered 2026-11-23: practice is mostly on the phone speaker (C); both count-in and free start (B); rhythm verdicts left to the build, so report-only first (E); the tabla theka moves to M4, and M3 practises to the metronome click.

## M4 — v0.4: depth

- Tabla theka for keherwa, dadra, teentaal and rupak in place of the click (moved from M3, D42). Shipped sounds must be original or public domain (CLAUDE.md rule 9), so they are made by the app or recorded for it.
- Generated raga phrases following each raga's rules.
- Ornaments: kan and meend (notation + contour comparison).
- User-entered tunes/compositions. Built first (D56): *Your tunes*, a sixth mode. You type in a tune (a title and its notation, checked as you type, each line drawn as practice shows it) and practise it line by line, in order, again and again. Lines longer than the phrase level are cut as raga phrases are; lines beyond the flute are left out and marked in the editor. The call plays each line's written timing at the session tempo; pitch is judged. Then timing (D57): a tune with a `taal` line clicks in that taal and is timed as in Rhythm practice, *Strict rhythm* included, and a `start` line puts each line where it begins in the cycle (a mukhda from khali). The call's clicks, the count-in, the beat strip, the cue ("Start on matra 9, in any cycle") and the timing strip's vibhag marks all follow that start. Timed lines are cut at vibhags, never inside a note, so every piece keeps its place. A tune without a taal stays pitch only. Still to do: whole avartans, a different start per line, and shipped public-domain compositions.
- Sampled bansuri voice for the call; better tanpura.

## M5 — Publishing

- iOS audio session work and testing.
- Onboarding, empty states, help.
- Licensing check for every bundled sound and content file. Content is checked already (D55); sounds remain.
- Store listings, privacy statement (no data collected).
- Web build: evaluate whether the C++ core compiles to WebAssembly with acceptable latency.
