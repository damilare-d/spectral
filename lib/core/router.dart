import 'package:go_router/go_router.dart';

import '../features/home/home_view.dart';
import '../features/visualizer/visualizer_view.dart';
import '../features/analysis/analysis_view.dart';
import '../features/editor/editor_view.dart';
import '../features/export/export_view.dart';
import '../models/analysis_result.dart';
import '../models/video_segment.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'home',
      builder: (_, __) => const HomeView(),
    ),
    GoRoute(
      path: '/visualizer',
      name: 'visualizer',
      builder: (_, __) => const VisualizerView(),
    ),
    GoRoute(
      path: '/analysis',
      name: 'analysis',
      builder: (_, state) => AnalysisView(
        videoPath: state.extra as String,
      ),
    ),
    GoRoute(
      path: '/editor',
      name: 'editor',
      builder: (_, state) => EditorView(
        result: state.extra as AnalysisResult,
      ),
    ),
    GoRoute(
      path: '/export',
      name: 'export',
      builder: (_, state) {
        final args =
            state.extra as ({String videoPath, List<VideoSegment> segments});
        return ExportView(videoPath: args.videoPath, segments: args.segments);
      },
    ),
  ],
);
