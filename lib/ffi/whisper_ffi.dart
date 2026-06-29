import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

// ── Struct mirror for WhisperSegment ─────────────────────────────────────────
// Matches native/whisper_wrapper.h: { int64_t t0_ms, t1_ms; float prob; char text[512]; }

final class WhisperSegmentNative extends Struct {
  @Int64()
  external int t0Ms;

  @Int64()
  external int t1Ms;

  @Float()
  external double prob;

  @Array(512)
  external Array<Uint8> text;
}

// ── Result type ───────────────────────────────────────────────────────────────

class WhisperSegment {
  final int t0Ms;
  final int t1Ms;
  final double prob;
  final String text;
  const WhisperSegment(this.t0Ms, this.t1Ms, this.prob, this.text);
}

// ── Native typedefs ───────────────────────────────────────────────────────────

typedef _WrapperLoadNative = Pointer<Void> Function(Pointer<Utf8> modelPath);
typedef _WrapperLoad = Pointer<Void> Function(Pointer<Utf8> modelPath);

typedef _WrapperTranscribeNative = Int32 Function(
    Pointer<Void> handle,
    Pointer<Float> pcm, Int32 numSamples,
    Pointer<WhisperSegmentNative> outSegments, Int32 capacity);
typedef _WrapperTranscribe = int Function(
    Pointer<Void> handle,
    Pointer<Float> pcm, int numSamples,
    Pointer<WhisperSegmentNative> outSegments, int capacity);

typedef _WrapperFreeNative = Void Function(Pointer<Void> handle);
typedef _WrapperFree = void Function(Pointer<Void> handle);

// ── Public wrapper ────────────────────────────────────────────────────────────

class WhisperFFI {
  WhisperFFI._() {
    final lib = _load();
    _wrapperLoad = lib.lookupFunction<_WrapperLoadNative, _WrapperLoad>(
        'whisper_wrapper_load');
    _wrapperTranscribe =
        lib.lookupFunction<_WrapperTranscribeNative, _WrapperTranscribe>(
            'whisper_wrapper_transcribe');
    _wrapperFree = lib.lookupFunction<_WrapperFreeNative, _WrapperFree>(
        'whisper_wrapper_free');
  }

  static WhisperFFI? _instance;
  static WhisperFFI get instance => _instance ??= WhisperFFI._();

  late final _WrapperLoad _wrapperLoad;
  late final _WrapperTranscribe _wrapperTranscribe;
  late final _WrapperFree _wrapperFree;

  // Opaque whisper context — kept alive for the session.
  Pointer<Void>? _ctx;
  String? _loadedModelPath;

  static DynamicLibrary _load() {
    if (Platform.isWindows) return DynamicLibrary.open('spectral_native.dll');
    if (Platform.isAndroid || Platform.isLinux) {
      return DynamicLibrary.open('libspectral_native.so');
    }
    if (Platform.isMacOS) return DynamicLibrary.open('libspectral_native.dylib');
    throw UnsupportedError('whisper_ffi: unsupported platform');
  }

  /// Load (or reuse) the Whisper model from [modelPath].
  /// Expensive on first call (~2–3 s); subsequent calls with the same path are free.
  bool loadModel(String modelPath) {
    if (_ctx != null && _loadedModelPath == modelPath) return true;
    unloadModel();

    final pathPtr = modelPath.toNativeUtf8();
    try {
      final ctx = _wrapperLoad(pathPtr);
      if (ctx == nullptr) return false;
      _ctx = ctx;
      _loadedModelPath = modelPath;
      return true;
    } finally {
      calloc.free(pathPtr);
    }
  }

  /// Transcribe [pcm] (float32 mono, 16 kHz). Model must be loaded first.
  /// Returns a list of [WhisperSegment] with timestamps in milliseconds.
  List<WhisperSegment> transcribe(Float32List pcm, {int maxSegments = 512}) {
    final ctx = _ctx;
    if (ctx == null) throw StateError('WhisperFFI: model not loaded');

    final pcmPtr = calloc<Float>(pcm.length);
    final segPtr = calloc<WhisperSegmentNative>(maxSegments);

    try {
      for (int i = 0; i < pcm.length; i++) {
        pcmPtr[i] = pcm[i];
      }

      final n = _wrapperTranscribe(ctx, pcmPtr, pcm.length, segPtr, maxSegments);
      if (n < 0) return [];

      return List.generate(n, (i) {
        final s = segPtr[i];
        // Convert char[512] → Dart String
        final bytes = <int>[];
        for (int b = 0; b < 512; b++) {
          final c = s.text[b];
          if (c == 0) break;
          bytes.add(c);
        }
        final text = String.fromCharCodes(bytes).trim();
        return WhisperSegment(s.t0Ms, s.t1Ms, s.prob, text);
      });
    } finally {
      calloc.free(pcmPtr);
      calloc.free(segPtr);
    }
  }

  void unloadModel() {
    final ctx = _ctx;
    if (ctx != null) {
      _wrapperFree(ctx);
      _ctx = null;
      _loadedModelPath = null;
    }
  }
}
