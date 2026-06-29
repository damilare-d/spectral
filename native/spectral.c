#define MINIAUDIO_IMPLEMENTATION
#include "miniaudio.h"
#include "kiss_fft.h"
#include "spectral.h"

#include <stdlib.h>
#include <string.h>
#include <math.h>

#define SAMPLE_RATE 44100

typedef struct {
    ma_device  device;
    ma_mutex   mutex;

    kiss_fft_cfg fft_cfg;
    int          fft_size;

    float* ring_buffer;
    int    write_pos;

    int initialized;
    int device_open;
} SpectralState;

static SpectralState g;

static void data_callback(ma_device* device, void* output, const void* input,
                           ma_uint32 frame_count)
{
    (void)device;
    (void)output;

    if (!input || !g.initialized) return;

    const float* samples = (const float*)input;

    ma_mutex_lock(&g.mutex);
    for (ma_uint32 i = 0; i < frame_count; i++) {
        g.ring_buffer[g.write_pos] = samples[i];
        g.write_pos = (g.write_pos + 1) % g.fft_size;
    }
    ma_mutex_unlock(&g.mutex);
}

SPECTRAL_EXPORT int spectral_init(int fft_size)
{
    if (g.initialized) return 1;
    memset(&g, 0, sizeof(g));

    if (fft_size <= 0) fft_size = 1024;
    g.fft_size = fft_size;

    g.ring_buffer = (float*)calloc((size_t)fft_size, sizeof(float));
    if (!g.ring_buffer) return 0;

    g.fft_cfg = kiss_fft_alloc(fft_size, 0, NULL, NULL);
    if (!g.fft_cfg) {
        free(g.ring_buffer);
        return 0;
    }

    if (ma_mutex_init(&g.mutex) != MA_SUCCESS) {
        kiss_fft_free(g.fft_cfg);
        free(g.ring_buffer);
        return 0;
    }

    g.initialized = 1;
    return 1;
}

SPECTRAL_EXPORT int spectral_start(void)
{
    if (!g.initialized || g.device_open) return 0;

    ma_device_config cfg = ma_device_config_init(ma_device_type_capture);
    cfg.capture.format   = ma_format_f32;
    cfg.capture.channels = 1;
    cfg.sampleRate       = SAMPLE_RATE;
    cfg.dataCallback     = data_callback;

    if (ma_device_init(NULL, &cfg, &g.device) != MA_SUCCESS) return 0;
    if (ma_device_start(&g.device) != MA_SUCCESS) {
        ma_device_uninit(&g.device);
        return 0;
    }

    g.device_open = 1;
    return 1;
}

SPECTRAL_EXPORT void spectral_stop(void)
{
    if (!g.device_open) return;
    ma_device_stop(&g.device);
    ma_device_uninit(&g.device);
    g.device_open = 0;
}

SPECTRAL_EXPORT int spectral_get_magnitudes(float* out, int count)
{
    if (!g.initialized || !out || count <= 0) return 0;

    int n    = g.fft_size;
    int bins = (count < n / 2) ? count : n / 2;

    kiss_fft_cpx* cx_in  = (kiss_fft_cpx*)malloc((size_t)n * sizeof(kiss_fft_cpx));
    kiss_fft_cpx* cx_out = (kiss_fft_cpx*)malloc((size_t)n * sizeof(kiss_fft_cpx));
    if (!cx_in || !cx_out) {
        free(cx_in);
        free(cx_out);
        return 0;
    }

    // Copy ring buffer oldest-to-newest with Hann window applied
    ma_mutex_lock(&g.mutex);
    for (int i = 0; i < n; i++) {
        int   idx  = (g.write_pos + i) % n;
        float hann = 0.5f * (1.0f - cosf(2.0f * 3.14159265f * (float)i / (float)(n - 1)));
        cx_in[i].r = g.ring_buffer[idx] * hann;
        cx_in[i].i = 0.0f;
    }
    ma_mutex_unlock(&g.mutex);

    kiss_fft(g.fft_cfg, cx_in, cx_out);

    // Compute normalized log-scale magnitudes
    for (int i = 0; i < bins; i++) {
        float r   = cx_out[i].r;
        float im  = cx_out[i].i;
        float mag = sqrtf(r * r + im * im) / (float)n;

        // Map dBFS range [-80, 0] to [0, 1]
        float db         = 20.0f * log10f(mag + 1e-9f);
        float normalized = (db + 80.0f) / 80.0f;
        if (normalized < 0.0f) normalized = 0.0f;
        if (normalized > 1.0f) normalized = 1.0f;

        out[i] = normalized;
    }

    free(cx_in);
    free(cx_out);
    return bins;
}

SPECTRAL_EXPORT void spectral_destroy(void)
{
    if (!g.initialized) return;
    spectral_stop();
    ma_mutex_uninit(&g.mutex);
    kiss_fft_free(g.fft_cfg);
    free(g.ring_buffer);
    memset(&g, 0, sizeof(g));
}
