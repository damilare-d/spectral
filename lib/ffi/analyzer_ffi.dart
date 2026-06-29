import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

// ── Struct mirrors ────────────────────────────────────────────────────────────

// Opaque handle for AnalyzerCtx*
final class _AnalyzerCtx extends Opaque {}

// ── Native typedefs ───────────────────────────────────────────────────────────

typedef _LoadPcmNative = Pointer<_AnalyzerCtx> Function(
    Pointer<Float> pcm, Int32 numSamples, Int32 sampleRate);
typedef _LoadPcm = Pointer<_AnalyzerCtx> Function(
    Pointer<Float> pcm, int numSamples, int sampleRate);

typedef _GetEnergyNative = Int32 Function(
    Pointer<_AnalyzerCtx> ctx,
    Int32 windowMs, Int32 hopMs,
    Pointer<Int64> outStartMs, Pointer<Float> outEnergies,
    Int32 capacity);
typedef _GetEnergy = int Function(
    Pointer<_AnalyzerCtx> ctx,
    int windowMs, int hopMs,
    Pointer<Int64> outStartMs, Pointer<Float> outEnergies,
    int capacity);

typedef _GetOnsetsNative = Int32 Function(
    Pointer<_AnalyzerCtx> ctx,
    Int32 windowMs, Int32 hopMs,
    Pointer<Int64> outOnsetMs,
    Int32 capacity);
typedef _GetOnsets = int Function(
    Pointer<_AnalyzerCtx> ctx,
    int windowMs, int hopMs,
    Pointer<Int64> outOnsetMs,
    int capacity);

typedef _DestroyNative = Void Function(Pointer<_AnalyzerCtx> ctx);
typedef _Destroy = void Function(Pointer<_AnalyzerCtx> ctx);

typedef _FrameDiffNative = Float Function(
    Pointer<Uint8> frameA, Pointer<Uint8> frameB,
    Int32 width, Int32 height);
typedef _FrameDiff = double Function(
    Pointer<Uint8> frameA, Pointer<Uint8> frameB,
    int width, int height);

// ── Result types ──────────────────────────────────────────────────────────────

class EnergyWindow {
  final int startMs;
  final double energy; // [0, 1]
  const EnergyWindow(this.startMs, this.energy);
}

// ── Public wrapper ────────────────────────────────────────────────────────────

class AnalyzerFFI {
  AnalyzerFFI._() {
    final lib = _load();
    _loadPcm = lib.lookupFunction<_LoadPcmNative, _LoadPcm>('analyzer_load_pcm');
    _getEnergy = lib.lookupFunction<_GetEnergyNative, _GetEnergy>('analyzer_get_energy');
    _getOnsets = lib.lookupFunction<_GetOnsetsNative, _GetOnsets>('analyzer_get_onsets');
    _destroyCtx = lib.lookupFunction<_DestroyNative, _Destroy>('analyzer_destroy');
    _frameDiff = lib.lookupFunction<_FrameDiffNative, _FrameDiff>('analyzer_frame_difference');
  }

  static AnalyzerFFI? _instance;
  static AnalyzerFFI get instance => _instance ??= AnalyzerFFI._();

  late final _LoadPcm _loadPcm;
  late final _GetEnergy _getEnergy;
  late final _GetOnsets _getOnsets;
  late final _Destroy _destroyCtx;
  late final _FrameDiff _frameDiff;

  static DynamicLibrary _load() {
    if (Platform.isWindows) return DynamicLibrary.open('spectral_native.dll');
    if (Platform.isAndroid || Platform.isLinux) return DynamicLibrary.open('libspectral_native.so');
    if (Platform.isMacOS) return DynamicLibrary.open('libspectral_native.dylib');
    throw UnsupportedError('analyzer_ffi: unsupported platform');
  }

  /// Analyses a PCM buffer and returns energy windows + onset timestamps.
  /// [pcm]: float32 mono samples. [sampleRate]: e.g. 16000.
  /// [windowMs]/[hopMs]: window and hop sizes in milliseconds.
  ({List<EnergyWindow> windows, List<int> onsetMs}) analyzeAudio(
    Float32List pcm, {
    int sampleRate = 16000,
    int windowMs = 500,
    int hopMs = 250,
    int maxWindows = 4096,
    int maxOnsets = 4096,
  }) {
    final pcmPtr = calloc<Float>(pcm.length);
    final startMsPtr = calloc<Int64>(maxWindows);
    final energyPtr = calloc<Float>(maxWindows);
    final onsetPtr = calloc<Int64>(maxOnsets);

    try {
      for (int i = 0; i < pcm.length; i++) {
        pcmPtr[i] = pcm[i];
      }

      final ctx = _loadPcm(pcmPtr, pcm.length, sampleRate);
      if (ctx == nullptr) {
        return (windows: <EnergyWindow>[], onsetMs: <int>[]);
      }

      final nWindows = _getEnergy(ctx, windowMs, hopMs, startMsPtr, energyPtr, maxWindows);
      final nOnsets  = _getOnsets(ctx, windowMs, hopMs, onsetPtr, maxOnsets);
      _destroyCtx(ctx);

      final windows = List.generate(
        nWindows,
        (i) => EnergyWindow(startMsPtr[i], energyPtr[i]),
      );
      final onsets = List.generate(nOnsets, (i) => onsetPtr[i]);

      return (windows: windows, onsetMs: onsets);
    } finally {
      calloc.free(pcmPtr);
      calloc.free(startMsPtr);
      calloc.free(energyPtr);
      calloc.free(onsetPtr);
    }
  }

  /// Returns a scene-change score [0, 1] between two RGBA8 frames.
  /// Frames must be the same dimensions.
  double frameDifference(Uint8List frameA, Uint8List frameB, int width, int height) {
    final ptrA = calloc<Uint8>(frameA.length);
    final ptrB = calloc<Uint8>(frameB.length);
    try {
      for (int i = 0; i < frameA.length; i++) {
        ptrA[i] = frameA[i];
      }
      for (int i = 0; i < frameB.length; i++) {
        ptrB[i] = frameB[i];
      }
      return _frameDiff(ptrA, ptrB, width, height);
    } finally {
      calloc.free(ptrA);
      calloc.free(ptrB);
    }
  }
}
