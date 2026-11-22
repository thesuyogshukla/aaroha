// Minimal 32-bit float mono WAV writer (WAVE_FORMAT_IEEE_FLOAT with a fact
// chunk). Not realtime-safe: used from the analysis worker only.

#ifndef AAROHA_WAV_WRITER_H
#define AAROHA_WAV_WRITER_H

#include <cstdint>
#include <cstdio>

namespace aaroha {

class WavWriter {
 public:
  ~WavWriter() { close(); }

  bool open(const char* path, int sample_rate) {
    close();
    file_ = std::fopen(path, "wb");
    if (!file_) return false;
    sample_rate_ = sample_rate;
    frames_ = 0;
    write_header();
    return true;
  }

  bool is_open() const { return file_ != nullptr; }
  int64_t frames() const { return frames_; }

  void write(const float* samples, int64_t n) {
    if (!file_) return;
    frames_ += static_cast<int64_t>(std::fwrite(samples, sizeof(float), n, file_));
  }

  // Patches the header sizes and closes. Returns frames written.
  int64_t close() {
    if (!file_) return 0;
    std::fseek(file_, 0, SEEK_SET);
    write_header();
    std::fclose(file_);
    file_ = nullptr;
    return frames_;
  }

 private:
  void u32(uint32_t v) { std::fwrite(&v, 4, 1, file_); }
  void u16(uint16_t v) { std::fwrite(&v, 2, 1, file_); }

  void write_header() {
    const uint32_t data_bytes = static_cast<uint32_t>(frames_ * 4);
    std::fwrite("RIFF", 1, 4, file_);
    u32(4 + (8 + 18) + (8 + 4) + (8 + data_bytes));
    std::fwrite("WAVE", 1, 4, file_);
    std::fwrite("fmt ", 1, 4, file_);
    u32(18);
    u16(3);  // IEEE float
    u16(1);  // mono
    u32(static_cast<uint32_t>(sample_rate_));
    u32(static_cast<uint32_t>(sample_rate_ * 4));
    u16(4);   // block align
    u16(32);  // bits per sample
    u16(0);   // cbSize
    std::fwrite("fact", 1, 4, file_);
    u32(4);
    u32(static_cast<uint32_t>(frames_));
    std::fwrite("data", 1, 4, file_);
    u32(data_bytes);
  }

  std::FILE* file_ = nullptr;
  int sample_rate_ = 48000;
  int64_t frames_ = 0;
};

}  // namespace aaroha

#endif  // AAROHA_WAV_WRITER_H
