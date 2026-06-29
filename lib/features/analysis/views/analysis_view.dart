import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/locator.dart';
import '../../../services/highlight_detector.dart';
import '../../../services/whisper_model_service.dart';
import '../viewmodels/analysis_viewmodel.dart';

class AnalysisView extends StatefulWidget {
  final String videoPath;
  const AnalysisView({super.key, required this.videoPath});

  @override
  State<AnalysisView> createState() => _AnalysisViewState();
}

class _AnalysisViewState extends State<AnalysisView> {
  late final AnalysisViewModel _vm;
  Timer? _elapsedTimer;
  Duration _elapsed = Duration.zero;

  bool _started = false;
  bool _runSpeech = false; // off by default — user opts in

  @override
  void initState() {
    super.initState();
    _vm = AnalysisViewModel(
      detector: sl<HighlightDetector>(),
      modelSvc: sl<WhisperModelService>(),
    );
    _vm.addListener(_onVmChanged);
  }

  void _startAnalysis() {
    setState(() => _started = true);
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
    });
    _vm.startAnalysis(widget.videoPath, runSpeech: _runSpeech);
  }

  void _onVmChanged() {
    final result = _vm.result;
    if (result != null && mounted) {
      _vm.removeListener(_onVmChanged);
      context.go('/editor', extra: result);
    }
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _vm.removeListener(_onVmChanged);
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Analyse Video'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: _started
            ? ListenableBuilder(
                listenable: _vm,
                builder: (context, _) =>
                    _vm.error != null ? _buildError() : _buildProgress(),
              )
            : _buildConfig(),
      ),
    );
  }

  // ── Config card ─────────────────────────────────────────────────────────────

  Widget _buildConfig() {
    final filename = File(widget.videoPath).uri.pathSegments.last;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.movie_outlined,
            color: Colors.deepPurpleAccent, size: 48),
        const SizedBox(height: 20),
        Text(
          filename,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 32),

        // Options card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Analysis options',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              _OptionRow(
                icon: Icons.graphic_eq,
                label: 'Audio energy & beats',
                sublabel: 'Always included — fast',
                value: true,
                onChanged: null, // always on
              ),
              _OptionRow(
                icon: Icons.camera_alt,
                label: 'Scene changes',
                sublabel: 'Always included — fast',
                value: true,
                onChanged: null,
              ),
              _OptionRow(
                icon: Icons.face,
                label: 'Face & expression detection',
                sublabel: 'Always included — fast',
                value: true,
                onChanged: null,
              ),
              const Divider(color: Colors.white12, height: 24),
              _OptionRow(
                icon: Icons.mic,
                label: 'Speech recognition (Whisper)',
                sublabel: _runSpeech
                    ? 'ON — takes 3–10× video length on device'
                    : 'OFF — skip for screen recordings / no-speech videos',
                value: _runSpeech,
                onChanged: (v) => setState(() => _runSpeech = v),
                warningColor: _runSpeech,
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: _startAnalysis,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Start Analysis',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  // ── Progress ─────────────────────────────────────────────────────────────────

  Widget _buildProgress() {
    final stageHint = _stageHint(_vm.stageIndex, _vm.stageName);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.auto_awesome,
            color: Colors.deepPurpleAccent, size: 48),
        const SizedBox(height: 32),
        Text(
          _vm.stageName,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        LinearProgressIndicator(
          value: _vm.isDownloading ? _vm.downloadProgress : null,
          backgroundColor: Colors.white12,
          color: Colors.deepPurpleAccent,
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _vm.isDownloading
                  ? '${(_vm.downloadProgress * 100).toStringAsFixed(0)}%'
                  : 'Stage ${_vm.stageIndex + 1} of ${_vm.totalStages}',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
            Text(
              _formatElapsed(_elapsed),
              style: const TextStyle(color: Colors.white24, fontSize: 12),
            ),
          ],
        ),
        if (stageHint != null) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              stageHint,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildError() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
        const SizedBox(height: 16),
        Text(
          _vm.error!,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => context.pop(),
          child: const Text('Go back'),
        ),
      ],
    );
  }

  String? _stageHint(int stageIndex, String stageName) {
    if (stageName.contains('speech') || stageName.contains('Transcrib')) {
      return 'Running on-device speech recognition.\n'
          'This takes 3–10× the video duration on mobile CPU.';
    }
    return null;
  }

  static String _formatElapsed(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return m > 0 ? '${m}m ${s}s' : '${s}s';
  }
}

// ── Option row widget ─────────────────────────────────────────────────────────

class _OptionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final bool value;
  final void Function(bool)? onChanged;
  final bool warningColor;

  const _OptionRow({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.value,
    required this.onChanged,
    this.warningColor = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon,
              size: 18,
              color: enabled
                  ? (warningColor ? Colors.amber : Colors.deepPurpleAccent)
                  : Colors.white24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: enabled ? Colors.white : Colors.white38,
                        fontSize: 13)),
                Text(sublabel,
                    style: TextStyle(
                        color: warningColor
                            ? Colors.amber.withAlpha(180)
                            : Colors.white24,
                        fontSize: 10)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.deepPurpleAccent,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}
