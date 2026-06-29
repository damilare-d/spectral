import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/locator.dart';
import '../../../models/video_segment.dart';
import '../../../services/ffmpeg_service.dart';
import '../viewmodels/export_viewmodel.dart';

class ExportView extends StatefulWidget {
  final String videoPath;
  final List<VideoSegment> segments;

  const ExportView({
    super.key,
    required this.videoPath,
    required this.segments,
  });

  @override
  State<ExportView> createState() => _ExportViewState();
}

class _ExportViewState extends State<ExportView> {
  late final ExportViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = ExportViewModel(ffmpegService: sl<FfmpegService>());
    _vm.startExport(widget.videoPath, widget.segments);
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Export'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: ListenableBuilder(
          listenable: _vm,
          builder: (context, _) {
            if (_vm.error != null) return _buildError(context);
            if (_vm.isExporting) return _buildProgress();
            return _buildDone(context);
          },
        ),
      ),
    );
  }

  Widget _buildProgress() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.movie_creation,
            color: Colors.deepPurpleAccent, size: 48),
        const SizedBox(height: 24),
        const Text('Stitching clips…',
            style: TextStyle(color: Colors.white, fontSize: 16),
            textAlign: TextAlign.center),
        const SizedBox(height: 16),
        LinearProgressIndicator(
          value: _vm.progress > 0 ? _vm.progress : null,
          backgroundColor: Colors.white12,
          color: Colors.deepPurpleAccent,
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
      ],
    );
  }

  Widget _buildDone(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.check_circle, color: Colors.greenAccent, size: 56),
        const SizedBox(height: 24),
        Text(
          'Highlight reel ready (${_vm.outputSizeMb} MB)',
          style: const TextStyle(color: Colors.white, fontSize: 16),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        ElevatedButton.icon(
          onPressed: _vm.share,
          icon: const Icon(Icons.share),
          label: const Text('Share'),
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              padding: const EdgeInsets.symmetric(vertical: 14)),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () async {
            final dest = await _vm.saveToDownloads();
            if (dest != null && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Saved to $dest')),
              );
            }
          },
          icon: const Icon(Icons.download),
          label: const Text('Save to Downloads'),
          style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14)),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => context.go('/'),
          child:
              const Text('Back to home', style: TextStyle(color: Colors.white38)),
        ),
      ],
    );
  }

  Widget _buildError(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
        const SizedBox(height: 16),
        Text(_vm.error!,
            style: const TextStyle(color: Colors.white70),
            textAlign: TextAlign.center),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => context.pop(),
          child: const Text('Go back'),
        ),
      ],
    );
  }
}
