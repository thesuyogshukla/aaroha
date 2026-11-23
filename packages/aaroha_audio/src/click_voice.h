// Metronome clicks (docs/08 M3-B): short bursts of band-passed noise, played
// from a schedule in engine time. Noise rather than a tone, so the pitch
// tracker finds no pitch in a click and a click over a held note doesn't
// read as a note. The kind of matra sets brightness, length and level: sam
// is the loudest and brightest, khali soft and dark. Realtime-safe: fixed
// buffers, no allocation, no locks.

#ifndef AAROHA_CLICK_VOICE_H
#define AAROHA_CLICK_VOICE_H

#include <cstdint>

#include "aaroha_audio.h"
#include "drone.h"

namespace aaroha {

class ClickVoice {
 public:
  static constexpr int kMaxClicks = AR_MAX_CLICKS;

  explicit ClickVoice(int sample_rate = 48000) : sample_rate_(sample_rate) {}

  // Replaces the schedule. Clicks must be sorted by time.
  void set_schedule(const ar_click* clicks, int count);
  void stop();

  // Adds the clicks into out (mono). time is the engine frame of out[0].
  void render_add(float* out, int64_t n, int64_t time);

 private:
  void start(const ar_click& click);

  int sample_rate_;
  ar_click clicks_[kMaxClicks] = {};
  int count_ = 0;
  int index_ = 0;

  // The click sounding now.
  bool active_ = false;
  int64_t start_ = 0;
  int64_t length_ = 0;
  int64_t attack_ = 1;
  float gain_ = 0;
  float envelope_ = 0;
  float decay_ = 0;  // per-sample multiplier
  float b0_ = 0, a1_ = 0, a2_ = 0;
  float x1_ = 0, x2_ = 0, y1_ = 0, y2_ = 0;
  Rng rng_{0x6d2b79f5u};
};

}  // namespace aaroha

#endif  // AAROHA_CLICK_VOICE_H
