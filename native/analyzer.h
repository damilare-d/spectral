#pragma once

#include <stdint.h>
#include <stddef.h>
#include "spectral.h"  /* reuse SPECTRAL_EXPORT */

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Audio energy + onset analysis.
 * Call analyzer_load_pcm() first, then query energy/onset, then destroy.
 */

typedef struct AnalyzerCtx AnalyzerCtx;

/* Load float32 mono PCM (already decoded from a WAV or raw file).
 * sample_rate: typically 16000 (Whisper's expected rate).
 * Returns opaque handle on success, NULL on allocation failure. */
SPECTRAL_EXPORT AnalyzerCtx* analyzer_load_pcm(
    const float* pcm, int num_samples, int sample_rate);

/* Fill out_energies and out_start_ms with per-window RMS energy in [0,1].
 * window_ms: rolling window width in ms (e.g. 500).
 * hop_ms: step between windows (e.g. 250).
 * capacity: max entries the caller-allocated arrays can hold.
 * Returns number of windows written. */
SPECTRAL_EXPORT int analyzer_get_energy(
    AnalyzerCtx* ctx,
    int window_ms, int hop_ms,
    int64_t* out_start_ms, float* out_energies,
    int capacity);

/* Fill out_onset_ms with timestamps (ms) of detected onset events.
 * Uses positive energy-flux thresholding (mean + 1.5 * stddev).
 * capacity: max entries.
 * Returns number of onsets detected. */
SPECTRAL_EXPORT int analyzer_get_onsets(
    AnalyzerCtx* ctx,
    int window_ms, int hop_ms,
    int64_t* out_onset_ms,
    int capacity);

SPECTRAL_EXPORT void analyzer_destroy(AnalyzerCtx* ctx);

/*
 * Frame difference scoring for scene cut detection.
 * Operates on raw RGBA8 pixel buffers at any resolution.
 * Returns a score in [0, 1]; higher means more visual change.
 * A score above ~0.35 typically indicates a hard scene cut.
 */
SPECTRAL_EXPORT float analyzer_frame_difference(
    const uint8_t* frame_a,
    const uint8_t* frame_b,
    int width, int height);

#ifdef __cplusplus
}
#endif
