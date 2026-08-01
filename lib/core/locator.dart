import 'package:get_it/get_it.dart';

import '../models/render_config.dart';
import '../services/ffmpeg_service.dart';
import '../services/highlight_detector.dart';
import '../services/render_service.dart';
import '../services/whisper_model_service.dart';

/// Global service locator — mirrors the GetIt pattern from Stacked projects.
/// Access via [sl<T>()] anywhere in the app.
final GetIt sl = GetIt.instance;

void setupLocator() {
  // ── Services (long-lived singletons) ──────────────────────────────────────
  sl.registerLazySingleton<FfmpegService>(() => FfmpegService());
  sl.registerLazySingleton<WhisperModelService>(() => WhisperModelService());
  sl.registerLazySingleton<RenderService>(() => RenderService());

  // HighlightDetector receives its services via constructor injection.
  // FaceDetectionService is NOT registered globally because it must be
  // recreated for each analysis run (close() makes the instance unusable).
  sl.registerLazySingleton<HighlightDetector>(() => HighlightDetector(
        ffmpegService: sl<FfmpegService>(),
        modelService: sl<WhisperModelService>(),
      ));

  // RenderConfig persists user's render preferences for the app lifetime.
  sl.registerSingleton<RenderConfig>(RenderConfig());
}
