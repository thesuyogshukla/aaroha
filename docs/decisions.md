# Decisions

Each entry: what was decided, and why. Newest at the bottom. Change a decision by adding a new entry that supersedes the old one, not by editing history.

### D1 — Flutter app with a native C++ audio core (2026-10-25)
Flutter for UI, state and storage; a C++ core called through dart:ffi for playback, capture, pitch tracking and the clock.
**Why:** the hard part of this app is low-latency audio with raw mic access and one shared clock for playback and capture. That part is native in every option (Kotlin+Oboe, KMP, React Native), so switching away from Flutter would not remove it. Flutter covers Android and iOS UI from one codebase, and the owner knows it well, which helps when reviewing agent-written code.

### D2 — miniaudio for the native core (2026-10-25)
**Why:** single header, permissive license, backends for Android (AAudio/OpenSL), iOS/macOS (Core Audio) and web (Emscripten). One codebase runs on the phone, on the Mac for development and fixture tests, and possibly in the browser later. Oboe would be Android-only.

### D3 — Everything musical is relative to Sa (2026-10-25)
Content, evaluation and stats use swars and cents from Sa; Hz only at the audio boundary and in calibration.
**Why:** this is how Hindustani music is heard and taught, and it makes all content work on every flute with no changes.

### D4 — No per-hole correction in flute profiles (2026-10-25)
**Why:** correcting for a flute's slightly-off holes would hide intonation errors the player needs to hear about. Per-flute intonation is reported as stats instead.

### D5 — Drone on by default, one octave below Sa (2026-10-25)
**Why:** identifying a swar means hearing it against Sa. Without a drone the exercise becomes absolute-pitch training, a different and much harder skill. One octave down is the usual tanpura register for a medium flute and keeps drone energy mostly below the flute's range.

### D6 — First-try accuracy is the headline metric (2026-10-25)
**Why:** retries are allowed and useful, but ear progress means getting it right without hunting.

### D7 — ASCII Bhatkhande-style notation as the content format (2026-10-25)
See docs/03.
**Why:** the owner reads Bhatkhande sargam; plain text is easy to type, diff, review and generate; a single format serves content files, user tunes and tests.

### D8 — Android first, iOS after the app is solid (2026-10-25)
**Why:** the owner's primary device. iOS needs its own audio session work, deferred to M5.

### D9 — Equal temperament as the default tuning for v0.1 (2026-10-25) — superseded by D31
**Why:** differences from just intonation (12–16 cents on a few swars) fit inside the ±25 cent default tolerance, and ET is simplest to reason about. Revisit once fixtures show where the owner's flutes actually sit.

### D10 — Turn-taking: the app plays, then listens (2026-10-25)
**Why:** avoids the mic picking up the app's own call, without needing echo cancellation (which would damage the flute signal). Matches how call-and-response teaching works.

### D11 — YIN first; tracker choice decided by fixtures (2026-10-25)
**Why:** YIN is simple, well documented and suits the near-sinusoidal bansuri tone. McLeod (MPM) can be added behind the same interface; whichever does better on the fixture suite wins.

### D12 — Riverpod for state, drift for storage (2026-10-25)
**Why:** both are mainstream and well supported; drift gives typed SQL for the attempt history the stats are built on.

### D13 — Synthesized sounds in v0.1 (2026-10-25)
Flute voice and tanpura are synthesized in the C++ core.
**Why:** no licensing questions, perfectly in tune, sample-accurate scheduling. Sampled sounds come later (M4).

### D14 — Offline and private (2026-10-25)
**Why:** riyaz needs no network, and recordings of someone's practice are personal. Audio never leaves the device; no analytics or accounts in v0.x.

### D15 — Only public-domain or original content is shipped (2026-10-25)
**Why:** melodies of film songs and modern compositions can be copyrighted. Users can enter those themselves; they stay on their device.

### D16 — Real recordings are the ground truth (2026-10-25)
Labelled fixtures plus a librosa pYIN reference; WAVs in Git LFS.
**Why:** the agent building the app cannot hear the flute. Fixtures make pitch and evaluation changes measurable and repeatable on the host.

### D17 — Drone rejection: search floor + high-pass; drone checks informational until measured (2026-10-25)
The tracker's lowest searched pitch is two semitones below the flute's mandra Pa, and the analysis is high-passed at 0.7× mandra Pa. The segmenter bridges loud unvoiced stretches up to 150 ms.
**Why:** the synthetic self-test (`fixture_runner selftest`) showed:
- Without a drone, the tracker finds every note from .P to P' on all 8 flutes, with deviations accurate to ≤ 1.2 cents.
- With the drone mixed in, the tracker locked onto the drone's own strings (.S, ..P) in gaps and sometimes mid-note. The high-pass alone barely helped, because the drone's Sa is only just below the cutoff and its harmonics fall inside the flute's range.
- Limiting the search range removed most lock-ons. Bridging loud gaps stopped drone plucks splitting notes. At −12 dB drone-to-flute, all 200 notes are found, with 0–1 extra per flute and a mean error of ~1–1.5 cents.
- At −6 dB and louder, a single-pitch tracker degrades: 20% of frames lost at −6 dB, 40% at 0 dB, errors up to ~10–20 cents.

The real speaker-to-mic level on the owner's phone is unknown, so the drone cases are reported, not required. Once measured (M0 device test), pick from, in order of effort: wired earphones (no bleed); lower the drone or duck it during the listen window; cancel the drone using the exact signal the engine played as a reference (adaptive filter), which works because the engine generates the drone sample-accurately.

### D18 — JDK 17 for Gradle, via the app's gradle.properties (2026-10-25)
`org.gradle.java.home` points at the Homebrew openjdk@17.
**Why:** Gradle 8.14 (the Flutter template's) can't run on Android Studio's bundled Java 25. This matches the owner's drelogbook project. The path is machine-specific; on another machine, change or remove that line.

### D19 — permission_handler pinned to 12.x (2026-10-25)
**Why:** 13.x pulls in permission_handler_android 14, whose Gradle script needs a newer Android Gradle Plugin than Flutter 3.38's template (AGP 8.11). Revisit when the template's AGP moves up.

### D20 — Android-only plugin for now (2026-10-25)
`aaroha_audio` and `app` declare only the Android platform.
**Why:** Android first (D8). iOS and macOS need podspec/build glue for the C++ core; add them when the macOS dev target or iOS work starts. The Mac host build (`tools/build_native_host.sh`) covers testing the core meanwhile.

### D21 — Segmenter tuned on the first real recordings (2026-10-25)
Re-articulation dips must be ≥ 16 dB (was 8 dB) relative to the last 300 ms and must recover; dip frames are the note's tail; short runs that wobble > ±20 cents are transitions. Details in docs/05.
**Why:** the owner's first G-flute takes showed a steady breath pulse of 10–12 dB at 2–3 Hz. The 8 dB rule split one held S′ into four notes, an 11.6 s Sa hold into five, and long Ga/Ma notes into several. Tail frames that sagged in pitch also became phantom 120 ms notes. With the new rules, those takes segment into the notes actually played, and the overblown taar Ga (26.9 s) and the brief taar Re before Pa (48.6 s), both confirmed real from the spectrum, are still reported. The synthetic self-test is unchanged. Tongued repeats are covered only by a synthetic −18 dB test until `repeats` fixtures exist.

### D22 — Octave checks in the tracker and the segmenter (2026-10-30)
The tracker prefers half the chosen lag when the normalised difference there is below 0.35. The segmenter absorbs octave flips under 200 ms into the touching note on the same swar.
**Why:** at the start of a Pa in the moto g45 `phrases` take, the flute sounded 585 and 877 Hz at equal strength for ~100 ms. Their common period is 293 Hz, so YIN reported mandra Pa for 150 ms. That is acoustically defensible but musically wrong, because the player hears a cracked Pa. The tracker check alone didn't catch that case (the half lag was above 0.35), but it cut gross errors with the drone mixed in from ~1.4% to 0–0.3%. The segmenter rule handles the remaining short flips. Longer ones (a 320 ms overblow) are real mistakes and still reported. The synthetic self-test and all real fixtures pass.

### D23 — Calibration asks for a relaxed Sa and a check each session (2026-10-30)
**Why:** on 2026-10-30 the owner's G flute calibrated at 391.4 Hz and later 393.4 Hz. In the phrases take, played Sa sat 7–39 c below the calibrated value. A flute's pitch rises with breath pressure, so a strong calibration breath makes every later note read flat. The calibrator now starts counting when the note begins, reports an unsteady hold (spread over ±20 c), and asks for a normal riyaz breath. Home suggests a quick "Check Sa" before each session. Measuring Sa from the session itself is a possible later improvement.

### D24 — Fixture labels record what was actually played (2026-10-30)
`played:` is the sequence verified as played (analysis plus a spectrum check where needed); `intended:` keeps what the take asked for; `notes:` explains the difference. `check` collapses back-to-back identical notes unless `count_repeats: true`, and skips `fixtures/raw/`.
**Why:** a learner's takes don't match their intent (sharp shuddha Ma, flat komal Ni), and that is the point of the app. A label of the intent would make the suite fail forever. The fixtures are therefore a regression suite: when a change alters a reading, a person decides whether the label or the change is wrong. Collapsing repeats keeps a long note that splits in two from counting as a mismatch, matching how phrases are judged.

### D25 — One shared AudioService; mic off outside practice (2026-10-30)
**Why:** the phone runs one full-duplex stream at a time, so calibration, practice and the test tools share one engine instead of each owning one. The mic is stopped when calibration closes or a session ends (D14), and when practice goes to the background.

### D26 — v0.1 practice targets are random within the chosen set (2026-10-30)
Single swars never repeat back to back; phrases are 2–4 notes moving one or two places along the allowed pitches.
**Why:** enough for daily use now. Adaptive picking from the player's confusions (docs/05 §8) needs history, which v0.1 starts collecting, so it moves to v0.2 as planned.

### D27 — The listening window and end-of-attempt timings (2026-10-30)
Defaults in docs/05 ("Ending an attempt"): listen from 250 ms after the call (superseded by D28); a single note is judged after 500 ms of quiet or 1.5 s of holding; a phrase after 600 ms of quiet once enough notes are in. The call plays single swars for 1.6 s and phrase notes for 0.8 s.
**Why:** a starting point that keeps rounds quick. To be tuned from the owner's first real sessions.

### D28 — Listen after the call's measured round trip (2026-11-20)
The listening window opens at call end + measured round trip + 150 ms. The round trip is measured from each call's own echo (first tracker frame at the call's pitch) and kept as a running median, saved per device.
**Why:** the owner's first practice session on the moto g45 (session 4, 20 rounds, 35 verdicts) showed the call reaching the mic 421–481 ms after it was scheduled (median 431 ms), and its tail lasting ~420 ms past its end. With the old 250 ms margin, every attempt started with ~180 ms of the app's own call, perfectly in tune. Single-swar verdicts happened to ignore it (under 300 ms), but in phrase mode it would be an extra first note. Replaying all 20 first tries with the new window removes the echo and changes no verdict. The player never started sooner than 1.0 s after the call's end (median 1.3 s), so the later start costs nothing. Measuring from the calls themselves needs no calibration step and adapts to other phones and to Bluetooth.

### D29 — Faint, unclear notes are breaths (2026-11-20)
In attempts with more than one note, a note more than ~16.5 dB below the attempt's typical level *and* with median confidence under 0.9 is dropped.
**Why:** in the first phrase session (session 6, round 2), a barely sounded Pa between Ni and Ga was read as mandra Pa. The spectrum had nothing at mandra Pa (−47 dB) and a faint madhya Pa; the note was ~19 dB down with confidence 0.87. So the app said "wrong octave" where the truth was "Pa barely played". Level alone wasn't enough: 20 dB missed this case, and 16.5 dB alone dropped soft notes with clear pitch (confidence ≥ 0.89) in another attempt. Requiring both faint and unclear changes exactly that one verdict across all 72 practice verdicts (sessions 4–6), to "Pa missing". One fixture label changed: in the G `scale-slow`, the 350 ms "komal Dha" was a fading slide off Pa (20+ dB down, confidence 0.7–0.88), not a sounded note. All other fixtures are unchanged.

### D30 — The app is renamed Aaroha (2026-11-22)
Everything that named the app is now Aaroha: the app title and launcher label, the Android application id (`app.aaroha.aaroha`), the Dart packages (`aaroha_core`, `aaroha_audio`, app package `aaroha`), the C++ namespace and header (`aaroha::`, `aaroha_audio.h`), the C API prefix (`ar_` / `AR_`, Dart structs `Ar…`), the database file, and the docs. The raga term *pakad* (a raga's signature phrase) is unchanged wherever it means the musical idea.
**Why:** the owner's choice of name, made before the first commit. Consequences: a new application id makes Android treat it as a new app, so the old "Pakad" install keeps its own data (flutes, calibrations, history) until it is removed. Its recordings on the phone were already pulled to `fixtures/raw/`. On-phone recordings now go under `/sdcard/Android/data/app.aaroha.aaroha/files/recordings/`.

### D31 — Ear first: the right swar passes; just intonation by default (2026-11-22)
By default a right swar passes the attempt even when out of tune (cents still shown and tracked); a **Strict intonation** setting brings back failing it. Calls and judging use a **Tuning** setting, just intonation by default (supersedes D9).
**Why:** on 2026-11-22 the owner got stuck on a Ni round (sessions 8–10). The app's call was exact (heard back within 0.2 c), but the owner's G-flute Ni sat at a fixed 726–732 Hz on every try, 26–37 c below equal-tempered Ni. That was outside ±25 c, so every try failed, though the ear had found the right swar. Recalibrating Sa couldn't help (it moves the target, not the flute's note); one sharp calibration (399.2 Hz) even pushed Ni into komal Ni. Across sessions 4–10, the owner's swars compared with each tuning: Dha −12 c ET vs +4 c just, Ni −26 c ET vs −15 c just, Re +12 vs +8, Ga +4 vs +17, Sa/Ma/Pa within 4 c either way. Just intonation fits Dha and Ni (and the tanpura) better, though not Ga. Rejudging sessions 8 and 10 with the new defaults passes every real Ni attempt (now 15–24 c below just Ni), while the attempt where taar Sa was played still fails. An ear-training app shouldn't stop the player on a note their ear got right; intonation remains visible in each verdict and in the stats. Stored attempts keep the pass/fail they were judged with, so earlier sessions' summaries don't change.

### D32 — M2 scope and order (2026-11-22)
M2 is, in order: **A** hands-free practice (auto-retry countdown, replay-before-retry, give-up rule, *show the target* and *after a miss, show* settings with direction-and-size hints); **B** Listen & name, an ear-only mode with swar buttons and an octave switch only when needed; **C** smart drilling (confusion grid, adaptive targets); **D** alankars and raga mode for 8 starter ragas; **E** a pitch trace on the verdict, never live. Details in docs/08.
**Why:** from the owner after the first weeks of real practice. Retrying meant taking a hand off the flute; a revealed answer ends the ear's search, while a hint ("a little low", "too high") keeps it going. Naming notes isolates the ear and allows about three times the repetitions of playing back, anywhere and without a mic. It moves up from v0.4 because it serves the app's core purpose. Hands-free comes first as the quickest win for every session; drilling comes before raga material so the material arrives with adaptive practice already in place. The pitch trace is shown only after an attempt, because seeing pitch live would turn ear training into tuner reading.

### D33 — Hands-free practice as built (2026-11-22)
"Show the target" has three options, not the four in the D32 plan: *always*, *when the round ends*, *never*. "After a pass" and "after giving up" both meant the round had ended. A miss with "show: the answer" reveals the target too, matching the old "after attempt", and old saved settings carry over (shown → always, after attempt → when the round ends, hidden → never). Defaults keep today's behaviour: wait for the player, show the answer, replay before an automatic retry, give up after 3 misses. After a pass the next round starts in 1.5 s; after giving up, in 4 s, to take in the answer. A wrong swar within 250 c (a whole tone and a little) is "too" low or high; further is "much too".
**Why:** simpler choices with the same reach, and the owner's current sessions behave exactly as before until they change a setting.

### D34 — Listen & name as built (2026-11-22)
Naming runs the engine **playback only** (new `ar_engine_set_capture`, ABI 3): the drone and the flute voice play, the mic is never opened and no permission is asked. Each tapped swar is judged as an exactly played note (`judgeNamed`), so hints, the octave rule, give-up and stats work unchanged. The keypad is live from the start of the call. After a miss, a tap starts the next try, with no countdown; the call replays first only with "retry by itself" + "replay before retrying". *Hear Sa* takes the *Try again* slot. Rounds advance 1 s after a pass (1.5 s when playing).
**Why:** the point of the mode is many quick repetitions anywhere, so nothing should slow a tap down, and a countdown only helps when both hands are on a flute. A playback-only device keeps the "no mic" promise true at the OS level, not just in the UI.

## Open questions

- **Tolerance defaults by level:** ±35 / ±25 / ±15 cents is a guess; tune after a week of use.
- **Medium-flute octave convention:** assumed Sa in the 4th–5th octave (docs/02). Calibration will confirm.
- **Drone bleed:** measured on the moto g45 at drone volume 0.5: the drone reaches the mic about 13 dB below the flute, and the current drone filter handles it (fixtures `drone-only`, `with-drone`). Recheck if the owner practises with the drone much louder, or on another phone.
- **Call loudness and end-of-attempt timings:** confirmed by the owner's first sessions (2026-11-20): phrase calls at 0.8 s per note felt fine to follow, and every phrase was judged 0.6 s after the last note with none cut off. Revisit for longer phrases (M2).
- **Rhythm judging strictness:** onset/duration tolerances are guesses until M3 fixtures exist.
- **Raga versions:** which gharana's version of each starter raga to ship (owner to review).
