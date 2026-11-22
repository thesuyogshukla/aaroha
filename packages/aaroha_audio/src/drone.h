// Synthesized tanpura: four Karplus–Strong strings plucked in the usual
// pattern (first string, Sa, Sa, lower Sa). Realtime-safe: fixed buffers,
// no allocation, no locks.

#ifndef AAROHA_DRONE_H
#define AAROHA_DRONE_H

#include <cstdint>

namespace aaroha {

class Rng {
 public:
  explicit Rng(uint32_t seed = 0x9e3779b9u) : state_(seed) {}
  // Uniform in [-1, 1).
  float bipolar() {
    state_ ^= state_ << 13;
    state_ ^= state_ >> 17;
    state_ ^= state_ << 5;
    return static_cast<float>(state_) / 2147483648.0f - 1.0f;
  }

 private:
  uint32_t state_;
};

class KsString {
 public:
  void tune(double hz, double sample_rate, double t60_seconds);
  void pluck(float amplitude, Rng& rng);
  float tick();

 private:
  static constexpr int kSize = 8192;  // > one period down to ~6 Hz at 48 kHz
  static constexpr int kMask = kSize - 1;
  static constexpr float kBrightness = 0.25f;  // loop filter weight on the previous sample

  float buffer_[kSize] = {};
  int write_ = 0;
  double delay_ = 100;
  float decay_ = 0.99f;
  float previous_ = 0;
};

class Drone {
 public:
  explicit Drone(int sample_rate = 48000);

  // sa_hz is the flute's Sa; the drone sits one octave below.
  // first_string is AR_DRONE_PA / _MA / _NI.
  void configure(double sa_hz, int first_string);
  void set_on(bool on);
  void set_volume(float volume) { volume_ = volume; }

  // Adds the drone into out (mono).
  void render_add(float* out, int64_t n);

 private:
  void retune();
  void pluck_next();

  int sample_rate_;
  double sa_hz_ = 0;
  int first_string_ = 0;
  bool on_ = false;
  float volume_ = 0.5f;
  float gain_ = 0;  // smoothed towards on_ ? volume_ : 0
  int64_t until_next_pluck_ = 0;
  int pattern_index_ = 0;
  KsString strings_[4];
  Rng rng_;
};

}  // namespace aaroha

#endif  // AAROHA_DRONE_H
