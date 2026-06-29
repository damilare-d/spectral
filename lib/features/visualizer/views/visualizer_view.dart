import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../ui/visualizer_painter.dart';
import '../viewmodels/visualizer_viewmodel.dart';

/// The View owns only the Ticker (a UI/animation concern).
/// All state and logic live in [VisualizerViewModel].
class VisualizerView extends StatefulWidget {
  const VisualizerView({super.key});

  @override
  State<VisualizerView> createState() => _VisualizerViewState();
}

class _VisualizerViewState extends State<VisualizerView>
    with SingleTickerProviderStateMixin {
  late final VisualizerViewModel _vm;
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _vm = VisualizerViewModel();
    _vm.init();
    _ticker = createTicker(_vm.onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        if (_vm.permissionDenied) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: Text(
                'Microphone permission denied.\nGrant it in Settings and restart.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
            ),
          );
        }

        final shader  = _vm.shader;
        final texture = _vm.fftTexture;

        if (shader == null || texture == null) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          backgroundColor: Colors.black,
          body: CustomPaint(
            painter: VisualizerPainter(
              shader: shader,
              fftTexture: texture,
              time: _vm.time,
            ),
            size: Size.infinite,
          ),
        );
      },
    );
  }
}
