import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../game_engine/domain/bot_difficulty.dart';
import '../../game_engine/domain/player_color.dart';
import '../../game_engine/engine/game_engine.dart';
import '../design_system/tokens.dart';
import '../game_controller.dart';
import 'game_screen.dart';

String _difficultyLabel(BotDifficulty difficulty) {
  switch (difficulty) {
    case BotDifficulty.easy:
      return 'Fácil';
    case BotDifficulty.normal:
      return 'Normal';
    case BotDifficulty.hard:
      return 'Difícil';
    case BotDifficulty.expert:
      return 'Especialista';
  }
}

/// Minimal setup flow for Phase 1/3: pick player count and bot difficulty,
/// rest are bots.
class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  int _playerCount = 2;
  BotDifficulty _botDifficulty = BotDifficulty.normal;
  bool _starting = false;

  Future<void> _startMatch() async {
    setState(() => _starting = true);
    final colors = [
      PlayerColor.blue,
      PlayerColor.red,
      PlayerColor.green,
      PlayerColor.yellow,
    ];
    final configs = [
      PlayerConfig(id: 'p0', displayName: 'Você', color: colors[0]),
      for (var i = 1; i < _playerCount; i++)
        PlayerConfig(
          id: 'p$i',
          displayName: 'Bot $i',
          color: colors[i],
          isBot: true,
          botDifficulty: _botDifficulty,
        ),
    ];
    await ref.read(gameControllerProvider.notifier).startMatch(
          mapId: 'biblical_lands_v1',
          players: configs,
          seed: DateTime.now().millisecondsSinceEpoch,
        );
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const GameScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Partida Rápida')),
      body: Padding(
        padding: const EdgeInsets.all(ReinosSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mapa: Terras Bíblicas', style: ReinosTypography.heading),
            const SizedBox(height: ReinosSpacing.md),
            Text('Número de jogadores', style: ReinosTypography.body),
            Slider(
              value: _playerCount.toDouble(),
              min: 2,
              max: 4,
              divisions: 2,
              label: '$_playerCount',
              onChanged: (v) => setState(() => _playerCount = v.round()),
            ),
            const SizedBox(height: ReinosSpacing.md),
            Text('Dificuldade dos bots', style: ReinosTypography.body),
            Wrap(
              spacing: ReinosSpacing.sm,
              children: BotDifficulty.values.map((difficulty) {
                return ChoiceChip(
                  label: Text(_difficultyLabel(difficulty)),
                  selected: _botDifficulty == difficulty,
                  onSelected: (_) => setState(() => _botDifficulty = difficulty),
                );
              }).toList(),
            ),
            const SizedBox(height: ReinosSpacing.sm),
            Text(
              'Você + ${_playerCount - 1} bot(s).',
              style: ReinosTypography.label,
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _starting ? null : _startMatch,
                child: _starting
                    ? const SizedBox(
                        height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('COMEÇAR'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
