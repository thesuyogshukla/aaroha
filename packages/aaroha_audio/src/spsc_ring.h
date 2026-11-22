// Single-producer single-consumer lock-free ring of fixed-size slots.
// The producer fills a slot in place and commits it; the consumer reads a
// slot in place and releases it. No allocation after construction.

#ifndef AAROHA_SPSC_RING_H
#define AAROHA_SPSC_RING_H

#include <atomic>
#include <cstddef>
#include <memory>

namespace aaroha {

template <typename T, size_t N>
class SpscRing {
  static_assert((N & (N - 1)) == 0, "capacity must be a power of two");

 public:
  SpscRing() : slots_(new T[N]) {}

  // Producer side. Returns nullptr when full.
  T* write_slot() {
    const size_t head = head_.load(std::memory_order_relaxed);
    if (head - tail_.load(std::memory_order_acquire) == N) return nullptr;
    return &slots_[head & (N - 1)];
  }
  void commit_write() {
    head_.store(head_.load(std::memory_order_relaxed) + 1,
                std::memory_order_release);
  }

  // Consumer side. Returns nullptr when empty.
  const T* read_slot() {
    const size_t tail = tail_.load(std::memory_order_relaxed);
    if (head_.load(std::memory_order_acquire) == tail) return nullptr;
    return &slots_[tail & (N - 1)];
  }
  void commit_read() {
    tail_.store(tail_.load(std::memory_order_relaxed) + 1,
                std::memory_order_release);
  }

  // Consumer side: drop everything queued.
  void clear() { tail_.store(head_.load(std::memory_order_acquire)); }

 private:
  std::unique_ptr<T[]> slots_;
  alignas(64) std::atomic<size_t> head_{0};
  alignas(64) std::atomic<size_t> tail_{0};
};

}  // namespace aaroha

#endif  // AAROHA_SPSC_RING_H
