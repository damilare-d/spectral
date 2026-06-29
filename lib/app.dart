import 'package:flutter/material.dart';

import 'core/router.dart';

class SpectralApp extends StatelessWidget {
  const SpectralApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Spectral',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      routerConfig: appRouter,
    );
  }
}
