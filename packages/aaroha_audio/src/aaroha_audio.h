// Aaroha native audio core: C API used from Dart through dart:ffi.
//
// One full-duplex engine plays the drone and captures the mic on a single
// clock. Engine time is the number of frames processed since the engine
// started. A worker thread runs the pitch tracker on captured audio and
// queues pitch frames for Dart to poll. See docs/04-architecture.md.

#ifndef AAROHA_AUDIO_H
#define AAROHA_AUDIO_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#if defined(_WIN32)
#define AR_API __declspec(dllexport)
#else
#define AR_API __attribute__((visibility("default"))) __attribute__((used))
#endif

// Bumped whenever a struct layout or function signature changes.
#define AR_ABI_VERSION 5

#define AR_MAX_SEQUENCE_NOTES 128
#define AR_MAX_CLICKS 256

typedef struct ar_engine ar_engine;

typedef struct {
  int64_t time;      // engine frame at the centre of the analysis window
  float hz;          // 0 when unvoiced
  float confidence;  // 1 - YIN aperiodicity at the chosen lag, 0..1
  float rms;         // of the high-passed analysis window
  float reserved;
} ar_pitch_frame;

typedef struct {
  float min_hz;       // lowest pitch searched
  float max_hz;       // highest pitch searched
  float threshold;    // YIN absolute threshold on the normalised difference
  float highpass_hz;  // <= 0 disables the analysis high-pass
  int32_t window;     // analysis window in samples
  int32_t hop;        // samples between frames
} ar_tracker_config;

// One note of the flute voice, in engine frames.
typedef struct {
  int64_t start;
  int64_t duration;
  double hz;
  double glide_to_hz;  // > 0: meend into this pitch over the note's second half
  float amplitude;     // 0..1
  float reserved;
} ar_note;

// A metronome click (docs/08 M3-B): how its matra is marked in the taal.
enum {
  AR_BEAT_SAM = 0,
  AR_BEAT_TALI = 1,
  AR_BEAT_KHALI = 2,
  AR_BEAT_PLAIN = 3,
};

typedef struct {
  int64_t time;     // engine frame
  int32_t beat;     // AR_BEAT_*
  float amplitude;  // 0..1
} ar_click;

enum {
  AR_PRESET_UNPROCESSED = 0,
  AR_PRESET_VOICE_RECOGNITION = 1,
  AR_PRESET_DEFAULT = 2,
  AR_PRESET_NONE = 3,  // playback only: the mic is not opened
};

enum {
  AR_DRONE_PA = 0,
  AR_DRONE_MA = 1,
  AR_DRONE_NI = 2,
};

typedef struct {
  int32_t sample_rate;
  int32_t input_preset;      // AR_PRESET_* that the device opened with
  int32_t running;
  int32_t recording;
  int64_t capture_overruns;  // capture blocks dropped (analysis worker behind)
  int64_t pitch_overruns;    // pitch frames dropped (Dart not polling)
  char backend[32];
} ar_engine_info;

AR_API int32_t ar_abi_version(void);
AR_API int32_t ar_sizeof_pitch_frame(void);
AR_API int32_t ar_sizeof_tracker_config(void);
AR_API int32_t ar_sizeof_engine_info(void);
AR_API int32_t ar_sizeof_note(void);
AR_API int32_t ar_sizeof_click(void);
AR_API void ar_tracker_default_config(ar_tracker_config* out);

AR_API ar_engine* ar_engine_create(int32_t sample_rate);
// Returns 0 on success, a negative miniaudio result code on failure.
AR_API int32_t ar_engine_start(ar_engine* engine);
// Whether the next start opens the mic (default on). Off gives a playback-
// only device: no capture, no pitch frames, no mic permission needed.
AR_API void ar_engine_set_capture(ar_engine* engine, int32_t on);
AR_API void ar_engine_stop(ar_engine* engine);
AR_API void ar_engine_destroy(ar_engine* engine);
AR_API int64_t ar_engine_time(ar_engine* engine);
AR_API void ar_engine_get_info(ar_engine* engine, ar_engine_info* out);

// sa_hz is the flute's Sa; the drone plays one octave below it.
AR_API void ar_drone_set(ar_engine* engine, double sa_hz, int32_t first_string,
                         float volume, int32_t on);
AR_API void ar_tracker_set(ar_engine* engine, const ar_tracker_config* config);

// Schedules the flute voice. Note times are absolute engine frames, sorted,
// not overlapping; replaces anything already scheduled. Returns 0, or -1 if
// there are more than AR_MAX_SEQUENCE_NOTES notes or the command queue is full.
AR_API int32_t ar_play_sequence(ar_engine* engine, const ar_note* notes, int32_t count);
AR_API void ar_stop_playback(ar_engine* engine);

// Schedules metronome clicks, like ar_play_sequence: absolute engine frames,
// sorted; replaces anything scheduled. Returns 0, or -1 if there are more
// than AR_MAX_CLICKS clicks or the command queue is full.
AR_API int32_t ar_play_clicks(ar_engine* engine, const ar_click* clicks, int32_t count);
AR_API void ar_stop_clicks(ar_engine* engine);
// Turn-taking gate: while off, captured audio is discarded.
AR_API void ar_capture_enable(ar_engine* engine, int32_t on);
// Pops up to max queued frames into out; returns how many were written.
AR_API int32_t ar_read_pitch_frames(ar_engine* engine, ar_pitch_frame* out,
                                    int32_t max);

// Records the raw (unfiltered) capture stream as 32-bit float mono WAV.
// Returns 0 on success, -1 if the file can't be opened or already recording.
AR_API int32_t ar_record_start(ar_engine* engine, const char* wav_path);
// Returns the number of frames written.
AR_API int64_t ar_record_stop(ar_engine* engine);
// The engine frame of the current (or last) recording's first sample, or -1
// before any audio was written. Lines a recording up with scheduled sounds.
AR_API int64_t ar_record_first_frame(ar_engine* engine);

// Offline: runs the same tracker over a buffer. Frame times are sample
// indices. Returns the number of frames written to out (at most max).
AR_API int32_t ar_analyze(const float* samples, int64_t n, int32_t sample_rate,
                          const ar_tracker_config* config, ar_pitch_frame* out,
                          int32_t max);

// Offline: renders the flute voice for notes timed from frame 0.
AR_API void ar_render_notes(const ar_note* notes, int32_t count, int32_t sample_rate,
                            float* out, int64_t n);

// Offline: renders clicks timed from frame 0.
AR_API void ar_render_clicks(const ar_click* clicks, int32_t count, int32_t sample_rate,
                             float* out, int64_t n);

// Offline: renders n samples of drone, as the engine would play it.
AR_API void ar_render_drone(double sa_hz, int32_t first_string, float volume,
                            int32_t sample_rate, float* out, int64_t n);

#ifdef __cplusplus
}
#endif

#endif  // AAROHA_AUDIO_H
