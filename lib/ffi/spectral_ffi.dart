import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

// ── Native function signatures ────────────────────────────────────────────────

typedef _InitNative = Int32 Function(Int32 fftSize);
typedef _Init = int Function(int fftSize);

typedef _StartNative = Int32 Function();
typedef _Start = int Function();

typedef _StopNative = Void Function();
typedef _Stop = void Function();

typedef _GetMagnitudesNative = Int32 Function(Pointer<Float> out, Int32 count);
typedef _GetMagnitudes = int Function(Pointer<Float> out, int count);

typedef _DestroyNative = Void Function();
typedef _Destroy = void Function();

// ── Public wrapper ────────────────────────────────────────────────────────────

class SpectralFFI {
  SpectralFFI._() {
    final lib = _load();
    _init = lib.lookupFunction<_InitNative, _Init>('spectral_init');
    _start = lib.lookupFunction<_StartNative, _Start>('spectral_start');
    _stop = lib.lookupFunction<_StopNative, _Stop>('spectral_stop');
    _getMagnitudes =
        lib.lookupFunction<_GetMagnitudesNative, _GetMagnitudes>('spectral_get_magnitudes');
    _destroy = lib.lookupFunction<_DestroyNative, _Destroy>('spectral_destroy');
  }

  static SpectralFFI? _instance;
  static SpectralFFI get instance => _instance ??= SpectralFFI._();

  late final _Init _init;
  late final _Start _start;
  late final _Stop _stop;
  late final _GetMagnitudes _getMagnitudes;
  late final _Destroy _destroy;

  static DynamicLibrary _load() {
    if (Platform.isWindows) return DynamicLibrary.open('spectral_native.dll');
    if (Platform.isAndroid || Platform.isLinux) return DynamicLibrary.open('libspectral_native.so');
    if (Platform.isMacOS) return DynamicLibrary.open('libspectral_native.dylib');
    throw UnsupportedError('spectral_native: unsupported platform');
  }

  bool init(int fftSize) => _init(fftSize) != 0;
  bool start() => _start() != 0;
  void stop() => _stop();
  void destroy() => _destroy();

  // Returns a list of [count] normalized magnitudes in [0, 1].
  List<double> getMagnitudes(int count) {
    final ptr = calloc<Float>(count);
    try {
      final written = _getMagnitudes(ptr, count);
      return List.generate(written, (i) => ptr[i].toDouble());
    } finally {
      calloc.free(ptr);
    }
  }
}
