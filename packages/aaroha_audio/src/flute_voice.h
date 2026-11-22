// Synthesized flute voice for the app's "call": a near-sinusoidal tone with
// weak harmonics and a little breath noise, played from a schedule of notes
// in engine time. Realtime-safe: fixed buffers, no allocation, no locks.

#ifndef AAROHA_FLUTE_VOICE_H
#define AAROHA_FLUTE_VOICE_H

#include <cstdint>

#include "drone.h"
#include "aaroha_audio.h"

namespace aaroha {

class FluteVoice {
 public:
  static constexpr int kMaxNotes = AR_MAX_SEQUENCE_NOTES;

  explicit FluteVoice(int sample_rate = 48000) : sample_rate_(sample_rate) {}

  // Replaces the schedule. Notes must be sorted by start and not overlap.
  void set_sequence(const ar_note* notes, int count);
  void stop() { count_ = 0; }

  // Adds the voice into out (mono). time is the engine frame of out[0].
  void render_add(float* out, int64_t n, int64_t time);

 private:
  int sample_rate_;
  ar_note notes_[kMaxNotes] = {};
  int count_ = 0;
  int index_ = 0;
  double phase_ = 0;
  float breath_ = 0;
  Rng rng_{0x2545f491u};
};

}  // namespace aaroha

#endif  // AAROHA_FLUTE_VOICE_H
