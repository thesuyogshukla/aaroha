# 07 — Test fixtures

A library of real recordings of the owner's flutes, labelled with what was played. It is the ground truth for the pitch tracker and the evaluator. An agent cannot hear the flute, so these recordings let it check changes on the Mac without a phone or a player.

## How to record

- Use the M0 debug build's **raw recording** button. It records through the same unprocessed mic path the app uses, as 48 kHz mono 32-bit float WAV.
- Pick the take in the dropdown above the button. The app saves `recordings/<flute>/<take>.wav` (adding `-2`, `-3` instead of overwriting) and writes `<take>.yaml` beside it: flute, Sa and whether it was calibrated, drone and filter settings, mic preset, and `played:` for takes with a fixed sequence.
- Calibrate Sa for the flute first; the picker warns if you haven't, or if the drone setting doesn't match the take.
- Pull to the Mac (git ignores `fixtures/raw/`), then move reviewed takes into `fixtures/<flute>/`:
  `adb pull /sdcard/Android/data/app.aaroha.aaroha/files/recordings/. fixtures/raw/`
- `fixture_runner check` reads these labels directly, including the ones still in `fixtures/raw/`.
- Phone where it will sit during riyaz (on a stand, ~0.5–1 m away).
- Quiet room first; a few in normal home noise later.
- Say nothing during takes; put labels in the YAML file instead.

## Session 1 (~30 min): two flutes at the extremes

Start with **G** (largest) and **D#** (smallest). They cover the range of all eight.

Per flute:

| Take | What to play | Purpose |
|---|---|---|
| `silence` | 5 s of nothing | noise floor |
| `sa-hold` | Sa, held 5 s | calibration |
| `scale-slow` | every swar from mandra Pa to taar Pa, including komal/tivra, ~2 s each with a breath between | tracker accuracy across range |
| `taar-holds` | S' R' G' m' P', 3 s each | octave errors on overblown notes |
| `deviations` | Ga, then Ga deliberately flat, then sharp; same for Ni, Re | out-of-tune detection |
| `repeats` | S S S S, then G G G G, tongued; then breath-articulated | repeated-note splitting |
| `phrases` | the 5 phrases in `fixtures/phrases.txt` at ~60 matras/min | phrase segmentation |
| `drone-only` | the app's drone on the phone speaker at normal volume, nothing played, 5 s | drone level in the mic |
| `with-drone` | S R G m P D N S′ slowly with the drone on | drone bleed |
| `ornaments` | a few meends (G~R, P~m) and kans | later; v0.4 |

## Session 2: remaining flutes

A, A#, B, C, C#, D: `silence`, `sa-hold`, `scale-slow`, `with-drone`. About 5 minutes each.

## Files and labels

```
fixtures/
  phrases.txt
  g-medium/
    sa-hold.wav
    sa-hold.yaml
    scale-slow.wav
    scale-slow.yaml
    …
  dsharp-medium/
    …
```

```yaml
# fixtures/g-medium/scale-slow.yaml (written by the app)
take: scale-slow
flute: 'G medium'
recorded: 2026-11-02T18:04:11.000
seconds: 62.4
sa_hz: 385.10
sa_calibrated: true
drone: false
drone_volume: 0.50
drone_first_string: pa
drone_filter: true
input_preset: unprocessed      # as reported by the engine
backend: AAudio
device: '<Android build>'
played: ".P .d .D .n .N S r R g G m M P d D n N S' r' R' g' G' m' M' P'"
notes: ""
```

The app fills `played:` with the notes the take asks for. If you played something different, edit it. For `deviations`, mark the intended direction (`played: "G G(flat) G(sharp)"`); the runner ignores the parentheses, and the size of the deviation comes from the reference tracker.

## Reference pitch

`tools/reference_pitch.py` runs **librosa pYIN** (a well-established offline tracker) on each WAV and writes `<take>.ref.csv` (time, hz, voiced). Generated once and committed. Our tracker is compared against it frame by frame. Where the two disagree a lot, a human listens before deciding which is right.

(Python on the owner's Mac needs the Xcode license accepted first: `sudo xcodebuild -license`. Or use a separately installed Python.)

## Checks the fixture runner performs

| Check | Target |
|---|---|
| Median abs. cents error vs reference, stable voiced frames | < 5 cents |
| Octave error rate (frames off by ~1200 cents) | < 1% |
| Voicing agreement with reference | > 95% |
| `scale-slow`: segmented notes = labelled sequence | exact |
| `deviations`: flat/sharp takes judged out of tune in the right direction | all |
| `repeats`: number of notes | exact |
| `phrases`: phrase judged as pass | all |
| `with-drone`: same results as without drone | all |
| `rhythm-*`: written notes found, onsets against the pitch rise | median ≤ 30 ms, 90% ≤ 100 ms |

The runner prints a table per fixture and exits non-zero on failure.

`selftest` also checks the metronome (D44): clicks alone at 110 a minute must give no notes on any flute, and clicks over the synthetic notes, from 12 dB below the flute's peak to 6 dB above it, must leave every note and its cents unchanged. `clickcheck [dir]` runs `check` again with clicks mixed into the labelled recordings at −6, 0 and +6 dB. Known result: 36 of 39 (rhythm takes skipped). The one difference is the D# `scale-slow` take's overblown madhya Pa, whose tracker confidence already hovers at the threshold; a click there stretches the weak patch past the 150 ms bridge and the note splits (D44).

## Storage

Float WAV at 48 kHz is about 11 MB per minute. Use **Git LFS** for `fixtures/**/*.wav` from the start. Keep takes short.

## Takes cut from sessions

`g-medium/cracked-attacks` joins the listening windows of three tries from practice sessions 33–35 (the label's `source_file` says which). In each, a hard-tongued Pa cracks near taar Re before settling (D48). Cut such takes from the listening window only. Earlier audio holds the end of the app's own call.

## Paused sessions

A session that was paused is recorded in parts: `…-session-N.wav`/`.jsonl`, then `…-session-N-part2…` and so on, one per stretch between pauses, all on the same engine clock. `session`, `export` and `intonation` take the first part's log and read the rest with it, so pull every part.

## Trace previews

`dart run bin/fixture_runner.dart export <session.jsonl> <dir>` (in `tools/fixture_runner`) writes each attempt of a recorded session as JSON: settings, target and the tracker frames heard while listening. `AAROHA_TRACE_IN=<dir> AAROHA_TRACE_OUT=<dir> FLUTTER_ROOT=<flutter> flutter test test/trace_preview_test.dart` (in `app/`) judges them again and draws each session's pitch traces to a PNG sheet with the app's own widget. Useful for changing the trace without a phone.

## Notation previews

`AAROHA_NOTATION_OUT=<file.png> FLUTTER_ROOT=<flutter> flutter test test/notation_preview_test.dart` (in `app/`) draws a sheet of timed phrases with the app's sargam widget: Latin on a light theme beside Devanagari on a dark one, plus verdict colours. Useful for changing how rhythm is drawn without a phone (docs/03, Rendering).

## Rhythm takes (M3-D)

Recorded in Test tools like the other takes, to the metronome, for tuning onset detection (docs/08 M3-D). Five takes, all keherwa, each recorded at **60** and at **90** matras a minute:

| Take | Notation | Checks |
|---|---|---|
| `rhythm-steps` | `S R G m \| P D N S' \|\| S' N D P \| m G R S \|\|` | one swar per matra |
| `rhythm-holds` | `S - R G \| m - - - \|\| P - m G \| R - S - \|\|` | long and short notes |
| `rhythm-halves` | `SR GR S - \| RG mG R - \|\| Gm Pm G - \| RG RS S - \|\|` | two swars in a matra |
| `rhythm-repeats` | `S S S S \| R R R R \|\| G G G G \| S - - - \|\|` | repeated swars, tongued |
| `rhythm-repeats-fast` | `SS SS RR RR \| GG GG S - \|\|` | repeated swars, two to a matra |

How to record one:
- Calibrate Sa in Test tools first (the card at the top), with the drone off. Measure the sound delay once (the *Sound delay* card) if it hasn't been.
- Pick the take and the tempo. *Hear it* plays the phrase on the flute voice over the click, after a count-in.
- *Record with count-in*: four clicks count you in; start on the next click (sam) and play the phrase yourself on the flute, with the click. Only the clicks play while recording: Record stops a *Hear it* still playing, so the app's flute voice can't end up in the take. (The first ten takes, 2026-11-25, held only *Hear it* playback and were set aside.) The metronome runs two matras past the end and recording stops by itself.
- Phone on a stand about 30 cm away, speaker towards you, as for practice. A mistake is fine: say so in the label's `notes`, or record again (a second take is saved as `-2`).

The label adds `rhythm` (the notation), `taal`, `tempo`, `sam_frame` and `click_frames` (sample positions in this WAV where sam and each click were played) and `sound_delay_ms` (the stored speaker delay), plus `count_repeats` for the repeat takes. `dart run bin/fixture_runner.dart rhythm [dir]` reports, for each take, how many notes were found and how far each onset is from where it should be: sam plus its written position at the tempo, plus the sound delay. The self-test prints the same report for synthetic takes as a baseline (a few ms at both tempos). The report also fits a line through the take's onsets, which shows the player's tempo against the click (steady, rushing or dragging) and how far notes stray from that line. It also compares each onset with where energy at the note's own fundamental rises (`pitchRiseOnset`), which the player's timing and the clicks don't affect (D52). A last line gives what Rhythm practice would say about the take (D53): notes on time, early and late, holds short, and drift.

Ten of the owner's takes, one per shape and tempo, are fixtures: `g-medium/rhythm-<take>-<tempo>` (from 2026-11-27). Three of them drifted from the click (steps at 60, holds at 90, fast repeats at 60); their `notes` say so. `check` runs a rhythm take differently from the others: every written note must be found (within 60 c, as rhythm doesn't judge pitch), a repeat take must have no extra notes, and the onsets must agree with the pitch rise, median within 30 ms and 90% within 100 ms. `clickcheck` skips them: they already hold the app's clicks, recorded about 20 dB above the flute.

## Sound delay takes

With *Save session audio* on, each sound delay measurement keeps its recording and what was played as `recordings/delay/delay-<time>.wav` and `.json` on the phone. `dart run bin/fixture_runner.dart delay <json>...` (in `tools/fixture_runner`) measures them again on the Mac and prints each click's delay. The self-test also checks the measurement on the engine's own clicks, delayed through a simulated room with the drone playing.

## Intonation from sessions

`dart run bin/fixture_runner.dart intonation <session.jsonl>... [--csv <file>]` (in `tools/fixture_runner`) judges every recorded attempt again and measures each note played as the right swar. It reports the share within each tolerance (just and equal), where each swar sits and how much it moves, a line per session, and splits by first try, single swar or phrase, and note length. `--csv` writes one row per note. It is how the tolerance defaults were set (decisions.md D41).
