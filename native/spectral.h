#pragma once

#ifdef _WIN32
#define SPECTRAL_EXPORT __declspec(dllexport)
#else
#define SPECTRAL_EXPORT __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
#endif

// Initialize the audio capture and FFT pipeline.
// fft_size: number of samples per FFT frame (must be power of 2, e.g. 1024)
// Returns 1 on success, 0 on failure.
SPECTRAL_EXPORT int spectral_init(int fft_size);

// Open and start the default capture device (microphone).
// Returns 1 on success, 0 on failure.
SPECTRAL_EXPORT int spectral_start(void);

// Stop and close the capture device.
SPECTRAL_EXPORT void spectral_stop(void);

// Compute FFT on the current audio ring buffer and write normalized
// magnitudes into `out`. Writes min(count, fft_size/2) values in [0, 1].
// Returns the number of values written.
SPECTRAL_EXPORT int spectral_get_magnitudes(float* out, int count);

// Release all resources.
SPECTRAL_EXPORT void spectral_destroy(void);

#ifdef __cplusplus
}
#endif
