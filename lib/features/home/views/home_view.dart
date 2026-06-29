import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../viewmodels/home_viewmodel.dart';

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
                _ModeCard(
                  icon: Icons.graphic_eq,
                  title: 'Live Visualizer',
                  subtitle: 'Real-time mic FFT with GPU shaders',
                  onTap: _vm.isPickingFile ? null : () => context.push('/visualizer'),
                ),
                const SizedBox(height: 16),
                _ModeCard(
                  icon: Icons.auto_awesome_mosaic,
                  title: 'Video Highlights',
                  subtitle: 'AI-powered multi-cut sequence from any video',
                  onTap: _vm.isPickingFile ? null : () => _pickAndNavigate(context),
                ),
                const Spacer(),
                if (_vm.isPickingFile)
                  const Center(child: CircularProgressIndicator(color: Colors.deepPurpleAccent)),
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

// ── Reusable card widget ──────────────────────────────────────────────────────

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withAlpha(77),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.deepPurpleAccent, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white24),
            ],
          ),
        ),
      ),
    );
  }
}
