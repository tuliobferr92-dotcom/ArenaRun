import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ui/design_system/tokens.dart';
import 'ui/screens/home_screen.dart';

void main() {
  runApp(const ProviderScope(child: ReinosApp()));
}

class ReinosApp extends StatelessWidget {
  const ReinosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'REINOS',
      debugShowCheckedModeBanner: false,
      theme: buildReinosTheme(),
      home: const HomeScreen(),
    );
  }
}
