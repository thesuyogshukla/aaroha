#include "drone.h"

#include <cmath>

#include "aaroha_audio.h"

namespace aaroha {

namespace {

// Ratio of each first-string choice to the drone's Sa (all in the octave below).
double first_string_ratio(int first_string) {
  switch (first_string) {
    case AR_DRONE_MA: return std::pow(2.0, -700.0 / 1200.0);  // mandra Ma
    case AR_DRONE_NI: return std::pow(2.0, -100.0 / 1200.0);  // mandra Ni
    default: return std::pow(2.0, -500.0 / 1200.0);           // mandra Pa
  }
}

constexpr float kPluckAmplitude[4] = {0.8f, 0.7f, 0.7f, 0.9f};
constexpr double kPluckGapSeconds[4] = {1.1, 1.1, 1.1, 1.6};
constexpr double kT60Seconds = 3.5;

}  // namespace

void KsString::tune(double hz, double sample_rate, double t60_seconds) {
  if (hz <= 0) return;
  // The loop filter adds kBrightness samples of delay.
  delay_ = sample_rate / hz - kBrightness;
  if (delay_ > kSize - 4) delay_ = kSize - 4;
  if (delay_ < 2) delay_ = 2;
  decay_ = static_cast<float>(std::exp(std::log(0.001) / (t60_seconds * hz)));
}

void KsString::pluck(float amplitude, Rng& rng) {
  const int length = static_cast<int>(delay_) + 2;
  float smoothed = 0;
  for (int i = 0; i < length; ++i) {
    smoothed += 0.6f * (rng.bipolar() - smoothed);
    buffer_[(write_ - 1 - i) & kMask] = amplitude * smoothed;
  }
}

float KsString::tick() {
  const double read = write_ - delay_;
  const int i0 = static_cast<int>(std::floor(read));
  const float frac = static_cast<float>(read - i0);
  const float a = buffer_[i0 & kMask];
  const float b = buffer_[(i0 + 1) & kMask];
  const float out = a + frac * (b - a);
  buffer_[write_ & kMask] =
      decay_ * ((1.0f - kBrightness) * out + kBrightness * previous_);
  previous_ = out;
  write_ = (write_ + 1) & kMask;
  return out;
}

Drone::Drone(int sample_rate) : sample_rate_(sample_rate) {}

void Drone::configure(double sa_hz, int first_string) {
  if (sa_hz == sa_hz_ && first_string == first_string_) return;
  sa_hz_ = sa_hz;
  first_string_ = first_string;
  retune();
}

void Drone::set_on(bool on) {
  if (on && !on_) {
    pattern_index_ = 0;
    until_next_pluck_ = 0;
  }
  on_ = on;
}

void Drone::retune() {
  const double drone_sa = sa_hz_ / 2.0;
  strings_[0].tune(drone_sa * first_string_ratio(first_string_), sample_rate_, kT60Seconds);
  strings_[1].tune(drone_sa, sample_rate_, kT60Seconds);
  strings_[2].tune(drone_sa, sample_rate_, kT60Seconds);
  strings_[3].tune(drone_sa / 2.0, sample_rate_, kT60Seconds);
}

void Drone::pluck_next() {
  strings_[pattern_index_].pluck(kPluckAmplitude[pattern_index_], rng_);
  // ±6% timing variation so the drone doesn't sound mechanical.
  const double gap = kPluckGapSeconds[pattern_index_] * (1.0 + 0.06 * rng_.bipolar());
  until_next_pluck_ = static_cast<int64_t>(gap * sample_rate_);
  pattern_index_ = (pattern_index_ + 1) % 4;
}

void Drone::render_add(float* out, int64_t n) {
  if (sa_hz_ <= 0) return;
  const float target = on_ ? volume_ : 0.0f;
  if (target == 0.0f && gain_ < 1e-5f) {
    gain_ = 0;
    return;
  }
  for (int64_t i = 0; i < n; ++i) {
    if (on_ && until_next_pluck_-- <= 0) pluck_next();
    gain_ += (target - gain_) * 0.0005f;  // ~40 ms fade at 48 kHz
    const float mix = strings_[0].tick() + strings_[1].tick() + strings_[2].tick() +
                      strings_[3].tick();
    out[i] += 0.25f * gain_ * mix;
  }
}

}  // namespace aaroha
