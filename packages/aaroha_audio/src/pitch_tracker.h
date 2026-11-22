// Streaming YIN pitch tracker with an optional analysis high-pass.

#ifndef AAROHA_PITCH_TRACKER_H
#define AAROHA_PITCH_TRACKER_H

#include <cstdint>
#include <vector>

#include "aaroha_audio.h"

namespace aaroha {

// RBJ second-order high-pass (Butterworth Q).
class Biquad {
 public:
  void set_highpass(double cutoff_hz, double sample_rate);
  void bypass();
  void reset() { z1_ = z2_ = 0.0; }
  float process(float x) {
    if (bypass_) return x;
    const double y = b0_ * x + z1_;
    z1_ = b1_ * x - a1_ * y + z2_;
    z2_ = b2_ * x - a2_ * y;
    return static_cast<float>(y);
  }

 private:
  bool bypass_ = true;
  double b0_ = 1, b1_ = 0, b2_ = 0, a1_ = 0, a2_ = 0;
  double z1_ = 0, z2_ = 0;
};

class PitchTracker {
 public:
  // Allocates; call off the audio thread.
  void configure(const ar_tracker_config& config, int sample_rate);
  // Clears buffered audio and filter state. start_time is the timestamp of
  // the next sample passed to process().
  void reset(int64_t start_time);

  // Feeds samples; calls emit(const ar_pitch_frame&) once per hop.
  template <typename Emit>
  void process(const float* x, int64_t n, Emit&& emit) {
    for (int64_t i = 0; i < n; ++i) {
      buffer_[filled_++] = highpass_.process(x[i]);
      if (filled_ == window_) {
        emit(analyze());
        shift();
      }
    }
  }

 private:
  ar_pitch_frame analyze();
  void shift();

  ar_tracker_config config_{};
  int sample_rate_ = 48000;
  int window_ = 1024;
  int hop_ = 480;
  int tau_min_ = 2;
  int tau_max_ = 320;
  int filled_ = 0;
  int64_t buffer_start_time_ = 0;
  Biquad highpass_;
  std::vector<float> buffer_;
  std::vector<float> diff_;
};

}  // namespace aaroha

#endif  // AAROHA_PITCH_TRACKER_H
