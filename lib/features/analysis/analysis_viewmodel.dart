import 'package:flutter/foundation.dart';

import '../../models/analysis_result.dart';
import '../../models/content_type.dart';
import '../../services/highlight_detector.dart';
import '../../services/whisper_model_service.dart';

class AnalysisViewModel extends ChangeNotifier {
  final HighlightDetector _detector;
  final WhisperModelService _modelSvc;

  AnalysisViewModel({
    required HighlightDetector detector,
    required WhisperModelService modelSvc,
  })  : _detector = detector,
        _modelSvc = modelSvc;

  String _stageName = 'Initialising…';
  double _stageProgress = 0.0;
  int _stageIndex = 0;
  int _totalStages = 5;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String? _error;
  AnalysisResult? _result;

  String get stageName => _stageName;
  double get stageProgress => _stageProgress;
  int get stageIndex => _stageIndex;
  int get totalStages => _totalStages;
  bool get isDownloading => _isDownloading;
  double get downloadProgress => _downloadProgress;
  String? get error => _error;
  AnalysisResult? get result => _result;

  Future<void> startAnalysis(
    String videoPath, {
    bool runSpeech = false,
    ContentType? contentTypeOverride,
  }) async {
    if (runSpeech) {
      final modelReady = await _modelSvc.isDownloaded;
      if (!modelReady) {
        _isDownloading = true;
        _stageName = 'Downloading Whisper model (~75 MB)…';
        notifyListeners();
        try {
          await _modelSvc.ensureModel(onProgress: (p) {
            _downloadProgress = p;
            notifyListeners();
          });
        } catch (e) {
          _error = 'Model download failed: $e';
          notifyListeners();
          return;
        }
        _isDownloading = false;
        notifyListeners();
      }
    }

    _detector
        .analyze(videoPath,
            runSpeech: runSpeech,
            contentTypeOverride: contentTypeOverride)
        .listen(
      (event) {
        switch (event) {
          case AnalysisStage():
            _stageName = event.label;
            _stageProgress = event.fraction;
            _stageIndex = event.stageIndex;
            _totalStages = event.totalStages;
          case AnalysisComplete():
            _result = event.result;
          case AnalysisError():
            _error = event.message;
        }
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        notifyListeners();
      },
    );
  }
}
