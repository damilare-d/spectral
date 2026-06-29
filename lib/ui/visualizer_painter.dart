import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class VisualizerPainter extends CustomPainter {
  const VisualizerPainter({
    required this.shader,
    required this.fftTexture,
    required this.time,
  });

  final ui.FragmentShader shader;
  final ui.Image fftTexture;
  final double time;

  @override
  void paint(Canvas canvas, Size size) {
    // Uniform layout must match shaders/visualizer.frag declarations:
    //   uniform vec2  uResolution → setFloat(0, w), setFloat(1, h)
    //   uniform float uTime       → setFloat(2, t)
    //   uniform sampler2D uFftTexture → setImageSampler(0, img)
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, time);
    shader.setImageSampler(0, fftTexture);

    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = shader,
    );
  }

  @override
  bool shouldRepaint(VisualizerPainter old) =>
      old.fftTexture != fftTexture || old.time != time;
}
