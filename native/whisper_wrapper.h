#pragma once

#include <stdint.h>
#include "spectral.h"  /* SPECTRAL_EXPORT */

#ifdef __cplusplus
extern "C" {
#endif

/* A single transcription segment returned by whisper. */
typedef struct {
    int64_t t0_ms;    /* segment start in milliseconds */
    int64_t t1_ms;    /* segment end in milliseconds */
    float   prob;     /* average token probability [0, 1] */
    char    text[512]; /* null-terminated UTF-8 text */
} WhisperSegment;

/* Load a whisper.cpp GGML model from disk.
 * Returns an opaque handle on success, NULL on failure. */
SPECTRAL_EXPORT void* whisper_wrapper_load(const char* model_path);

/* Transcribe float32 mono PCM at 16 kHz.
 * out_segments: caller-allocated array of WhisperSegment.
 * capacity: max segments to write.
 * Returns the number of segments written, or -1 on error. */
SPECTRAL_EXPORT int whisper_wrapper_transcribe(
    void*               handle,
    const float*        pcm_16khz,
    int                 num_samples,
    WhisperSegment*     out_segments,
    int                 capacity);

/* Free the model context. Safe to call with NULL. */
SPECTRAL_EXPORT void whisper_wrapper_free(void* handle);

#ifdef __cplusplus
}
#endif
