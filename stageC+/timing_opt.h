/*
 * timing_opt.h  -  Stage C timing helper (works on Windows, macOS and Raspberry Pi / Linux)
 *
 *   uint64_t now_ns(void)     current time in nanoseconds (only differences are meaningful)
 *   void     sleep_ms(int ms) pause for about ms milliseconds
 *
 * Tip: #include "timing_opt.h" before any other header.
 */
#ifndef TIMING_OPT_H
#define TIMING_OPT_H

#if defined(__linux__) && !defined(_POSIX_C_SOURCE) && !defined(_GNU_SOURCE)
#define _POSIX_C_SOURCE 200809L          /* makes clock_gettime visible on Linux */
#endif

#include <stdint.h>

static inline uint64_t timing_ticks_to_ns(uint64_t ticks, uint64_t frequency) {
    return (ticks / frequency) * 1000000000ULL +
           (ticks % frequency) * 1000000000ULL / frequency;
}

#ifdef _WIN32
  #include <windows.h>
  static inline uint64_t timing_tick_frequency(void) {
      static uint64_t frequency = 0;
      if (frequency == 0) {
          LARGE_INTEGER value;
          QueryPerformanceFrequency(&value);
          frequency = (uint64_t)value.QuadPart;
      }
      return frequency;
  }

  static inline uint64_t timing_now_ticks(void) {
      LARGE_INTEGER count;
      QueryPerformanceCounter(&count);
      return (uint64_t)count.QuadPart;
  }

  static inline uint64_t now_ns(void) {
      return timing_ticks_to_ns(timing_now_ticks(), timing_tick_frequency());
  }

  static inline void sleep_ms(int ms) { Sleep((DWORD)ms); }

#else   /* macOS, Linux, Raspberry Pi */
  #include <time.h>

  static inline uint64_t now_ns(void) {
      struct timespec t;
      clock_gettime(CLOCK_MONOTONIC, &t);
      return (uint64_t)t.tv_sec * 1000000000ULL + (uint64_t)t.tv_nsec;
  }

  static inline uint64_t timing_tick_frequency(void) { return 1000000000ULL; }
  static inline uint64_t timing_now_ticks(void) { return now_ns(); }

  static inline void sleep_ms(int ms) {
      struct timespec t;
      t.tv_sec  = ms / 1000;
      t.tv_nsec = (long)(ms % 1000) * 1000000L;
      nanosleep(&t, NULL);
  }
#endif

#endif /* TIMING_OPT_H */
