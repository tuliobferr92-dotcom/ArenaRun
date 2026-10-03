import 'package:flutter/material.dart';

import '../../game_engine/domain/player.dart';
import '../../game_engine/state/game_phase.dart';
import '../../game_engine/state/game_state.dart';
import '../design_system/tokens.dart';

String phaseLabel(GamePhase phase) {
  switch (phase) {
    case GamePhase.lobby:
      return 'Lobby';
    case GamePhase.setup:
      return 'Preparação';
    case GamePhase.initialPlacement:
      return 'Posicionamento Inicial';
    case GamePhase.turnStart:
      return 'Início de Turno';
    case GamePhase.reinforcement:
      return 'Reforços';
    case GamePhase.attack:
      return 'Ataque';
    case GamePhase.battle:
      return 'Batalha';
    case GamePhase.conquest:
      return 'Conquista';
    case GamePhase.fortification:
      return 'Movimentação';
    case GamePhase.cardReward:
      return 'Recompensa';
    case GamePhase.turnEnd:
      return 'Fim de Turno';
    case GamePhase.gameOver:
      return 'Fim de Jogo';
  }
}

/// Minimal, non-intrusive HUD (section 54) — the map stays the protagonist.
class GameHud extends StatelessWidget {
  final GameState state;
  final VoidCallback onEndPhase;
  final VoidCallback onShowObjective;
  final bool canEndPhase;

  const GameHud({
    super.key,
    required this.state,
    required this.onEndPhase,
    required this.onShowObjective,
    required this.canEndPhase,
  });

  @override
  Widget build(BuildContext context) {
    final Player player = state.currentPlayer;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(ReinosSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PlayerBadge(player: player, turnNumber: state.turnNumber),
            const SizedBox(width: ReinosSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(phaseLabel(state.phase), style: ReinosTypography.heading),
                  if (state.phase == GamePhase.reinforcement)
                    Text(
                      'Reforços disponíveis: ${state.pendingReinforcements}',
                      style: ReinosTypography.label,
                    ),
                ],
              ),
            ),
            IconButton(
              onPressed: onShowObjective,
              icon: const Icon(Icons.auto_stories, color: ReinosColors.gold),
              tooltip: 'Objetivo secreto',
            ),
            FilledButton(
              onPressed: canEndPhase ? onEndPhase : null,
              child: const Text('Avançar Fase'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerBadge extends StatelessWidget {
  final Player player;
  final int turnNumber;

  const _PlayerBadge({required this.player, required this.turnNumber});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: ReinosSpacing.sm, vertical: ReinosSpacing.xs),
      decoration: BoxDecoration(
        color: ReinosColors.surface,
        borderRadius: BorderRadius.circular(ReinosRadius.sm),
        border: Border.all(color: ReinosColors.bronze),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(player.displayName, style: ReinosTypography.body),
          Text('Turno $turnNumber', style: ReinosTypography.label),
        ],
      ),
    );
  }
}
