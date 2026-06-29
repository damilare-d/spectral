#include "analyzer.h"

#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <stdint.h>

/* ── AnalyzerCtx ─────────────────────────────────────────────────────────── */

struct AnalyzerCtx {
    float*  pcm;
    int     num_samples;
    int     sample_rate;
};

AnalyzerCtx* analyzer_load_pcm(const float* pcm, int num_samples, int sample_rate) {
    if (!pcm || num_samples <= 0 || sample_rate <= 0) return NULL;

    AnalyzerCtx* ctx = (AnalyzerCtx*)malloc(sizeof(AnalyzerCtx));
    if (!ctx) return NULL;

    ctx->pcm = (float*)malloc(num_samples * sizeof(float));
    if (!ctx->pcm) { free(ctx); return NULL; }

    memcpy(ctx->pcm, pcm, num_samples * sizeof(float));
    ctx->num_samples = num_samples;
    ctx->sample_rate = sample_rate;
    return ctx;
}

void analyzer_destroy(AnalyzerCtx* ctx) {
    if (!ctx) return;
    free(ctx->pcm);
    free(ctx);
}

/* ── Energy analysis ────────────────────────────────────────────────────── */

int analyzer_get_energy(
        AnalyzerCtx* ctx,
        int window_ms, int hop_ms,
        int64_t* out_start_ms, float* out_energies,
        int capacity) {

    if (!ctx || window_ms <= 0 || hop_ms <= 0 || capacity <= 0) return 0;

    int window_samples = (int)((int64_t)window_ms * ctx->sample_rate / 1000);
    int hop_samples    = (int)((int64_t)hop_ms    * ctx->sample_rate / 1000);
    if (window_samples <= 0 || hop_samples <= 0) return 0;

    /* First pass: compute RMS per window and track global max for normalisation */
    float max_rms = 1e-9f;
    int count = 0;

    int start = 0;
    while (start + window_samples <= ctx->num_samples && count < capacity) {
        double sum_sq = 0.0;
        for (int i = start; i < start + window_samples; i++) {
            double s = ctx->pcm[i];
            sum_sq += s * s;
        }
        float rms = (float)sqrt(sum_sq / window_samples);
        if (rms > max_rms) max_rms = rms;
        count++;
        start += hop_samples;
    }

    /* Second pass: normalise and fill output arrays */
    int written = 0;
    start = 0;
    while (start + window_samples <= ctx->num_samples && written < capacity) {
        double sum_sq = 0.0;
        for (int i = start; i < start + window_samples; i++) {
            double s = ctx->pcm[i];
            sum_sq += s * s;
        }
        float rms = (float)sqrt(sum_sq / window_samples);
        out_start_ms[written]  = (int64_t)start * 1000 / ctx->sample_rate;
        out_energies[written]  = rms / max_rms;
        written++;
        start += hop_samples;
    }
    return written;
}

/* ── Onset detection ────────────────────────────────────────────────────── */

int analyzer_get_onsets(
        AnalyzerCtx* ctx,
        int window_ms, int hop_ms,
        int64_t* out_onset_ms,
        int capacity) {

    if (!ctx || window_ms <= 0 || hop_ms <= 0 || capacity <= 0) return 0;

    int window_samples = (int)((int64_t)window_ms * ctx->sample_rate / 1000);
    int hop_samples    = (int)((int64_t)hop_ms    * ctx->sample_rate / 1000);
    if (window_samples <= 0 || hop_samples <= 0) return 0;

    /* Compute per-window RMS energy array */
    int max_windows = (ctx->num_samples - window_samples) / hop_samples + 1;
    if (max_windows <= 0) return 0;

    float* energies = (float*)malloc(max_windows * sizeof(float));
    if (!energies) return 0;

    int n_windows = 0;
    int start = 0;
    while (start + window_samples <= ctx->num_samples && n_windows < max_windows) {
        double sum_sq = 0.0;
        for (int i = start; i < start + window_samples; i++) {
            double s = ctx->pcm[i];
            sum_sq += s * s;
        }
        energies[n_windows++] = (float)sqrt(sum_sq / window_samples);
        start += hop_samples;
    }

    if (n_windows < 2) { free(energies); return 0; }

    /* Compute mean and stddev of positive energy flux */
    double mean_flux = 0.0, mean_sq_flux = 0.0;
    int n_flux = 0;
    for (int i = 1; i < n_windows; i++) {
        float flux = energies[i] - energies[i - 1];
        if (flux > 0.0f) {
            mean_flux    += flux;
            mean_sq_flux += flux * flux;
            n_flux++;
        }
    }
    if (n_flux == 0) { free(energies); return 0; }
    mean_flux    /= n_flux;
    mean_sq_flux /= n_flux;
    float stddev  = (float)sqrt(mean_sq_flux - mean_flux * mean_flux);
    float threshold = (float)mean_flux + 1.5f * stddev;

    /* Detect onsets: positive flux above threshold */
    int n_onsets = 0;
    for (int i = 1; i < n_windows && n_onsets < capacity; i++) {
        float flux = energies[i] - energies[i - 1];
        if (flux > threshold) {
            int64_t onset_sample = (int64_t)i * hop_samples;
            out_onset_ms[n_onsets++] = onset_sample * 1000 / ctx->sample_rate;
        }
    }

    free(energies);
    return n_onsets;
}

/* ── Frame difference ───────────────────────────────────────────────────── */

float analyzer_frame_difference(
        const uint8_t* frame_a,
        const uint8_t* frame_b,
        int width, int height) {

    if (!frame_a || !frame_b || width <= 0 || height <= 0) return 0.0f;

    /* Mean absolute difference over RGB channels (skip alpha) */
    double total = 0.0;
    int n_pixels = width * height;
    for (int i = 0; i < n_pixels; i++) {
        int base = i * 4;
        total += abs((int)frame_a[base]     - (int)frame_b[base]);
        total += abs((int)frame_a[base + 1] - (int)frame_b[base + 1]);
        total += abs((int)frame_a[base + 2] - (int)frame_b[base + 2]);
    }
    /* Normalise: max possible diff per pixel per channel is 255, 3 channels */
    return (float)(total / (n_pixels * 3 * 255.0));
}
