import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'home_viewmodel.dart';
import 'widgets/mode_card.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  late final HomeViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = HomeViewModel();
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32),
                const Text(
                  'Spectral',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Audio • Video • Intelligence',
                  style: TextStyle(color: Colors.white38, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                ModeCard(
                  icon: Icons.graphic_eq,
                  title: 'Live Visualizer',
                  subtitle: 'Real-time mic FFT with GPU shaders',
                  onTap: _vm.isPickingFile
                      ? null
                      : () => context.push('/visualizer'),
                ),
                const SizedBox(height: 16),
                ModeCard(
                  icon: Icons.auto_awesome_mosaic,
                  title: 'Video Highlights',
                  subtitle: 'AI-powered multi-cut sequence from any video',
                  onTap: _vm.isPickingFile
                      ? null
                      : () => _pickAndNavigate(context),
                ),
                const Spacer(),
                if (_vm.isPickingFile)
                  const Center(
                    child: CircularProgressIndicator(
                      color: Colors.deepPurpleAccent,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndNavigate(BuildContext context) async {
    final path = await _vm.pickVideo();
    if (path != null && context.mounted) {
      context.push('/analysis', extra: path);
    }
  }
}
