import 'package:flutter/material.dart';

import '../design_system/tokens.dart';
import 'setup_screen.dart';

/// Cinematic-ish home (section 5). Phase 1 keeps it functional; full
/// cinematic treatment (parallax, animated background) is Polish-phase work.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [ReinosColors.background, Color(0xFF231A10)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('REINOS', style: ReinosTypography.title),
              const SizedBox(height: ReinosSpacing.sm),
              Text(
                'ESTRATÉGIA. CONHECIMENTO. CONQUISTA.',
                style: ReinosTypography.subtitle,
              ),
              const SizedBox(height: ReinosSpacing.xl),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: ReinosColors.gold,
                  foregroundColor: ReinosColors.background,
                  padding: const EdgeInsets.symmetric(
                    horizontal: ReinosSpacing.xl,
                    vertical: ReinosSpacing.md,
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SetupScreen()),
                  );
                },
                child: const Text('JOGAR'),
              ),
              const SizedBox(height: ReinosSpacing.md),
              Text(
                'Fundação Fase 1 — core loop jogável',
                style: ReinosTypography.label,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
