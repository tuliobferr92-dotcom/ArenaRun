import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/save_game_service.dart';
import '../design_system/tokens.dart';
import '../game_controller.dart';
import 'game_screen.dart';
import 'setup_screen.dart';

/// Cinematic-ish home (section 5). Phase 1 keeps it functional; full
/// cinematic treatment (parallax, animated background) is Polish-phase work.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  List<SaveSummary> _saves = const [];

  @override
  void initState() {
    super.initState();
    _refreshSaves();
  }

  Future<void> _refreshSaves() async {
    final saves = await ref.read(gameControllerProvider.notifier).listSaves();
    if (mounted) setState(() => _saves = saves);
  }

  Future<void> _continueMatch() async {
    if (_saves.isEmpty) return;
    await ref.read(gameControllerProvider.notifier).loadMatch(_saves.first.gameId);
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GameScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final hasSave = _saves.isNotEmpty;
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
                  Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const SetupScreen()))
                      .then((_) => _refreshSaves());
                },
                child: const Text('JOGAR'),
              ),
              const SizedBox(height: ReinosSpacing.sm),
              TextButton(
                onPressed: hasSave ? _continueMatch : null,
                child: Text(
                  hasSave
                      ? 'CONTINUAR PARTIDA (turno ${_saves.first.turnNumber})'
                      : 'CONTINUAR PARTIDA',
                  style: TextStyle(
                    color: hasSave ? ReinosColors.parchment : ReinosColors.parchment.withValues(alpha: 0.4),
                  ),
                ),
              ),
              const SizedBox(height: ReinosSpacing.md),
              Text(
                'Fundação Fase 1/2 — core loop + save/load jogáveis',
                style: ReinosTypography.label,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
