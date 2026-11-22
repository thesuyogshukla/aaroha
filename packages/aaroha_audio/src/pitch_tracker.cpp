#include "pitch_tracker.h"

#include <algorithm>
#include <cmath>
#include <cstring>

namespace aaroha {

namespace {
constexpr double kPi = 3.14159265358979323846;
constexpr double kButterworthQ = 0.70710678118654752440;

// Octave check: if the normalised difference at half the chosen lag is below
// this, the heard pitch is the octave above. A flute note with an extra
// partial (e.g. 585 + 877 Hz while a note cracks) repeats only every 1/292 s,
// so YIN finds the sub-octave; a true low note, with its strong fundamental,
// stays far above this at half its period (decisions.md D22).
constexpr float kOctaveCheckThreshold = 0.35f;
}  // namespace

void Biquad::set_highpass(double cutoff_hz, double sample_rate) {
  if (cutoff_hz <= 0 || cutoff_hz >= sample_rate / 2) {
    bypass();
    return;
  }
  const double w0 = 2.0 * kPi * cutoff_hz / sample_rate;
  const double cosw = std::cos(w0);
  const double alpha = std::sin(w0) / (2.0 * kButterworthQ);
  const double a0 = 1.0 + alpha;
  b0_ = (1.0 + cosw) / 2.0 / a0;
  b1_ = -(1.0 + cosw) / a0;
  b2_ = (1.0 + cosw) / 2.0 / a0;
  a1_ = -2.0 * cosw / a0;
  a2_ = (1.0 - alpha) / a0;
  bypass_ = false;
  reset();
}

void Biquad::bypass() {
  bypass_ = true;
  reset();
}

void PitchTracker::configure(const ar_tracker_config& config, int sample_rate) {
  config_ = config;
  sample_rate_ = sample_rate;
  window_ = std::max(64, config.window);
  hop_ = std::clamp(config.hop, 1, window_);
  tau_min_ = std::max(2, static_cast<int>(std::floor(sample_rate / config.max_hz)));
  // The lag search needs at least half the window left for integration.
  tau_max_ = std::min(window_ / 2,
                      static_cast<int>(std::ceil(sample_rate / config.min_hz)));
  buffer_.assign(window_, 0.0f);
  diff_.assign(tau_max_ + 2, 0.0f);
  highpass_.set_highpass(config.highpass_hz, sample_rate);
  reset(0);
}

void PitchTracker::reset(int64_t start_time) {
  filled_ = 0;
  buffer_start_time_ = start_time;
  highpass_.reset();
}

void PitchTracker::shift() {
  std::memmove(buffer_.data(), buffer_.data() + hop_,
               sizeof(float) * (window_ - hop_));
  filled_ -= hop_;
  buffer_start_time_ += hop_;
}

ar_pitch_frame PitchTracker::analyze() {
  ar_pitch_frame frame{};
  frame.time = buffer_start_time_ + window_ / 2;

  const float* b = buffer_.data();
  double energy = 0;
  for (int i = 0; i < window_; ++i) energy += static_cast<double>(b[i]) * b[i];
  frame.rms = static_cast<float>(std::sqrt(energy / window_));
  if (frame.rms < 1e-6f) return frame;

  // Difference function over a fixed integration length.
  const int integration = window_ - tau_max_;
  for (int tau = 1; tau <= tau_max_; ++tau) {
    double sum = 0;
    for (int j = 0; j < integration; ++j) {
      const double d = b[j] - b[j + tau];
      sum += d * d;
    }
    diff_[tau] = static_cast<float>(sum);
  }

  // Cumulative mean normalised difference, in place.
  diff_[0] = 1.0f;
  double running = 0;
  for (int tau = 1; tau <= tau_max_; ++tau) {
    running += diff_[tau];
    diff_[tau] = running > 0 ? static_cast<float>(diff_[tau] * tau / running) : 1.0f;
  }

  // First dip below the threshold, followed down to its local minimum.
  int tau = -1;
  for (int t = tau_min_; t <= tau_max_; ++t) {
    if (diff_[t] < config_.threshold) {
      while (t + 1 <= tau_max_ && diff_[t + 1] < diff_[t]) ++t;
      tau = t;
      break;
    }
  }
  if (tau < 0) {
    const float best = *std::min_element(diff_.begin() + tau_min_,
                                         diff_.begin() + tau_max_ + 1);
    frame.confidence = std::clamp(1.0f - best, 0.0f, 1.0f);
    return frame;
  }

  const int half = tau / 2;
  if (half - 2 >= tau_min_) {
    int best = half;
    for (int t = half - 2; t <= half + 2; ++t) {
      if (diff_[t] < diff_[best]) best = t;
    }
    if (diff_[best] < kOctaveCheckThreshold) tau = best;
  }

  double shift = 0;
  if (tau > 1 && tau < tau_max_) {
    const double a = diff_[tau - 1], c = diff_[tau], e = diff_[tau + 1];
    const double denom = a - 2 * c + e;
    if (denom != 0) shift = std::clamp(0.5 * (a - e) / denom, -1.0, 1.0);
  }
  frame.hz = static_cast<float>(sample_rate_ / (tau + shift));
  frame.confidence = std::clamp(1.0f - diff_[tau], 0.0f, 1.0f);
  return frame;
}

}  // namespace aaroha
