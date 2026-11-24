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

### D35 — Smart drilling as built (2026-11-22)
Stats and target weights use each swar's **last 40 first tries**, pooled across flutes and both answer modes; intonation stays per flute and comes from played attempts only. Weight = (0.15 + (misses + 1) / (tries + 2)) × (1 + min(days unseen / 7, 1)). A pair confused at least twice is drillable; 20% of targets are a contrast drill from the top three pairs in the allowed set. History is read from the database when a session starts and updated live. A *Focus on swars you miss* setting, on by default, gives plain random targets when off.
**Why:** first tries are the honest measure of the ear (later tries have heard the answer). A window rather than all-time lets stats follow progress. Pooling flutes is right for hearing, which is relative to Sa, while intonation depends on each flute's holes. The smoothing (+1/+2) keeps one early miss from dominating; the 0.15 floor keeps a swar you always get right at about a quarter of the share of one you miss half the time, rather than vanishing, so practice still covers the whole set. The week-long recency boost brings back swars left out of recent sessions. Two confusions before a contrast drill avoids drilling a one-off slip, and one target in five keeps drills frequent without turning the session into them. Stored pass/fail flags are not used: stats re-read each note's verdict, so the ear-first rule (D31) applies to old sessions too.

### D36 — Alankars and raga mode as built (2026-11-22)
An alankar round holds whole groups of up to 4 notes, and one walk up and down is the session. Raga phrases longer than 8 notes are split at their breaks. The aaroh and avaroh open a raga session. On a raga, an alankar walks the aaroh's rising swars up and the avaroh's falling swars down. Content stays in the repo's `content/` folder and reaches the app through the `app/content` symlink. The core package uses the pure-Dart `yaml` package to read it. Kafi's pakad is written without Bhatkhande's repeated notes (`S S R R g g m m P`).
**Why:** short rounds keep an alankar call-and-response, like the 2–4-note phrases the end-of-attempt timings were tuned on (D27). A whole 16-note walk in one round would be a memory test, not an ear test. 8 notes is the longest a full aaroh needs; longer pakads keep their musical shape by splitting where the notation already breaks. Taking only the rising (or falling) notes keeps vakra turns from adding the wrong Ni or Ga to a scale. Flutter silently skips assets outside the app folder, and the symlink keeps one copy of the content for the app and the host tests. Repeated notes are still a weak spot of the segmenter (docs/05 §3), so a pakad of repeats would fail for the wrong reason.

### D37 — Notes below the flute's range are dropped (2026-11-22)
The segmenter takes a floor: a semitone below the flute's lowest note (from its profile; mandra Pa on every medium flute). Detected notes below it are dropped. The app, the session replay and the fixture check all apply it. The host WAV reader also reads a recording whose header was never finished, up to the end of the file.
**Why:** in session 28 (raga Bhupali, round 6), S' D P G was played cleanly. 220 ms after the G ended, the drone's low string sounded for 200 ms, about 22 dB below the playing. Its real pitch is under the tracker's search floor (mandra Ma, D17), so the tracker reported it at 646–701 c below Sa, with confidence around 0.9. The note was "faint" but not "unclear", so the D29 rule kept it, and it failed the attempt as an extra note. No flute can play below its lowest note, so the range is a firmer test than level or confidence. Across all 18 recorded sessions this changes exactly that one verdict, and the 12 labelled fixtures are unchanged. Session 17's recording was cut off when the app closed mid-session: its header says 0 bytes, and it now replays 6 of 6.

### D38 — Phrase length grows with the player (2026-11-22)
One phrase level, levels 1–5 (2–4 notes up to 6–8), applies to short phrases, alankar rounds and raga phrases. It moves on first tries of phrase rounds over a sliding window of 10: up at 8 or more right, down at 4 or fewer, starting again after each change. It is kept apart for playing and naming, stored in the settings table, and starts at level 1. Raga phrases too long for the level are cut into pieces that share a note. Alankar groups are spread evenly across rounds.
**Why:** the owner, a beginner, found the 6–8-note raga phrases hard to follow while 2–4 notes were easy to remember and play back. Session 28 points the same way: one of three 7-note phrases was right first time, against three of five 4-note ones. 80% over 10 rounds is the "auto-progress" idea from docs/01, at the phrase level: high enough that the new length starts from mastery, and short enough to move within a session or two. The step down at 40% stops a level that's too hard from turning every round into a miss. Sharing a note between pieces keeps a cut aaroh moving in one line (`S R G P`, `P D S'`) instead of restarting cold. Naming is easier than playing, so it has its own level and can't raise the bar for the flute. The level starts at 1 rather than being worked out from old sessions, because those were played at mixed lengths. The 2–4-note phrases the owner has been playing are level 1 anyway.

### D39 — Pitch trace as built (2026-11-22)
The trace draws the segmenter's cleaned cents, not raw tracker frames. It is coloured by each note's verdict, against labelled target lanes with tolerance bands and a faint semitone grid. Its range covers the targets and judged notes, padded by 60 c and at least 400 c; stray frames outside the range are dropped. It shows only after a played attempt's verdict, only while the target may be shown, and it isn't stored. In the test tools, the live pitch widget is renamed `LivePitchTrace` to keep the names apart.
**Why:** previews from the owner's sessions 23–28 drove each choice. Raw frames showed tracker octave slips as cracks that weren't there. Ranging over every voiced frame let a drone tail or breath before the first note squash the lanes into a strip, with a long grey line to the edge. A plain lane±60 c range made a single swar's ±10 c wobble fill the height, and its 50 c tolerance band filled most of the picture. Labelled lanes name the target's swars, so the trace follows the "show the target" rules and stays hidden when the verdict is a hint or nothing. The semitone grid gives a wrong note's distance without naming it.

### D40 — Recordings survive a killed app (2026-11-22)
The native WAV writer rewrites the header's sizes and flushes the file about once a second of audio, not only when recording stops. The session log is written line by line straight to the file, not through a buffered stream.
**Why:** session 17 was cut off when the app closed mid-session. Its header still said 0 bytes, and its last log lines were never written. The host reader learned to read such a file to the end (D37), but other tools reject it. Once a second costs one small seek and write on the worker thread and loses at most a second of audio. A session writes a few log lines per round, so writing each one directly costs nothing noticeable and keeps the log complete up to the moment the app dies.

### D41 — Tolerance defaults kept, from the owner's sessions (2026-11-23)
The pitch tolerance stays at ±25 c by default, with ±35 and ±15 as the other choices. Just intonation stays the default reference. `fixture_runner intonation` measures every right-swar note in the recorded sessions, so this can be checked again as more sessions come in.
**Why:** across 281 right-swar notes from 16 sessions (4–28, G medium), the share within each tolerance was:

| | ±10 | ±15 | ±20 | ±25 | ±30 | ±35 |
|---|---|---|---|---|---|---|
| Just intonation | 49% | 70% | 84% | 91% | 95% | 98% |
| Equal temperament | 47% | 65% | 74% | 85% | 93% | 96% |

±25 passes nine notes in ten, and on S, R, P and D (the steadiest swars) 96%. What it flags is not scatter but steady habits: Ni about 15 c flat, taar Sa often 15–30 c flat, Ga about 14 c sharp of just (close to equal temperament), and in the early sessions a sharp Ma. Those are worth hearing about. ±35 flags only 6 notes in 281, so as a default it would say almost nothing. ±15 flags 30%, and 17% even on the steady swars, so it is a stretch goal, not a default. Shifts in the whole session (a cold flute, the day's Sa) add only a little: removing each session's offset from its Sa and Pa moves ±25 from 91% to 93%. Within a note the pitch holds within about ±3–7 c, so the tracker is not the limit. In phrases, only 61% of attempts had every note within ±25, so with strict intonation off (D31) the tolerance marks notes without failing rounds. Just intonation fits 6 points better than equal at ±25, mainly on Dha and Ni.

### D42 — M3 scope and order (2026-11-23)
M3 is, in order: **A** timed phrases end to end (the call plays written durations at a tempo; the display shows holds, matra arcs and vibhag bars; timing not judged); **B** a metronome with taal accents, and a choice of count-in or free start; **C** latency calibration, phone speaker first, rhythm judging off on Bluetooth; **D** onset detection and repeated-swar splitting, tuned on new labelled fixtures; **E** a Rhythm mode with timing reported per note, not failing the round unless *strict rhythm* is on. The tabla theka moves to M4. Details in docs/08.
**Why:** the notation parser already reads durations, so the first gap is carrying them through practice, which mostly can be built and checked on the Mac. The count-in and the latency measurement come before judging, because judging needs a known downbeat and a known delay. The owner practises on the phone speaker, so it is calibrated first. Timing is report-only at first for the same ear-first reason as pitch (D31): the owner is a beginner, and the ±15% tolerance is a guess until D's fixtures exist. The owner chose both start options. Tabla recordings from elsewhere can't ship (rule 9); the owner chose to practise to the click in M3 rather than delay it for app-made or commissioned tabla sounds.

### D43 — Timed phrases as built (M3-A, 2026-11-23)
A round's target is a `Phrase` with its timing, not a list of swars: drills carry one, the call plays its notes, holds and rests, and the stored round and session log keep it as printed notation. Material without durations becomes one matra per note (`evenPhrase`), and a phrase in that shape draws exactly as before. The call's tempo is a session setting, 75 matras a minute by default, with 50, 60, 90 and 110 offered; a phrase's own `tempo:` header is not used, as docs/02 says the session setting wins. Single swars keep their 1.6 s note. Pieces cut from a long phrase keep their timing: joined parts carry on where the last ended; a piece that starts inside a matra keeps its place in it, padded with a rest; bars are dropped from pieces, since a piece is not a whole avartan. Rests show as a faint `_`, distinct from the Latin hold `-`.
**Why:** 75 a minute is the 0.8 s per note every phrase had before, so existing practice is unchanged unless the player changes the tempo. Storing printed notation keeps old rounds readable (their text is the same) and lets history and the host tools parse timed targets with the same parser. Keeping a piece's place in its matra keeps the rhythm as written. Bhatkhande marks rests with `-` in some books, but the app's Latin script already uses `-` for a hold (docs/03), so a rest needs another sign. The underscore matches the ASCII notation.

### D44 — Metronome and count-in as built (M3-B, 2026-11-23)
Clicks are short bursts of band-passed noise from a click voice in the native engine, scheduled in engine frames like the call. The kind of matra sets brightness, length and level: sam loudest and brightest, tali a little softer, khali soft and dark, other matras short and plain. Rupak's sam is played as khali, since its first vibhag is khali. A count-in is the taal's last vibhag leading into sam, at least 3 matras, or 4 without a taal. Counted in, the call and the player's turn each start on their own sam; with a free start (*When ready*), the metronome's cycle carries on from the call. All of it is off by default, and single swars and naming never click.
**Why:** a pitched click (a woodblock tone) could be tracked as a note or bend a held one; noise has no period for YIN to find. The self-test confirms it on every flute: clicks alone give no voiced frames at all, and clicks up to 6 dB above the flute's peak leave all 25 synthetic notes per flute and their cents (within 1.2 c) unchanged. A low thump for sam was rejected: a phone speaker barely plays it. A count-in to a new sam for the turn keeps the wait short (a whole teentaal cycle could be 13 s) and gives judging a known downbeat. One known case: on the D# `scale-slow` fixture, the overblown madhya Pa's confidence already sits just under the tracker's threshold, and a click there stretches the weak patch past the 150 ms bridge, so the note splits in two. Masking the frames under each click didn't help, because the weak patch outlasts the click. The segmenter isn't loosened for this one note; D's metronome fixtures will show whether it matters in practice.

### D45 — Sound delay measured with clicks (M3-C, 2026-11-23)
The round trip from a scheduled sound to the mic is measured with 6 metronome clicks, a second apart, recorded with the drone silenced and found in the recording from their onsets: the first rise in energy above 1 kHz that is 15 dB over the 50 ms before it and reaches within 20 dB of the loudest moment. The delay most clicks agree on (within 3 ms) is kept, if at least 5 of 6 are heard and agree within 5 ms. It is stored per output; only the phone speaker is measured. A device opened just for the measurement gets 0.8 s to settle first.
**Why:** a click's onset is sharp, so it can be timed to a fraction of a millisecond, where the call's pitch echo (D28) is only as fine as the tracker's 10 ms frames and its start time. The recording's first sample is stamped with the engine frame, so the delay is on the same clock as rhythm judging will use. A second between clicks keeps each click's window clear of the next at delays up to 900 ms. Two rules came from the first runs on the moto g45. First, the first click after opening the device came 4 ms late, hence the settling time. Second, a soft room sound 30 dB below a click, starting 7 ms before it, was taken for the click's onset. Hence the rule that an onset must be nearly as loud as the clicks. With both, three runs gave 422.8, 422.8 and 422.7 ms. Headphones are not measured, because the mic can't hear clicks played into them. Bluetooth is not measured, because its delay is long and changes from connection to connection.

### D46 — Rhythm takes for onset tuning (M3-D, 2026-11-24)
Five rhythm takes in keherwa, each recorded at 60 and 90 matras a minute: steps (one swar a matra), holds, halves (two swars in a matra), repeats and fast repeats. They are recorded in Test tools to the metronome after a four-click count-in, and recording stops by itself two matras after the phrase. The label stores the click and sam positions as sample offsets in the WAV (from `ar_record_first_frame`) and the stored sound delay, so a note's expected onset is exact: sam + written position at the tempo + delay.
**Why:** the shapes cover what rhythm judging must handle: plain steps, holds that must not split, subdivisions, and repeated swars, the known weak spot (docs/05 §3), at two tempos. Keherwa is the most common taal and starts on a clear sam (not rupak's khali). The phrases stay in a beginner's comfortable range (madhya Sa to taar Sa). Storing positions inside the WAV, rather than engine times, keeps each fixture self-contained for the host. A synthetic baseline shows the present segmenter already places clean onsets within a few milliseconds, so the real takes, with their breath and tonguing, will show what the onset detector has to fix.

### D47 — Pause and resume in practice (2026-11-24)
A *Pause* button beside *End* stops the call, clicks, drone and mic. It works from the call, listening, answering and the verdict, the same as the app going to the background. *Resume* plays the round's call again. If the round was already passed or given up, it moves on to the next round instead. Pausing does not count as an attempt. The session recording continues in a new part (`…-part2.wav`/`.jsonl`), and the host tools read all parts.
**Why:** the owner sometimes has to stop mid-session, and *End* was the only way out. After a break the player has lost the call, so carrying on into a listening window would give a miss nobody earned. Replaying is what the player would ask for anyway. Turning the mic and drone off makes a pause truly quiet, and it reuses the background path that already existed.

### D48 — Cracked attacks pass, and are pointed out (2026-11-24)
A run under 250 ms, a fifth (702 ± 50 c) above the note it runs into with no re-articulation, is that note's attack cracking into the next mode of its fingering. It becomes part of the note, which records the crack (`DetectedNote.crack`). The verdict passes the note, adds "attack cracked upward" and uses the in-between colour. The `phrases` fixture's label no longer lists its 200 ms crack from Ma into Pa as a played taar Re. A new fixture, `g-medium/cracked-attacks`, holds three such tries from sessions 33–35.
**Why:** in the owner's sessions 33–35, a hard-tongued Pa failed three tries as "extra taar Re". The spectrum shows the flute really sounded it: the 875 Hz partial, the third mode of the all-closed fingering, ran 16–20 dB above Pa for 180–230 ms. So this is a playing flaw, not a tracker error. The owner chose to have it judged as the right note but mentioned (asked 2026-11-24), the ear-first view (D31): a listener hears Pa with a cracked start, not two notes. The octave-flip rule (D22) stays silent because its flips are often two modes sounding together, which the tracker reads an octave down. The cracks here are clean and long enough to hear. The fifth and its tolerance come from the three cracks (measured 679–690 c above the settled Pa) and the earlier `phrases` one. 250 ms covers the longest seen (230 ms) and stays under the shortest notes the app asks for (333 ms, two to a matra at 90). Replaying ~300 recorded verdicts (sessions 4–36) changed exactly those three tries. Cracks downward, or from first-mode notes to their twelfth, haven't been seen and aren't handled.

## Open questions

- **Medium-flute octave convention:** assumed Sa in the 4th–5th octave (docs/02). Calibration will confirm.
- **Drone bleed:** measured on the moto g45 at drone volume 0.5: the drone reaches the mic about 13 dB below the flute, and the current drone filter handles it (fixtures `drone-only`, `with-drone`). Recheck if the owner practises with the drone much louder, or on another phone.
- **Call loudness and end-of-attempt timings:** confirmed by the owner's first sessions (2026-11-20): phrase calls at 0.8 s per note felt fine to follow, and every phrase was judged 0.6 s after the last note with none cut off. Revisit for longer phrases (M2).
- **Rhythm judging strictness:** onset/duration tolerances are guesses until M3 fixtures exist (D42: report-only until then).
- **Raga versions:** which gharana's version of each starter raga to ship. Drafts are in `content/ragas/` (M2-D), awaiting the owner's review. Least certain: Durga's vadi, and the Khamaj and Des pakads.
