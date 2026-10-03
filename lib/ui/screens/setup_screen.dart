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

/// Setup flow for Fases 1–3: total player count, how many of them are
/// humans sharing this device (pass-and-play, section 56) vs bots, and
/// bot difficulty.
class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  int _playerCount = 2;
  int _localHumans = 1;
  BotDifficulty _botDifficulty = BotDifficulty.normal;
  bool _starting = false;

  void _setPlayerCount(int count) {
    setState(() {
      _playerCount = count;
      if (_localHumans > _playerCount) _localHumans = _playerCount;
    });
  }

  Future<void> _startMatch() async {
    setState(() => _starting = true);
    final colors = [
      PlayerColor.blue,
      PlayerColor.red,
      PlayerColor.green,
      PlayerColor.yellow,
    ];
    final configs = [
      for (var i = 0; i < _playerCount; i++)
        if (i < _localHumans)
          PlayerConfig(id: 'p$i', displayName: 'Jogador ${i + 1}', color: colors[i])
        else
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
    final botCount = _playerCount - _localHumans;
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
              onChanged: (v) => _setPlayerCount(v.round()),
            ),
            const SizedBox(height: ReinosSpacing.md),
            Text('Jogadores humanos neste aparelho', style: ReinosTypography.body),
            Slider(
              value: _localHumans.toDouble(),
              min: 1,
              max: _playerCount.toDouble(),
              divisions: _playerCount > 1 ? _playerCount - 1 : null,
              label: '$_localHumans',
              onChanged: (v) => setState(() => _localHumans = v.round()),
            ),
            if (_localHumans > 1)
              Text(
                'Modo pass-and-play: o dispositivo será passado entre os jogadores a cada turno.',
                style: ReinosTypography.label,
              ),
            if (botCount > 0) ...[
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
            ],
            const SizedBox(height: ReinosSpacing.sm),
            Text(
              '$_localHumans jogador(es) humano(s) + $botCount bot(s).',
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
