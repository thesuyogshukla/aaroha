# 04 — Architecture

## Overview

```
┌──────────────────────────── Flutter app (app/) ────────────────────────────┐
│  UI (screens)  ←→  Riverpod state  ←→  Session controller (state machine)  │
│                                          │             │                   │
│                         drift (SQLite) ←─┘             │                   │
└──────────────────────────────────────────┬─────────────┼───────────────────┘
                                           │             │
               ┌───────────────────────────▼──┐   ┌──────▼───────────────────┐
               │ aaroha_core (pure Dart)       │   │ aaroha_audio (FFI plugin) │
               │  music model, notation,      │   │  Dart bindings           │
               │  evaluator, content,         │   │        │ dart:ffi        │
               │  generators, stats           │   │  ┌─────▼──────────────┐  │
               └──────────────────────────────┘   │  │ C++ audio core     │  │
                                                  │  │ miniaudio engine   │  │
                                                  │  │ synth · capture ·  │  │
                                                  │  │ pitch tracker      │  │
                                                  │  └────────────────────┘  │
                                                  └──────────────────────────┘
```

- **C++ audio core** does everything time-critical: playback, capture, pitch tracking, and the shared clock.
- **aaroha_core** does all the musical reasoning in pure Dart, testable on the host.
- **app** is UI, state, persistence and wiring.

## Repository layout

```
aaroha/
  app/                         Flutter app
  packages/
    aaroha_core/                pure Dart package
      lib/src/model/           Swar, Pitch, Phrase, Tuning, FluteProfile
      lib/src/notation/        parser, printer, renderer data
      lib/src/eval/            segmentation, judging, alignment, rhythm
      lib/src/content/         loaders, alankar generator, raga generator
      lib/src/stats/           confusion, intonation, adaptive picker
      test/
    aaroha_audio/               Flutter FFI plugin (template: plugin_ffi)
      src/                     C++ core + vendored miniaudio.h
      lib/                     Dart bindings + PitchFrame stream wrapper
      android/ ios/ macos/     build glue (CMake / podspec)
  tools/
    fixture_runner/            Dart CLI: runs core + native tracker over fixtures/
    reference_pitch.py         librosa pYIN reference for cross-checking
  fixtures/                    labelled WAVs (see 07)
  content/                     ragas, alankars, compositions (see 06)
  docs/
```

## C++ audio core

### Library choice: miniaudio

Single-header, public domain / MIT-0. Backends: AAudio and OpenSL ES (Android), Core Audio (iOS/macOS), Web Audio (via Emscripten). One codebase covers the phone, the Mac for development and tests, and possibly web later. See decisions.md D2.

### Engine

One full-duplex `ma_device` (playback + capture) at **48 kHz, mono**, low-latency performance profile. `ar_engine_set_capture(engine, 0)` before start opens a **playback-only** device instead (`AR_PRESET_NONE`): no capture, no pitch frames, no mic permission. Listen & name uses it.

- **Android input preset: `Unprocessed`**, falling back to `VoiceRecognition` where unprocessed is not supported. Both avoid echo cancellation and noise suppression, which damage a flute tone. Log which preset was actually used.
- **iOS (later):** `AVAudioSession` category `playAndRecord`, mode `measurement` (disables voice processing), default-to-speaker.
- Request RECORD_AUDIO permission from Dart before starting the engine.

### Clock

Engine time = number of frames processed since the engine started (int64). Every captured block, every pitch frame and every scheduled sound uses engine time. Dart reads the current engine time through FFI. Playback and capture share one device callback, so their clocks cannot drift apart.

The remaining unknown is the fixed delay between "sample written to output" and "same sound arrives in the input buffer" (output + input latency). Measured once per device/route by a loopback test (play clicks, detect them in the mic) and stored. Only rhythm scoring (v0.3) needs it.

### Threads

| Thread | Does | Rules |
|---|---|---|
| Audio callback | mixes voices into output; copies input into a capture ring buffer | no alloc, no locks, no logging |
| Analysis worker | reads capture ring, runs pitch tracker, writes PitchFrames into an output ring | may allocate at start only |
| Dart isolate (UI) | polls the PitchFrame ring ~60×/s via FFI, sends commands | — |

Dart **polls** rather than receiving callbacks: simpler and avoids calling into Dart from native threads.

### Synthesis (in the callback)

- **Flute voice (v0.1, `flute_voice.cpp`):** sine fundamental + 2nd/3rd harmonics (0.22, 0.07) + breath noise, 40 ms attack and 60 ms release (shorter for short notes), no vibrato so the call is a clean reference. Meend glides exponentially over the second half of a note. Dart sends whole schedules (up to 128 `ar_note`s in engine frames) through a lock-free queue; the callback swaps them in. `ar_render_notes` renders offline, and the self-test checks the voice reads back within 2 c on every flute.
- **Drone (v0.1):** synthesized plucked strings (Karplus–Strong with a buzzy bridge approximation), pattern per docs/02.
- **Click/metronome (v0.3)**, **tabla theka (v0.4, D42)**: sounds made by the app or recorded for it (CLAUDE.md rule 9).
- Sounds are scheduled at an engine time, so a phrase plays sample-accurately, which the rhythm judging relies on.

### Pitch tracker

- **YIN** with parabolic interpolation; window 1024 samples (21 ms), hop 480 (10 ms → 100 frames/s); default search range 150–2500 Hz, threshold 0.15.
- Output per frame: `PitchFrame { int64 time; float hz; float confidence; float rms; }`. `time` is the engine frame at the **centre** of the analysis window. `hz = 0` when unvoiced.
- **Drone rejection** (the app's "drone filter", decisions.md D17): the search floor is set to two semitones below the flute's mandra Pa, and the analysis is high-passed at 0.7× mandra Pa. All drone strings sit below that floor, so drone-only audio has no period in range.
- McLeod (MPM) can be added behind the same interface and compared on the fixtures. Choice is driven by fixture results (D11).
- An **offline entry point** `ar_analyze(samples, n, sampleRate, config, outFrames)` runs the same tracker on a buffer. Used by the fixture runner on the Mac.

### C API (sketch)

```c
ar_engine*  ar_engine_create(const ar_config*);
int         ar_engine_start(ar_engine*);
void        ar_engine_stop(ar_engine*);
void        ar_engine_destroy(ar_engine*);
int64_t     ar_engine_time(ar_engine*);              // frames
int         ar_engine_input_preset(ar_engine*);      // which preset actually applied

void        ar_drone_set(ar_engine*, double saHz, int firstString, float volume, int on);
int         ar_play_sequence(ar_engine*, const ar_note* notes, int count);  // absolute engine frames
void        ar_stop_playback(ar_engine*);

void        ar_capture_enable(ar_engine*, int on);    // turn-taking gate
int         ar_read_pitch_frames(ar_engine*, ar_pitch_frame* out, int max);
int         ar_record_start(ar_engine*, const char* wavPath);   // raw fixture recording
void        ar_record_stop(ar_engine*);

int         ar_analyze(const float* samples, int n, int sampleRate,
                       const ar_tracker_config*, ar_pitch_frame* out, int max);
```

Recordings are written by the analysis worker, never the callback. The WAV header's sizes are rewritten about once a second, so a recording cut off by a killed app is still a valid file missing at most its last second (D40).

## aaroha_core (Dart)

- **model:** `Swar`, `Saptak`, `Pitch`, `Tuning` (table-driven), `FluteProfile`, `Note`, `Phrase`.
- **notation:** parser + printer + render model (docs/03).
- **eval:** turns `List<PitchFrame>` + target `Phrase` + settings into an `AttemptResult` (docs/05). Pure function; easy to test with fixture frames.
- **content:** loads `content/` files; alankar generator; raga phrase generator (v0.4).
- **stats:** confusion matrix, per-flute intonation, adaptive target picker.

## App

### Session controller

```
idle → (calibrate?) → ready
ready → countIn → calling → listening → judging → verdict
verdict → retry → calling        (replay call, attempt++)
verdict → retryNoCall → listening
verdict → next → countIn         (or → summary when rounds done)
```

- **Turn-taking:** capture is gated off while the app is calling, and back on after the call plus a short tail (~150 ms). Frames are tagged with engine time anyway, so the evaluator can ignore anything before the listen window opens.
- **Listen window ends** when: enough notes have been heard for the target and the player has stopped (silence > 600 ms), or a timeout (target duration × 2 + 3 s).

### Persistence (drift)

| Table | Contents |
|---|---|
| `flutes` | FluteProfile rows |
| `sessions` | id, flute, mode, settings snapshot (JSON), start/end |
| `rounds` | id, session, target notation, source |
| `attempts` | id, round, attempt number, result (JSON), first-try flag, duration |
| `settings` | key/value |

Stats are computed from `attempts`; aggregates can be cached later if needed.

## Development workflow

- The plugin and app currently target **Android only**. A Flutter **macOS desktop** target could run the same C++ core with the Mac's mic; it needs a podspec for the plugin and is not set up yet.
- `tools/build_native_host.sh` builds the core as a Mac dylib. The fixture runner loads it through its own small FFI binding (it is a plain Dart CLI, so it can't depend on the Flutter plugin); struct sizes and the ABI version are checked at load time on both sides.
- The fixture runner (`tools/fixture_runner`) is the main verification step for any change to pitch tracking or evaluation. `selftest` needs no recordings: it synthesizes flute-like notes across every flute's range, with and without the drone mixed in.
