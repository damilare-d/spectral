import 'dart:io';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FaceDetectionService {
  // ML Kit is Android/iOS only — null on Windows/desktop.
  final FaceDetector? _detector = Platform.isWindows
      ? null
      : FaceDetector(
          options: FaceDetectorOptions(
            enableClassification: true,
            enableLandmarks: false,
            enableContours: false,
            performanceMode: FaceDetectorMode.fast,
          ),
        );

  bool _closed = false;

  /// Score each frame file. Returns a parallel list of face scores in [0, 1].
  /// Score = max(smilingProbability) across detected faces, or 0.3 if a face
  /// is present but smiling probability is unavailable, or 0 if no face.
  ///
  /// On Windows, returns 0.0 for every frame (ML Kit unavailable on desktop).
  Future<List<double>> scoreFrames(List<String> framePaths) async {
    if (_detector == null) return List.filled(framePaths.length, 0.0);

    final scores = <double>[];
    for (final path in framePaths) {
      if (_closed) break;
      final image = InputImage.fromFilePath(path);
      try {
        final faces = await _detector.processImage(image);
        if (faces.isEmpty) {
          scores.add(0.0);
          continue;
        }
        double best = 0.0;
        for (final face in faces) {
          final smiling = face.smilingProbability ?? 0.3;
          if (smiling > best) best = smiling;
        }
        scores.add(best);
      } catch (_) {
        scores.add(0.0);
      }
    }
    return scores;
  }

  Future<void> close() async {
    _closed = true;
    await _detector?.close();
  }
}
