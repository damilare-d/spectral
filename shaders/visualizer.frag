#include <flutter/runtime_effect.glsl>

// Uniforms (indices match Dart setFloat calls in order of declaration):
// setFloat(0, width)   → uResolution.x
// setFloat(1, height)  → uResolution.y
// setFloat(2, time)    → uTime
// setImageSampler(0, fftTexture) → uFftTexture
uniform vec2      uResolution;
uniform float     uTime;
uniform sampler2D uFftTexture;  // 1 × N grayscale: each pixel.r = magnitude[x]

out vec4 fragColor;

// Inigo Quilez cosine-based palette — maps [0,1] to a smooth color cycle.
vec3 palette(float t) {
    vec3 a = vec3(0.5, 0.5, 0.5);
    vec3 b = vec3(0.5, 0.5, 0.5);
    vec3 c = vec3(1.0, 0.7, 0.4);
    vec3 d = vec3(0.00, 0.15, 0.20);
    return a + b * cos(6.28318 * (c * t + d));
}

void main() {
    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 uv = fragCoord / uResolution;

    // Sample the FFT magnitude for this horizontal position.
    float mag = texture(uFftTexture, vec2(uv.x, 0.5)).r;

    // Bars grow upward: filled when we're in the lower `mag` fraction of height.
    // uv.y = 0 at top, 1 at bottom in Flutter's coordinate space.
    float barFill = step(1.0 - mag, uv.y);

    // Soft glow around the leading edge of the bar.
    float edgeY      = 1.0 - mag;
    float distToEdge = abs(uv.y - edgeY);
    float glow       = 0.018 / (distToEdge + 0.006) * mag * mag;

    // Color: shifts with frequency, height, and time for a living feel.
    vec3 col       = palette(uv.x * 0.65 + (1.0 - uv.y) * 0.35 + uTime * 0.06);
    vec3 glowColor = col * 1.8;

    vec3 color = col * barFill + glowColor * glow * (1.0 - barFill);

    // Subtle vignette to frame the visualization.
    vec2 vc    = uv * 2.0 - 1.0;
    float vig  = 1.0 - 0.45 * dot(vc, vc);
    color *= vig;

    fragColor = vec4(color, 1.0);
}
