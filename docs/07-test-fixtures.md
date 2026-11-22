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

The runner prints a table per fixture and exits non-zero on failure.

## Storage

Float WAV at 48 kHz is about 11 MB per minute. Use **Git LFS** for `fixtures/**/*.wav` from the start. Keep takes short.

## Trace previews

`dart run bin/fixture_runner.dart export <session.jsonl> <dir>` (in `tools/fixture_runner`) writes each attempt of a recorded session as JSON: settings, target and the tracker frames heard while listening. `AAROHA_TRACE_IN=<dir> AAROHA_TRACE_OUT=<dir> FLUTTER_ROOT=<flutter> flutter test test/trace_preview_test.dart` (in `app/`) judges them again and draws each session's pitch traces to a PNG sheet with the app's own widget. Useful for changing the trace without a phone.

## Intonation from sessions

`dart run bin/fixture_runner.dart intonation <session.jsonl>... [--csv <file>]` (in `tools/fixture_runner`) judges every recorded attempt again and measures each note played as the right swar. It reports the share within each tolerance (just and equal), where each swar sits and how much it moves, a line per session, and splits by first try, single swar or phrase, and note length. `--csv` writes one row per note. It is how the tolerance defaults were set (decisions.md D41).
