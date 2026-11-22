#include "flute_voice.h"

#include <algorithm>
#include <cmath>
#include <cstring>

namespace aaroha {

namespace {
constexpr double kTwoPi = 6.28318530717958647692;
constexpr double kAttackSeconds = 0.04;
constexpr double kReleaseSeconds = 0.06;
}  // namespace

void FluteVoice::set_sequence(const ar_note* notes, int count) {
  count_ = std::clamp(count, 0, kMaxNotes);
  std::memcpy(notes_, notes, sizeof(ar_note) * count_);
  index_ = 0;
  phase_ = 0;
}

void FluteVoice::render_add(float* out, int64_t n, int64_t time) {
  for (int64_t i = 0; i < n && index_ < count_; ++i) {
    const int64_t t = time + i;
    while (index_ < count_ && t >= notes_[index_].start + notes_[index_].duration) {
      ++index_;
      phase_ = 0;
    }
    if (index_ >= count_) break;
    const ar_note& note = notes_[index_];
    if (t < note.start) continue;

    const double elapsed = static_cast<double>(t - note.start) / sample_rate_;
    const double remaining = static_cast<double>(note.start + note.duration - t) / sample_rate_;
    const double length = static_cast<double>(note.duration) / sample_rate_;
    // Short notes get proportionally shorter attack and release.
    const double attack = std::min(kAttackSeconds, 0.25 * length);
    const double release = std::min(kReleaseSeconds, 0.25 * length);
    const double envelope = std::min(1.0, elapsed / attack) * std::min(1.0, remaining / release);

    // Meend: glide exponentially over the second half of the note.
    double hz = note.hz;
    if (note.glide_to_hz > 0) {
      const double progress = std::clamp((elapsed / length - 0.5) * 2.0, 0.0, 1.0);
      hz = note.hz * std::pow(note.glide_to_hz / note.hz, progress);
    }
    phase_ += kTwoPi * hz / sample_rate_;
    if (phase_ > kTwoPi) phase_ -= kTwoPi;

    breath_ += 0.3f * (rng_.bipolar() - breath_);
    const double tone =
        std::sin(phase_) + 0.22 * std::sin(2 * phase_) + 0.07 * std::sin(3 * phase_);
    out[i] += static_cast<float>(note.amplitude * envelope * (0.8 * tone + 0.06 * breath_));
  }
}

}  // namespace aaroha
