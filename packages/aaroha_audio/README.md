# aaroha_audio

Flutter FFI plugin wrapping Aaroha's native audio core (`src/`): a full-duplex
miniaudio engine that plays the tanpura drone, captures the mic in unprocessed
mode, and runs a YIN pitch tracker on a worker thread.

- C API: [src/aaroha_audio.h](src/aaroha_audio.h)
- Dart API: [lib/aaroha_audio.dart](lib/aaroha_audio.dart)
- Design: [docs/04-architecture.md](../../docs/04-architecture.md)

miniaudio 0.11.25 is vendored in `src/third_party/miniaudio` (public domain / MIT-0).
