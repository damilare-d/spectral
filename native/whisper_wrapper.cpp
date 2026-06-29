#include "whisper_wrapper.h"
#include "whisper.h"

#include <cstring>
#include <cstdio>
#include <algorithm>

extern "C" {

void* whisper_wrapper_load(const char* model_path) {
    if (!model_path) return nullptr;

    whisper_context_params cparams = whisper_context_default_params();
    cparams.use_gpu = false;  /* CPU-only; GPU not available on most Android targets */

    whisper_context* ctx = whisper_init_from_file_with_params(model_path, cparams);
    return static_cast<void*>(ctx);
}

int whisper_wrapper_transcribe(
        void*           handle,
        const float*    pcm_16khz,
        int             num_samples,
        WhisperSegment* out_segments,
        int             capacity) {

    if (!handle || !pcm_16khz || num_samples <= 0 || !out_segments || capacity <= 0) {
        return -1;
    }

    auto* ctx = static_cast<whisper_context*>(handle);

    whisper_full_params params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
    params.print_realtime   = false;
    params.print_progress   = false;
    params.print_timestamps = true;
    params.language         = "en";
    params.n_threads        = 4;
    params.single_segment   = false;

    int ret = whisper_full(ctx, params, pcm_16khz, num_samples);
    if (ret != 0) return -1;

    int n_segments = whisper_full_n_segments(ctx);
    int written    = std::min(n_segments, capacity);

    for (int i = 0; i < written; i++) {
        out_segments[i].t0_ms = whisper_full_get_segment_t0(ctx, i) * 10;  /* centiseconds → ms */
        out_segments[i].t1_ms = whisper_full_get_segment_t1(ctx, i) * 10;
        out_segments[i].prob  = 0.0f;

        /* Accumulate average token probability for this segment */
        int n_tokens = whisper_full_n_tokens(ctx, i);
        if (n_tokens > 0) {
            float sum_p = 0.0f;
            for (int t = 0; t < n_tokens; t++) {
                sum_p += whisper_full_get_token_p(ctx, i, t);
            }
            out_segments[i].prob = sum_p / n_tokens;
        }

        const char* text = whisper_full_get_segment_text(ctx, i);
        if (text) {
            strncpy(out_segments[i].text, text, sizeof(out_segments[i].text) - 1);
            out_segments[i].text[sizeof(out_segments[i].text) - 1] = '\0';
        } else {
            out_segments[i].text[0] = '\0';
        }
    }

    return written;
}

void whisper_wrapper_free(void* handle) {
    if (!handle) return;
    whisper_free(static_cast<whisper_context*>(handle));
}

}  /* extern "C" */
