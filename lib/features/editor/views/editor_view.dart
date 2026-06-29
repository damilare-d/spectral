import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../../models/analysis_result.dart';
import '../../../models/video_segment.dart';
import '../../../widgets/segment_timeline.dart';
import '../viewmodels/editor_viewmodel.dart';

class EditorView extends StatefulWidget {
  final AnalysisResult result;
  const EditorView({super.key, required this.result});

  @override
  State<EditorView> createState() => _EditorViewState();
}

class _EditorViewState extends State<EditorView> {
  late final EditorViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = EditorViewModel();
    _vm.init(widget.result);
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  void _export() {
    if (_vm.selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one segment')),
      );
      return;
    }
    context.push('/export', extra: (
      videoPath: _vm.videoPath,
      segments: List<VideoSegment>.from(_vm.selected),
    ));
  }

  void _prevSegment() {
    final active = _vm.activeSegment;
    if (active == null) {
      if (_vm.selected.isNotEmpty) _vm.seekTo(_vm.selected.first);
      return;
    }
    final idx = _vm.selected.indexWhere((s) => s.startMs == active.startMs);
    if (idx > 0) _vm.seekTo(_vm.selected[idx - 1]);
  }

  void _nextSegment() {
    final active = _vm.activeSegment;
    if (active == null) {
      if (_vm.selected.isNotEmpty) _vm.seekTo(_vm.selected.first);
      return;
    }
    final idx = _vm.selected.indexWhere((s) => s.startMs == active.startMs);
    if (idx >= 0 && idx < _vm.selected.length - 1) {
      _vm.seekTo(_vm.selected[idx + 1]);
    }
  }

  /// Current scrub fraction within the active segment (0.0–1.0).
  double _scrubFraction() {
    final seg = _vm.activeSegment;
    if (seg == null || seg.durationMs <= 0) return 0.0;
    final fraction =
        (_vm.positionMs - seg.startMs) / seg.durationMs;
    return fraction.clamp(0.0, 1.0);
  }

  /// Time string: "1:23 / 1:30"
  String _activeTimeLabel() {
    final seg = _vm.activeSegment;
    if (seg == null) return '-- / --';
    return '${_formatMs(_vm.positionMs)} / ${seg.endLabel}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Edit Highlights'),
        actions: [
          ListenableBuilder(
            listenable: _vm,
            builder: (_, __) => TextButton.icon(
              onPressed: _vm.selected.isEmpty ? null : _export,
              icon: const Icon(Icons.movie_creation,
                  color: Colors.deepPurpleAccent),
              label: const Text('Export',
                  style: TextStyle(color: Colors.deepPurpleAccent)),
            ),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _vm,
        builder: (context, _) => Column(
          children: [
            // ── Video preview ───────────────────────────────────────────────
            AspectRatio(
              aspectRatio: _vm.videoReady
                  ? _vm.videoController.value.aspectRatio
                  : 16 / 9,
              child: _vm.videoReady
                  ? VideoPlayer(_vm.videoController)
                  : const ColoredBox(
                      color: Color(0xFF111111),
                      child: Center(
                        child: CircularProgressIndicator(
                            color: Colors.deepPurpleAccent),
                      ),
                    ),
            ),

            // ── Playback controls ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.skip_previous,
                        color: Colors.white70),
                    onPressed: _vm.videoReady ? _prevSegment : null,
                  ),
                  IconButton(
                    iconSize: 36,
                    icon: Icon(
                      _vm.isPlaying ? Icons.pause : Icons.play_arrow,
                      color: _vm.videoReady
                          ? Colors.white
                          : Colors.white24,
                    ),
                    onPressed:
                        _vm.videoReady ? _vm.togglePlayPause : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next,
                        color: Colors.white70),
                    onPressed: _vm.videoReady ? _nextSegment : null,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _activeTimeLabel(),
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 13),
                  ),
                  const Spacer(),
                  if (_vm.activeSegment != null)
                    Text(
                      '${(_vm.activeSegment!.durationMs / 1000).toStringAsFixed(1)}s clip',
                      style: const TextStyle(
                          color: Colors.white24, fontSize: 11),
                    ),
                ],
              ),
            ),

            // ── Scrub slider (only when a segment is active) ────────────────
            if (_vm.activeSegment != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 14),
                    activeTrackColor: Colors.deepPurpleAccent,
                    inactiveTrackColor: Colors.white12,
                    thumbColor: Colors.deepPurpleAccent,
                    overlayColor: Colors.deepPurple.withAlpha(60),
                  ),
                  child: Slider(
                    value: _scrubFraction(),
                    onChanged: _vm.seekWithinActive,
                  ),
                ),
              ),

            // ── Timeline ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: SizedBox(
                height: 36,
                child: SegmentTimeline(
                  allSegments: _vm.allSegments,
                  selected: _vm.selected,
                  videoDurationMs: _vm.videoDurationMs,
                  currentPositionMs: _vm.positionMs,
                  onTap: _vm.seekTo,
                ),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_formatMs(0),
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 10)),
                  Text(_formatMs(_vm.videoDurationMs),
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 10)),
                ],
              ),
            ),

            // ── Transcript preview ──────────────────────────────────────────
            if (_vm.transcript.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111122),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _vm.transcript,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 11),
                  ),
                ),
              ),

            // ── Segment cards ───────────────────────────────────────────────
            Expanded(
              child: _vm.selected.isEmpty
                  ? const Center(
                      child: Text('No segments selected',
                          style: TextStyle(color: Colors.white38)))
                  : ReorderableListView.builder(
                      padding:
                          const EdgeInsets.fromLTRB(16, 8, 16, 80),
                      itemCount: _vm.selected.length,
                      onReorder: _vm.reorder,
                      itemBuilder: (ctx, i) {
                        final seg = _vm.selected[i];
                        final isActive =
                            _vm.activeSegment?.startMs == seg.startMs;
                        return _SegmentCard(
                          key: ValueKey(seg.startMs),
                          seg: seg,
                          index: i + 1,
                          isActive: isActive,
                          onTap: () => _vm.seekTo(seg),
                          onRemove: () => _vm.removeSegment(seg),
                          onTrimStart: (d) => _vm.trimStart(seg, d),
                          onTrimEnd: (d) => _vm.trimEnd(seg, d),
                          onShowScores: () =>
                              _showScoreSheet(context, seg),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: ListenableBuilder(
        listenable: _vm,
        builder: (_, __) => FloatingActionButton.extended(
          onPressed: _export,
          backgroundColor: Colors.deepPurple,
          icon: const Icon(Icons.movie_filter),
          label: Text(
              'Export ${_vm.selected.length} clip${_vm.selected.length == 1 ? '' : 's'}'),
        ),
      ),
    );
  }

  void _showScoreSheet(BuildContext context, VideoSegment seg) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${seg.startLabel} – ${seg.endLabel}  •  Score breakdown',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            _ScoreLine('Energy', seg.energyScore, Colors.orange),
            _ScoreLine('Onsets / beats', seg.onsetScore, Colors.amber),
            _ScoreLine('Scene change', seg.sceneScore, Colors.lightBlue),
            _ScoreLine('Speech', seg.speechScore, Colors.greenAccent),
            _ScoreLine('Face / expression', seg.faceScore, Colors.pinkAccent),
            const Divider(color: Colors.white12, height: 24),
            _ScoreLine('Composite', seg.compositeScore,
                Colors.deepPurpleAccent,
                bold: true),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  static String _formatMs(int ms) {
    final total = ms ~/ 1000;
    final m = total ~/ 60;
    final s = total % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

// ── Score line (used in bottom sheet) ─────────────────────────────────────────

class _ScoreLine extends StatelessWidget {
  final String label;
  final double score;
  final Color color;
  final bool bold;

  const _ScoreLine(this.label, this.score, this.color,
      {this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: bold ? Colors.white : Colors.white70,
                fontSize: 12,
                fontWeight:
                    bold ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          Expanded(
            child: LinearProgressIndicator(
              value: score,
              backgroundColor: Colors.white12,
              color: color,
              minHeight: bold ? 6 : 4,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            score.toStringAsFixed(2),
            style: TextStyle(
              color: bold ? Colors.white : Colors.white38,
              fontSize: 11,
              fontWeight:
                  bold ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Segment card ──────────────────────────────────────────────────────────────

class _SegmentCard extends StatelessWidget {
  final VideoSegment seg;
  final int index;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final void Function(int deltaMs) onTrimStart;
  final void Function(int deltaMs) onTrimEnd;
  final VoidCallback onShowScores;

  const _SegmentCard({
    super.key,
    required this.seg,
    required this.index,
    required this.isActive,
    required this.onTap,
    required this.onRemove,
    required this.onTrimStart,
    required this.onTrimEnd,
    required this.onShowScores,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isActive
          ? const Color(0xFF2A1A4E) // active highlight
          : const Color(0xFF1A1A2E),
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: isActive
            ? const BorderSide(color: Colors.deepPurpleAccent, width: 1)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onShowScores,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header row ─────────────────────────────────────────────
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: isActive
                        ? Colors.deepPurple
                        : Colors.deepPurple.withAlpha(80),
                    child: Text('$index',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${seg.startLabel} – ${seg.endLabel}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                        ),
                        Text(
                          '${(seg.durationMs / 1000).toStringAsFixed(1)}s  •  score ${seg.compositeScore.toStringAsFixed(2)}',
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close,
                        color: Colors.white38, size: 18),
                    onPressed: onRemove,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),

              // ── Score bar ───────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 8),
                child: _ScoreBar(score: seg.compositeScore),
              ),

              // ── Trim controls ───────────────────────────────────────────
              Row(
                children: [
                  const Text('Start',
                      style: TextStyle(
                          color: Colors.white38, fontSize: 10)),
                  const SizedBox(width: 4),
                  _TrimButton(
                      label: '−1s', onTap: () => onTrimStart(1000)),
                  _TrimButton(
                      label: '+1s', onTap: () => onTrimStart(-1000)),
                  const Spacer(),
                  const Text('End',
                      style: TextStyle(
                          color: Colors.white38, fontSize: 10)),
                  const SizedBox(width: 4),
                  _TrimButton(
                      label: '−1s', onTap: () => onTrimEnd(-1000)),
                  _TrimButton(
                      label: '+1s', onTap: () => onTrimEnd(1000)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreBar extends StatelessWidget {
  final double score;
  const _ScoreBar({required this.score});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: LinearProgressIndicator(
            value: score,
            backgroundColor: Colors.white12,
            color: Color.lerp(Colors.orange, Colors.greenAccent, score)!,
            minHeight: 3,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(score.toStringAsFixed(2),
            style:
                const TextStyle(color: Colors.white38, fontSize: 10)),
      ],
    );
  }
}

class _TrimButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _TrimButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label,
            style: const TextStyle(
                color: Colors.white54, fontSize: 10)),
      ),
    );
  }
}
