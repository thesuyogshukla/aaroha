// Engine: one full-duplex miniaudio device, the drone, and the analysis
// worker. Threads:
//   audio callback  - renders the drone, copies captured audio into
//                     capture_ring (no allocation, no locks)
//   analysis worker - drains capture_ring, records WAV, runs the pitch
//                     tracker, fills pitch_ring
//   Dart            - polls pitch_ring, sets parameters through atomics

#include <algorithm>
#include <atomic>
#include <chrono>
#include <cstring>
#include <mutex>
#include <new>
#include <thread>

#include "click_voice.h"
#include "drone.h"
#include "flute_voice.h"
#include "aaroha_audio.h"
#include "pitch_tracker.h"
#include "spsc_ring.h"
#include "third_party/miniaudio/miniaudio.h"
#include "wav_writer.h"

namespace {

using aaroha::SpscRing;

constexpr int kBlockFrames = 1024;

// A whole schedule for the flute voice; count < 0 means stop.
struct SequenceCommand {
  int32_t count;
  ar_note notes[AR_MAX_SEQUENCE_NOTES];
};

// A whole click schedule; count < 0 means stop.
struct ClickCommand {
  int32_t count;
  ar_click clicks[AR_MAX_CLICKS];
};

struct CaptureBlock {
  int64_t time;  // engine frame of samples[0]
  int32_t frames;
  float samples[kBlockFrames];
};

}  // namespace

struct ar_engine {
  explicit ar_engine(int rate) : sample_rate(rate), drone(rate), voice(rate), clicks(rate) {
    ar_tracker_default_config(&tracker_config);
  }

  int sample_rate;
  ma_device device{};
  bool device_ready = false;
  bool capture_device = true;  // open the mic on the next start
  int input_preset = AR_PRESET_DEFAULT;

  std::atomic<int64_t> frames{0};
  std::atomic<bool> capture_on{true};
  std::atomic<int64_t> capture_overruns{0};
  std::atomic<int64_t> pitch_overruns{0};

  // Drone parameters, written by Dart and applied in the callback.
  std::atomic<double> drone_sa{0};
  std::atomic<int> drone_first_string{AR_DRONE_PA};
  std::atomic<float> drone_volume{0.5f};
  std::atomic<bool> drone_on{false};
  aaroha::Drone drone;

  // Flute voice schedules, written by Dart and picked up in the callback.
  SpscRing<SequenceCommand, 4> sequence_ring;
  aaroha::FluteVoice voice;

  // Metronome click schedules, likewise.
  SpscRing<ClickCommand, 4> click_ring;
  aaroha::ClickVoice clicks;

  SpscRing<CaptureBlock, 256> capture_ring;    // ~5 s at 48 kHz
  SpscRing<ar_pitch_frame, 4096> pitch_ring;   // ~40 s at 100 frames/s

  std::thread worker;
  std::atomic<bool> worker_running{false};

  std::mutex tracker_mutex;
  ar_tracker_config tracker_config{};
  bool tracker_dirty = true;

  std::mutex record_mutex;
  aaroha::WavWriter recorder;
};

namespace {

void data_callback(ma_device* device, void* output, const void* input,
                   ma_uint32 frame_count) {
  auto* e = static_cast<ar_engine*>(device->pUserData);
  const int64_t now = e->frames.load(std::memory_order_relaxed);

  auto* out = static_cast<float*>(output);
  if (out) {
    std::memset(out, 0, sizeof(float) * frame_count);
    e->drone.configure(e->drone_sa.load(std::memory_order_relaxed),
                       e->drone_first_string.load(std::memory_order_relaxed));
    e->drone.set_volume(e->drone_volume.load(std::memory_order_relaxed));
    e->drone.set_on(e->drone_on.load(std::memory_order_relaxed));
    e->drone.render_add(out, frame_count);
    while (const SequenceCommand* command = e->sequence_ring.read_slot()) {
      if (command->count < 0) {
        e->voice.stop();
      } else {
        e->voice.set_sequence(command->notes, command->count);
      }
      e->sequence_ring.commit_read();
    }
    e->voice.render_add(out, frame_count, now);
    while (const ClickCommand* command = e->click_ring.read_slot()) {
      if (command->count < 0) {
        e->clicks.stop();
      } else {
        e->clicks.set_schedule(command->clicks, command->count);
      }
      e->click_ring.commit_read();
    }
    e->clicks.render_add(out, frame_count, now);
  }

  const auto* in = static_cast<const float*>(input);
  if (in && e->capture_on.load(std::memory_order_relaxed)) {
    for (ma_uint32 offset = 0; offset < frame_count; offset += kBlockFrames) {
      const int32_t n = static_cast<int32_t>(
          std::min<ma_uint32>(kBlockFrames, frame_count - offset));
      CaptureBlock* block = e->capture_ring.write_slot();
      if (!block) {
        e->capture_overruns.fetch_add(1, std::memory_order_relaxed);
        continue;
      }
      block->time = now + offset;
      block->frames = n;
      std::memcpy(block->samples, in + offset, sizeof(float) * n);
      e->capture_ring.commit_write();
    }
  }

  e->frames.store(now + frame_count, std::memory_order_relaxed);
}

void worker_loop(ar_engine* e) {
  aaroha::PitchTracker tracker;
  int64_t expected_time = -1;

  auto emit = [e](const ar_pitch_frame& frame) {
    ar_pitch_frame* slot = e->pitch_ring.write_slot();
    if (!slot) {
      e->pitch_overruns.fetch_add(1, std::memory_order_relaxed);
      return;
    }
    *slot = frame;
    e->pitch_ring.commit_write();
  };

  while (e->worker_running.load()) {
    {
      std::lock_guard<std::mutex> lock(e->tracker_mutex);
      if (e->tracker_dirty) {
        tracker.configure(e->tracker_config, e->sample_rate);
        e->tracker_dirty = false;
        expected_time = -1;
      }
    }

    const CaptureBlock* block = e->capture_ring.read_slot();
    if (!block) {
      std::this_thread::sleep_for(std::chrono::milliseconds(2));
      continue;
    }

    // A gap (capture gated off, or an overrun) restarts the analysis window
    // so no frame ever spans discontinuous audio.
    if (block->time != expected_time) tracker.reset(block->time);
    expected_time = block->time + block->frames;

    {
      std::lock_guard<std::mutex> lock(e->record_mutex);
      if (e->recorder.is_open()) e->recorder.write(block->samples, block->frames);
    }
    tracker.process(block->samples, block->frames, emit);
    e->capture_ring.commit_read();
  }
}

ma_result open_device(ar_engine* e, int preset) {
  ma_device_config config = ma_device_config_init(
      preset == AR_PRESET_NONE ? ma_device_type_playback : ma_device_type_duplex);
  config.sampleRate = static_cast<ma_uint32>(e->sample_rate);
  config.capture.format = ma_format_f32;
  config.capture.channels = 1;
  config.playback.format = ma_format_f32;
  config.playback.channels = 1;
  config.performanceProfile = ma_performance_profile_low_latency;
  config.dataCallback = data_callback;
  config.pUserData = e;

  config.aaudio.usage = ma_aaudio_usage_media;
  config.aaudio.contentType = ma_aaudio_content_type_music;
  switch (preset) {
    case AR_PRESET_UNPROCESSED:
      config.aaudio.inputPreset = ma_aaudio_input_preset_unprocessed;
      config.opensl.recordingPreset = ma_opensl_recording_preset_voice_unprocessed;
      break;
    case AR_PRESET_VOICE_RECOGNITION:
      config.aaudio.inputPreset = ma_aaudio_input_preset_voice_recognition;
      config.opensl.recordingPreset = ma_opensl_recording_preset_voice_recognition;
      break;
    default:
      break;
  }
  return ma_device_init(nullptr, &config, &e->device);
}

}  // namespace

extern "C" {

int32_t ar_abi_version(void) { return AR_ABI_VERSION; }
int32_t ar_sizeof_pitch_frame(void) { return sizeof(ar_pitch_frame); }
int32_t ar_sizeof_tracker_config(void) { return sizeof(ar_tracker_config); }
int32_t ar_sizeof_engine_info(void) { return sizeof(ar_engine_info); }
int32_t ar_sizeof_note(void) { return sizeof(ar_note); }
int32_t ar_sizeof_click(void) { return sizeof(ar_click); }

void ar_tracker_default_config(ar_tracker_config* out) {
  out->min_hz = 150.0f;
  out->max_hz = 2500.0f;
  out->threshold = 0.15f;
  out->highpass_hz = 0.0f;
  out->window = 1024;
  out->hop = 480;
}

ar_engine* ar_engine_create(int32_t sample_rate) {
  return new (std::nothrow) ar_engine(sample_rate > 0 ? sample_rate : 48000);
}

int32_t ar_engine_start(ar_engine* e) {
  if (!e) return MA_INVALID_ARGS;
  if (e->device_ready) return MA_SUCCESS;

  // Prefer the rawest mic path; fall back where a preset isn't supported.
  ma_result result = MA_ERROR;
  if (!e->capture_device) {
    result = open_device(e, AR_PRESET_NONE);
    if (result == MA_SUCCESS) e->input_preset = AR_PRESET_NONE;
  } else {
    for (int preset : {AR_PRESET_UNPROCESSED, AR_PRESET_VOICE_RECOGNITION,
                       AR_PRESET_DEFAULT}) {
      result = open_device(e, preset);
      if (result == MA_SUCCESS) {
        e->input_preset = preset;
        break;
      }
    }
  }
  if (result != MA_SUCCESS) return result;
  e->device_ready = true;

  e->capture_ring.clear();
  e->worker_running.store(true);
  e->worker = std::thread(worker_loop, e);

  result = ma_device_start(&e->device);
  if (result != MA_SUCCESS) {
    ar_engine_stop(e);
    return result;
  }
  return MA_SUCCESS;
}

void ar_engine_set_capture(ar_engine* e, int32_t on) {
  if (e) e->capture_device = on != 0;
}

void ar_engine_stop(ar_engine* e) {
  if (!e || !e->device_ready) return;
  ma_device_uninit(&e->device);  // stops the device and waits for the callback
  e->device_ready = false;
  e->worker_running.store(false);
  if (e->worker.joinable()) e->worker.join();
  ar_record_stop(e);
}

void ar_engine_destroy(ar_engine* e) {
  if (!e) return;
  ar_engine_stop(e);
  delete e;
}

int64_t ar_engine_time(ar_engine* e) {
  return e ? e->frames.load(std::memory_order_relaxed) : 0;
}

void ar_engine_get_info(ar_engine* e, ar_engine_info* out) {
  std::memset(out, 0, sizeof(*out));
  if (!e) return;
  out->sample_rate = e->sample_rate;
  out->input_preset = e->input_preset;
  out->running = e->device_ready ? 1 : 0;
  {
    std::lock_guard<std::mutex> lock(e->record_mutex);
    out->recording = e->recorder.is_open() ? 1 : 0;
  }
  out->capture_overruns = e->capture_overruns.load();
  out->pitch_overruns = e->pitch_overruns.load();
  const char* name =
      e->device_ready ? ma_get_backend_name(e->device.pContext->backend) : "none";
  std::strncpy(out->backend, name, sizeof(out->backend) - 1);
}

void ar_drone_set(ar_engine* e, double sa_hz, int32_t first_string, float volume,
                  int32_t on) {
  if (!e) return;
  e->drone_sa.store(sa_hz);
  e->drone_first_string.store(first_string);
  e->drone_volume.store(std::clamp(volume, 0.0f, 1.0f));
  e->drone_on.store(on != 0);
}

void ar_tracker_set(ar_engine* e, const ar_tracker_config* config) {
  if (!e || !config) return;
  std::lock_guard<std::mutex> lock(e->tracker_mutex);
  e->tracker_config = *config;
  e->tracker_dirty = true;
}

void ar_capture_enable(ar_engine* e, int32_t on) {
  if (e) e->capture_on.store(on != 0);
}

int32_t ar_read_pitch_frames(ar_engine* e, ar_pitch_frame* out, int32_t max) {
  if (!e) return 0;
  int32_t count = 0;
  while (count < max) {
    const ar_pitch_frame* frame = e->pitch_ring.read_slot();
    if (!frame) break;
    out[count++] = *frame;
    e->pitch_ring.commit_read();
  }
  return count;
}

int32_t ar_record_start(ar_engine* e, const char* wav_path) {
  if (!e || !wav_path) return -1;
  std::lock_guard<std::mutex> lock(e->record_mutex);
  if (e->recorder.is_open()) return -1;
  return e->recorder.open(wav_path, e->sample_rate) ? 0 : -1;
}

int64_t ar_record_stop(ar_engine* e) {
  if (!e) return 0;
  std::lock_guard<std::mutex> lock(e->record_mutex);
  return e->recorder.close();
}

int32_t ar_analyze(const float* samples, int64_t n, int32_t sample_rate,
                   const ar_tracker_config* config, ar_pitch_frame* out,
                   int32_t max) {
  if (!samples || !out || max <= 0) return 0;
  ar_tracker_config cfg;
  if (config) {
    cfg = *config;
  } else {
    ar_tracker_default_config(&cfg);
  }
  aaroha::PitchTracker tracker;
  tracker.configure(cfg, sample_rate);
  int32_t count = 0;
  tracker.process(samples, n, [&](const ar_pitch_frame& frame) {
    if (count < max) out[count++] = frame;
  });
  return count;
}

int32_t ar_play_sequence(ar_engine* e, const ar_note* notes, int32_t count) {
  if (!e || count < 0 || count > AR_MAX_SEQUENCE_NOTES || (count > 0 && !notes)) return -1;
  SequenceCommand* command = e->sequence_ring.write_slot();
  if (!command) return -1;
  command->count = count;
  if (count > 0) std::memcpy(command->notes, notes, sizeof(ar_note) * count);
  e->sequence_ring.commit_write();
  return 0;
}

void ar_stop_playback(ar_engine* e) {
  if (!e) return;
  SequenceCommand* command = e->sequence_ring.write_slot();
  if (!command) return;
  command->count = -1;
  e->sequence_ring.commit_write();
}

int32_t ar_play_clicks(ar_engine* e, const ar_click* clicks, int32_t count) {
  if (!e || count < 0 || count > AR_MAX_CLICKS || (count > 0 && !clicks)) return -1;
  ClickCommand* command = e->click_ring.write_slot();
  if (!command) return -1;
  command->count = count;
  if (count > 0) std::memcpy(command->clicks, clicks, sizeof(ar_click) * count);
  e->click_ring.commit_write();
  return 0;
}

void ar_stop_clicks(ar_engine* e) {
  if (!e) return;
  ClickCommand* command = e->click_ring.write_slot();
  if (!command) return;
  command->count = -1;
  e->click_ring.commit_write();
}

void ar_render_clicks(const ar_click* clicks, int32_t count, int32_t sample_rate, float* out,
                      int64_t n) {
  if (!out) return;
  std::memset(out, 0, sizeof(float) * n);
  auto* voice = new (std::nothrow) aaroha::ClickVoice(sample_rate);
  if (!voice) return;
  voice->set_schedule(clicks, count);
  voice->render_add(out, n, 0);
  delete voice;
}

void ar_render_notes(const ar_note* notes, int32_t count, int32_t sample_rate, float* out,
                     int64_t n) {
  if (!out) return;
  std::memset(out, 0, sizeof(float) * n);
  auto* voice = new (std::nothrow) aaroha::FluteVoice(sample_rate);
  if (!voice) return;
  voice->set_sequence(notes, count);
  voice->render_add(out, n, 0);
  delete voice;
}

void ar_render_drone(double sa_hz, int32_t first_string, float volume,
                     int32_t sample_rate, float* out, int64_t n) {
  if (!out) return;
  std::memset(out, 0, sizeof(float) * n);
  auto* drone = new (std::nothrow) aaroha::Drone(sample_rate);
  if (!drone) return;
  drone->configure(sa_hz, first_string);
  drone->set_volume(volume);
  drone->set_on(true);
  drone->render_add(out, n);
  delete drone;
}

}  // extern "C"
