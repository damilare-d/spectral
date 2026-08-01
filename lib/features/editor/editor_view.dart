import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../models/analysis_result.dart';
import '../../models/video_segment.dart';
import '../../widgets/segment_timeline.dart';
import 'editor_viewmodel.dart';
import 'widgets/quotes_card.dart';
import 'widgets/score_line.dart';
import 'widgets/segment_card.dart';
import 'widgets/segment_filter_chip.dart';

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

  static const _kPresetTags = [
    'Action', 'Comedy', 'Drama', 'Romance',
    'Suspense', 'Scenic', 'Dialogue', 'Music',
  ];

  void _export() {
    final toExport = _vm.filtered;
    if (toExport.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No clips in current filter to export')),
      );
      return;
    }
    context.push('/render', extra: (
      result: _vm.result,
      segments: List<VideoSegment>.from(toExport),
    ));
  }

  Widget _buildCard(VideoSegment seg, int i) {
    final isActive = _vm.activeSegment?.startMs == seg.startMs;
    return SegmentCard(
      key: ValueKey(seg.startMs),
      seg: seg,
      index: i + 1,
      isActive: isActive,
      onTap: () => _vm.seekTo(seg),
      onRemove: () => _vm.removeSegment(seg),
      onTrimStart: (d) => _vm.trimStart(seg, d),
      onTrimEnd: (d) => _vm.trimEnd(seg, d),
      onShowScores: () => _showScoreSheet(context, seg),
      onSetTag: () => _showTagPicker(seg),
    );
  }

  void _showTagPicker(VideoSegment seg) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, _) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add label',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in _kPresetTags)
                    ActionChip(
                      label: Text(tag),
                      backgroundColor: seg.tag == tag
                          ? Colors.deepPurple
                          : Colors.white10,
                      labelStyle: TextStyle(
                          color: seg.tag == tag ? Colors.white : Colors.white70,
                          fontSize: 13),
                      onPressed: () {
                        _vm.setTag(seg, seg.tag == tag ? null : tag);
                        Navigator.pop(ctx);
                      },
                    ),
                  if (seg.tag != null)
                    ActionChip(
                      label: const Text('Clear label'),
                      backgroundColor: Colors.red.withAlpha(50),
                      labelStyle: const TextStyle(
                          color: Colors.redAccent, fontSize: 13),
                      onPressed: () {
                        _vm.setTag(seg, null);
                        Navigator.pop(ctx);
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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

  double _scrubFraction() {
    final seg = _vm.activeSegment;
    if (seg == null || seg.durationMs <= 0) return 0.0;
    return ((_vm.positionMs - seg.startMs) / seg.durationMs).clamp(0.0, 1.0);
  }

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
            builder: (_, __) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withAlpha(60),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_vm.contentType.icon} ${_vm.contentType.label.split(' ').first}',
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _vm.selected.isEmpty ? null : _export,
                  icon: const Icon(Icons.movie_creation,
                      color: Colors.deepPurpleAccent),
                  label: const Text('Render',
                      style: TextStyle(color: Colors.deepPurpleAccent)),
                ),
              ],
            ),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _vm,
        builder: (context, _) => Column(
          children: [
            // ── Video preview ───────────────────────────────────────────────
            // Bound height to 40 % of screen so the rest of the editor fits.
            // Column gives AspectRatio unbounded height; on a 1366-wide screen
            // 16:9 would demand 768 px, overflowing a 689 px available column.
            Builder(builder: (ctx) {
              final maxH =
                  (MediaQuery.sizeOf(ctx).height * 0.40).clamp(160.0, 380.0);
              return Container(
                width: double.infinity,
                height: maxH,
                color: const Color(0xFF111111),
                child: Center(
                  child: AspectRatio(
                    aspectRatio: _vm.videoReady
                        ? _vm.videoController.value.aspectRatio
                        : 16 / 9,
                    child: _vm.videoReady
                        ? VideoPlayer(_vm.videoController)
                        : Center(
                            child: switch (_vm.videoError) {
                              null => const CircularProgressIndicator(
                                  color: Colors.deepPurpleAccent),
                              // Remux / encode in progress
                              String e when e.startsWith('Preparing') ||
                                      e.startsWith('Encoding') =>
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const CircularProgressIndicator(
                                        color: Colors.deepPurpleAccent),
                                    const SizedBox(height: 12),
                                    Text(e,
                                        style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 11)),
                                  ],
                                ),
                              // Permanent failure
                              _ => Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.videocam_off,
                                        color: Colors.white24, size: 32),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Preview unavailable',
                                      style: TextStyle(
                                          color: Colors.white38, fontSize: 11),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                            },
                          ),
                  ),
                ),
              );
            }),

            // ── Playback controls ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.skip_previous, color: Colors.white70),
                    onPressed: _vm.videoReady ? _prevSegment : null,
                  ),
                  IconButton(
                    iconSize: 36,
                    icon: Icon(
                      _vm.isPlaying ? Icons.pause : Icons.play_arrow,
                      color: _vm.videoReady ? Colors.white : Colors.white24,
                    ),
                    onPressed: _vm.videoReady ? _vm.togglePlayPause : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next, color: Colors.white70),
                    onPressed: _vm.videoReady ? _nextSegment : null,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _activeTimeLabel(),
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  const Spacer(),
                  if (_vm.activeSegment != null)
                    Text(
                      '${(_vm.activeSegment!.durationMs / 1000).toStringAsFixed(1)}s clip',
                      style: const TextStyle(color: Colors.white24, fontSize: 11),
                    ),
                ],
              ),
            ),

            // ── Scrub slider ────────────────────────────────────────────────
            if (_vm.activeSegment != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 14),
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
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
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ),
              ),

            // ── Top quotes ─────────────────────────────────────────────────
            if (_vm.topQuotes.isNotEmpty)
              QuotesCard(
                quotes: _vm.topQuotes,
                onSeek: _vm.seekToPosition,
              ),

            // ── Filter chips ────────────────────────────────────────────────
            if (_vm.selected.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                child: Row(
                  children: [
                    SegmentFilterChip(
                      label: 'All (${_vm.selected.length})',
                      selected: _vm.activeFilter == null,
                      onTap: () => _vm.setFilter(null),
                    ),
                    if (_vm.selected
                        .any((s) => s.tag == null || s.tag!.isEmpty))
                      SegmentFilterChip(
                        label: 'Untagged',
                        selected: _vm.activeFilter == '',
                        onTap: () => _vm.setFilter(''),
                      ),
                    for (final tag in _vm.allTags)
                      SegmentFilterChip(
                        label: tag,
                        selected: _vm.activeFilter == tag,
                        onTap: () => _vm.setFilter(tag),
                      ),
                  ],
                ),
              ),

            // ── Segment cards ───────────────────────────────────────────────
            Expanded(
              child: _vm.filtered.isEmpty
                  ? Center(
                      child: Text(
                        _vm.selected.isEmpty
                            ? 'No segments selected'
                            : 'No clips match this filter',
                        style: const TextStyle(color: Colors.white38),
                      ),
                    )
                  // Reorder only makes sense on the full unfiltered list.
                  : _vm.activeFilter == null
                      ? ReorderableListView.builder(
                          padding:
                              const EdgeInsets.fromLTRB(16, 8, 16, 80),
                          itemCount: _vm.filtered.length,
                          onReorder: _vm.reorder,
                          itemBuilder: (_, i) =>
                              _buildCard(_vm.filtered[i], i),
                        )
                      : ListView.builder(
                          padding:
                              const EdgeInsets.fromLTRB(16, 8, 16, 80),
                          itemCount: _vm.filtered.length,
                          itemBuilder: (_, i) =>
                              _buildCard(_vm.filtered[i], i),
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: ListenableBuilder(
        listenable: _vm,
        builder: (_, __) {
          final count = _vm.filtered.length;
          final filterLabel = _vm.activeFilter != null
              ? ' (${_vm.activeFilter!.isEmpty ? 'untagged' : _vm.activeFilter})'
              : '';
          return FloatingActionButton.extended(
            onPressed: _export,
            backgroundColor: Colors.deepPurple,
            icon: const Icon(Icons.movie_filter),
            label: Text(
                'Render $count clip${count == 1 ? '' : 's'}$filterLabel'),
          );
        },
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
            ScoreLine('Energy', seg.energyScore, Colors.orange),
            ScoreLine('Onsets / beats', seg.onsetScore, Colors.amber),
            ScoreLine('Scene change', seg.sceneScore, Colors.lightBlue),
            ScoreLine('Speech', seg.speechScore, Colors.greenAccent),
            ScoreLine('Face / expression', seg.faceScore, Colors.pinkAccent),
            if (seg.hookScore > 0)
              ScoreLine('Hook quality', seg.hookScore, Colors.tealAccent),
            const Divider(color: Colors.white12, height: 24),
            ScoreLine('Composite', seg.compositeScore,
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
