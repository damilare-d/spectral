import 'package:flutter/material.dart';

import '../../core/locator.dart';
import '../../models/analysis_result.dart';
import '../../models/render_config.dart';
import '../../models/social_format.dart';
import '../../models/video_segment.dart';
import '../../services/ffmpeg_service.dart';
import '../../services/render_service.dart';
import 'render_viewmodel.dart';
import 'widgets/clip_progress_card.dart';
import 'widgets/render_option_toggle.dart';
import 'widgets/social_format_picker.dart';

class RenderView extends StatefulWidget {
  final AnalysisResult result;
  final List<VideoSegment> segments;

  const RenderView({super.key, required this.result, required this.segments});

  @override
  State<RenderView> createState() => _RenderViewState();
}

class _RenderViewState extends State<RenderView> {
  late final RenderViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = RenderViewModel(
      result: widget.result,
      segments: widget.segments,
      config: sl<RenderConfig>(),
      renderService: sl<RenderService>(),
      ffmpegService: sl<FfmpegService>(),
    );
    _vm.addListener(_onVmChanged);
  }

  void _onVmChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
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
        title: Text(
          _vm.phase == RenderPhase.config
              ? 'Render ${widget.segments.length} clip${widget.segments.length == 1 ? '' : 's'}'
              : 'Rendering…',
        ),
        actions: [
          if (_vm.phase == RenderPhase.done && _vm.doneCount > 0)
            TextButton.icon(
              onPressed: _vm.shareAll,
              icon: const Icon(Icons.share, color: Colors.deepPurpleAccent),
              label: const Text('Share all',
                  style: TextStyle(color: Colors.deepPurpleAccent)),
            ),
        ],
      ),
      body: _vm.phase == RenderPhase.config
          ? _buildConfig()
          : _buildProgress(),
    );
  }

  // ── Config phase ──────────────────────────────────────────────────────────

  Widget _buildConfig() {
    final cfg = _vm.config;
    return ListenableBuilder(
      listenable: cfg,
      builder: (_, __) => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Format ──────────────────────────────────────────────────
            _sectionLabel('Format'),
            const SizedBox(height: 10),
            SocialFormatPicker(
              selected: cfg.format,
              onChanged: cfg.setFormat,
            ),

            const SizedBox(height: 24),

            // ── Output mode ──────────────────────────────────────────────
            _sectionLabel('Output mode'),
            const SizedBox(height: 10),
            _modeCard(
              label: 'Individual clips',
              sublabel: 'One video file per clip — best for batch posting',
              selected: cfg.batchMode,
              onTap: () => cfg.setBatchMode(true),
            ),
            const SizedBox(height: 8),
            _modeCard(
              label: 'Joined reel',
              sublabel: 'All clips concatenated into one video',
              selected: !cfg.batchMode,
              onTap: () => cfg.setBatchMode(false),
            ),

            const SizedBox(height: 24),

            // ── Enhancements ─────────────────────────────────────────────
            _sectionLabel('Enhancements'),
            const SizedBox(height: 10),
            RenderOptionToggle(
              icon: Icons.closed_caption,
              label: 'Auto-captions',
              sublabel: result.whisperSegments.isEmpty
                  ? 'Requires speech recognition — re-analyse with Whisper'
                  : 'Burns subtitles from Whisper transcript',
              value: cfg.captions && result.whisperSegments.isNotEmpty,
              enabled: result.whisperSegments.isNotEmpty,
              onChanged: cfg.setCaptions,
            ),
            if (cfg.captions && result.whisperSegments.isNotEmpty) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: _captionStyleChips(cfg),
              ),
            ],

            RenderOptionToggle(
              icon: Icons.title,
              label: 'Hook text overlay',
              sublabel: result.topQuotes.isEmpty
                  ? 'No quotes extracted — re-analyse with speech'
                  : '"${result.topQuotes.first.text.trim()}"',
              value: cfg.hookText && result.topQuotes.isNotEmpty,
              enabled: result.topQuotes.isNotEmpty,
              onChanged: cfg.setHookText,
            ),

            RenderOptionToggle(
              icon: Icons.crop,
              label: 'Vertical reframe (9:16)',
              sublabel: cfg.format.isVertical
                  ? 'Crops to portrait for ${cfg.format.label}'
                  : 'Not needed for ${cfg.format.label} (landscape)',
              value: cfg.verticalCrop,
              enabled: cfg.format.isVertical,
              onChanged: cfg.setVerticalCrop,
            ),

            RenderOptionToggle(
              icon: Icons.flip_camera_android,
              label: 'Transitions',
              sublabel: 'Fade between clips (joined reel only)',
              value: cfg.transitions && !cfg.batchMode,
              enabled: !cfg.batchMode,
              onChanged: cfg.setTransitions,
            ),

            const SizedBox(height: 32),

            // ── Start button ─────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _startRender,
                icon: const Icon(Icons.movie_filter),
                label: Text(
                  cfg.batchMode
                      ? 'Render ${widget.segments.length} clips'
                      : 'Render joined reel',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  AnalysisResult get result => widget.result;

  Widget _captionStyleChips(RenderConfig cfg) {
    return Row(
      children: [
        for (final style in CaptionStyle.values)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => cfg.setCaptionStyle(style),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: cfg.captionStyle == style
                      ? Colors.deepPurple
                      : Colors.white10,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  style.label,
                  style: TextStyle(
                    color: cfg.captionStyle == style
                        ? Colors.white
                        : Colors.white54,
                    fontSize: 12,
                    fontWeight: cfg.captionStyle == style
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _modeCard({
    required String label,
    required String sublabel,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? Colors.deepPurple.withAlpha(80) : const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? Colors.deepPurpleAccent : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? Colors.deepPurpleAccent : Colors.white38,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          color: selected ? Colors.white : Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  Text(sublabel,
                      style:
                          const TextStyle(color: Colors.white38, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text.toUpperCase(),
        style: const TextStyle(
            color: Colors.white38,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2),
      );

  // ── Progress phase ────────────────────────────────────────────────────────

  Widget _buildProgress() {
    return Column(
      children: [
        // Summary bar
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          color: const Color(0xFF111122),
          child: Text(
            _vm.phase == RenderPhase.done
                ? '${_vm.doneCount} done${_vm.failCount > 0 ? ', ${_vm.failCount} failed' : ''}'
                : 'Rendering ${_vm.doneCount + 1} of ${widget.segments.length}…',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
            itemCount: _vm.clips.length,
            itemBuilder: (_, i) => ClipProgressCard(
              clip: _vm.clips[i],
              onShare: () => _vm.shareClip(_vm.clips[i]),
              onSave: () => _vm.saveClip(_vm.clips[i]),
              sizeMb: _vm.clips[i].isDone
                  ? _vm.clipSizeMb(_vm.clips[i])
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  void _startRender() {
    _vm.startRender();
  }
}
