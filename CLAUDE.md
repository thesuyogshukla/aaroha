# CLAUDE.md

Guide for coding agents working on Aaroha. Read this first, then the spec doc for the area you are touching.

## What this is

A Flutter app (Android first) for bansuri ear training. It plays notes/phrases over a tanpura drone, listens to the player's flute through the mic, and judges the attempt. See [README.md](README.md) for the doc index.

The owner is a bansuri player and an experienced Flutter developer who builds through agents rather than by hand. They own medium flutes in A, A#, B, C, C#, D, D# and G.

## Layout (planned, see docs/04-architecture.md)

```
app/                 Flutter app (UI, state, storage)
packages/
  aaroha_core/        Pure Dart: music model, notation parser, evaluator, content, generators
  aaroha_audio/       Flutter FFI plugin: C++ audio core (miniaudio) + Dart bindings
tools/               Host-side CLIs: fixture runner, reference pitch script
fixtures/            Labelled flute recordings (see docs/07-test-fixtures.md)
content/             Raga definitions, alankars, compositions (data files)
docs/                Specs
```

## Rules

1. **Specs are the source of truth.** Before changing behaviour, read the relevant doc. If the change alters behaviour described there, update the doc in the same change.
2. **Record decisions.** Any non-obvious choice (library, algorithm, threshold default, format change) gets an entry in [docs/decisions.md](docs/decisions.md) with the reason.
3. **Everything musical is relative to Sa.** Content, evaluation and stats work in swars and cents from Sa. Hz appears only at the audio boundary and in flute calibration.
4. **`aaroha_core` is pure Dart.** No Flutter imports, no platform code. It must run under `dart test` on the host.
5. **Realtime audio rules (C++ core).** No allocation, locks, logging or file I/O inside the audio callback. Communicate with lock-free ring buffers. Pitch analysis runs on a worker thread, not in the callback.
6. **One clock.** Playback and capture share the native engine's clock. Every pitch frame and every scheduled sound carries an engine timestamp. Do not use Dart wall-clock time for anything musical.
7. **Verify against fixtures, not by ear.** Changes to the pitch tracker or evaluator must pass the fixture suite (`tools/` runner) on the host. Do not loosen fixture expectations to make a change pass without recording why in decisions.md.
8. **Privacy.** Audio never leaves the device. No analytics, no accounts in v0.x.
9. **Shipped content must be public domain or original.** Film songs and other copyrighted tunes are only ever user-entered. See docs/06-content.md.

## Verifying work

- Core tests: `cd packages/aaroha_core && dart test`
- Native core for the Mac: `tools/build_native_host.sh` (uses the Android SDK's CMake/Ninja if none on PATH)
- Tracker + segmenter self-test on synthetic flute notes: `cd tools/fixture_runner && dart run bin/fixture_runner.dart selftest`
- Labelled recordings: `dart run bin/fixture_runner.dart check` (and `analyze <wav> --flute "G medium" [--highpass]` for one take)
- Analyze: `flutter analyze` in `app/` and `packages/aaroha_audio/`, `dart analyze` elsewhere. Formatter width is 100.
- App tests: `cd app && flutter test`
- After changing `app/lib/data/database.dart`: `cd app && dart run build_runner build --force-jit` (the default AOT build of the builders fails on this Mac)
- App: `cd app && flutter build apk --debug`, or `flutter run` with the phone connected (the owner's main test phone is a moto g45 5G, Android 15, from 2026-10-30; a motorola edge 20 fusion, Android 13, is a secondary device; earlier work used a moto g(9), Android 11). Check `adb devices` for which phone is connected before installing.

After changing anything in `packages/aaroha_audio/src/`, rebuild the host library before running the fixture runner.

## App structure (`app/lib`)

- `audio/` — `AudioService` (the one native engine, shared by every screen) and `SaCalibrator`
- `data/` — drift database (flutes, sessions, rounds, attempts, settings) and Riverpod providers
- `home/` — home screen (flute, practice options, Start) and history
- `flutes/` — flute profiles and the calibration sheet
- `practice/` — practice settings, the round loop (`PracticeController`), practice screen, session summary
- `debug/` — M0 test tools: live pitch readout and fixture recording
- `widgets/` — sargam rendering

The mic is on only during calibration, flute practice and the test tools. Listen & name runs the engine playback only (no mic).

## Conventions

- State management: Riverpod. Local database: drift (SQLite).
- Notation strings in code and content use the ASCII format in docs/03-notation.md.
- Cents are doubles; frequencies are doubles in Hz; engine time is int64 frames (samples) from engine start, converted to seconds only for display.
