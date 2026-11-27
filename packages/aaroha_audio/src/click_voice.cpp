#include "click_voice.h"

#include <algorithm>
#include <cmath>
#include <cstring>

namespace aaroha {

namespace {

constexpr double kTwoPi = 6.28318530717958647692;

struct ClickSound {
  double center_hz;  // band-pass centre
  double q;
  double decay_s;    // time constant of the exponential decay
  double length_s;
  double gain;
};

// Indexed by AR_BEAT_*.
constexpr ClickSound kSounds[] = {
    {3200, 1.1, 0.020, 0.080, 1.00},  // sam
    {2600, 1.1, 0.013, 0.060, 0.70},  // tali
    {1400, 0.8, 0.011, 0.050, 0.38},  // khali
    {2200, 1.1, 0.009, 0.045, 0.48},  // plain
};

// A click this late after its time is skipped rather than played late.
constexpr double kLateSeconds = 0.010;

}  // namespace

void ClickVoice::set_schedule(const ar_click* clicks, int count) {
  count_ = std::clamp(count, 0, kMaxClicks);
  if (count_ > 0) std::memcpy(clicks_, clicks, sizeof(ar_click) * count_);
  index_ = 0;
}

void ClickVoice::stop() {
  count_ = 0;
  index_ = 0;
  active_ = false;
}

void ClickVoice::start(const ar_click& click) {
  const ClickSound& s = kSounds[std::clamp(click.beat, 0, 3)];
  const double w0 = kTwoPi * s.center_hz / sample_rate_;
  const double alpha = std::sin(w0) / (2 * s.q);
  const double a0 = 1 + alpha;
  // RBJ band-pass, 0 dB peak gain.
  b0_ = static_cast<float>(alpha / a0);
  a1_ = static_cast<float>(-2 * std::cos(w0) / a0);
  a2_ = static_cast<float>((1 - alpha) / a0);
  x1_ = x2_ = y1_ = y2_ = 0;
  start_ = click.time;
  length_ = static_cast<int64_t>(s.length_s * sample_rate_);
  attack_ = std::max<int64_t>(1, static_cast<int64_t>(0.001 * sample_rate_));
  // Band-passed white noise is quieter than the noise itself. 1.5 puts a
  // full-level sam where a 0.6 sam was before (D54): on the moto g45 that
  // just reaches full scale in its own mic, so no setting can clip it.
  gain_ = static_cast<float>(1.5 * s.gain * std::clamp(click.amplitude, 0.0f, 1.0f));
  envelope_ = 1;
  decay_ = static_cast<float>(std::exp(-1.0 / (s.decay_s * sample_rate_)));
  active_ = true;
}

void ClickVoice::render_add(float* out, int64_t n, int64_t time) {
  const int64_t late = static_cast<int64_t>(kLateSeconds * sample_rate_);
  for (int64_t i = 0; i < n; ++i) {
    const int64_t t = time + i;
    while (index_ < count_ && clicks_[index_].time <= t) {
      if (t - clicks_[index_].time <= late) start(clicks_[index_]);
      ++index_;
    }
    if (!active_) {
      if (index_ >= count_) break;
      continue;
    }
    const int64_t elapsed = t - start_;
    if (elapsed >= length_) {
      active_ = false;
      continue;
    }
    const float x = rng_.bipolar();
    const float y = b0_ * (x - x2_) - a1_ * y1_ - a2_ * y2_;
    x2_ = x1_;
    x1_ = x;
    y2_ = y1_;
    y1_ = y;
    const float ramp = elapsed < attack_ ? static_cast<float>(elapsed) / attack_ : 1.0f;
    out[i] += gain_ * ramp * envelope_ * y;
    envelope_ *= decay_;
  }
}

}  // namespace aaroha
