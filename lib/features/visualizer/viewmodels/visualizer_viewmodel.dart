import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../ffi/spectral_ffi.dart';

class VisualizerViewModel extends ChangeNotifier {
  static const int _fftSize = 1024;
  static const int _fftBins = _fftSize ~/ 2;

  ui.FragmentShader? _shader;
  ui.Image? _fftTexture;
  double _time = 0.0;
  bool _running = false;
  bool _permissionDenied = false;
  bool _updating = false;
  bool _disposed = false;

  ui.FragmentShader? get shader => _shader;
  ui.Image? get fftTexture => _fftTexture;
  double get time => _time;
  bool get running => _running;
  bool get permissionDenied => _permissionDenied;

  Future<void> init() async {
    await _loadShader();
    await _startCapture();
  }

  Future<void> _loadShader() async {
    final program =
        await ui.FragmentProgram.fromAsset('shaders/visualizer.frag');
    _shader = program.fragmentShader();
    notifyListeners();
  }

  Future<void> _startCapture() async {
    if (Platform.isAndroid) {
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        _permissionDenied = true;
        notifyListeners();
        return;
      }
    }
    final ok =
        SpectralFFI.instance.init(_fftSize) && SpectralFFI.instance.start();
    _running = ok;
    notifyListeners();
  }

  /// Called from the View's Ticker on every vsync frame.
  void onTick(Duration elapsed) {
    _time = elapsed.inMilliseconds / 1000.0;
    if (_running && !_updating) {
      _updating = true;
      _fetchAndUpdate().whenComplete(() => _updating = false);
    }
    // Always notify so uTime animates the shader even without new FFT data.
    notifyListeners();
  }

  Future<void> _fetchAndUpdate() async {
    final magnitudes = SpectralFFI.instance.getMagnitudes(_fftBins);
    final newTexture = await _buildTexture(magnitudes);
    // Guard: VM may have been disposed while we were awaiting the texture build.
    // Disposing twice crashes with an assertion error in dart:ui/painting.dart.
    if (_disposed) {
      newTexture.dispose();
      return;
    }
    final old = _fftTexture;
    _fftTexture = newTexture;
    old?.dispose();
    notifyListeners();
  }

  Future<ui.Image> _buildTexture(List<double> magnitudes) async {
    final n = magnitudes.length;
    final pixels = Uint8List(n * 4);
    for (int i = 0; i < n; i++) {
      final v = (magnitudes[i] * 255).clamp(0, 255).toInt();
      pixels[i * 4]     = v;
      pixels[i * 4 + 1] = v;
      pixels[i * 4 + 2] = v;
      pixels[i * 4 + 3] = 255;
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(pixels);
    final descriptor = ui.ImageDescriptor.raw(
      buffer,
      width: n,
      height: 1,
      pixelFormat: ui.PixelFormat.rgba8888,
    );
    final codec = await descriptor.instantiateCodec(
        targetWidth: n, targetHeight: 1);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  @override
  void dispose() {
    _disposed = true;
    SpectralFFI.instance.stop();
    SpectralFFI.instance.destroy();
    _fftTexture?.dispose();
    _fftTexture = null;
    super.dispose();
  }
}
