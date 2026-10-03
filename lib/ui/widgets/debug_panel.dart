import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reinos_engine/game_engine/state/game_phase.dart';
import 'package:reinos_engine/game_engine/state/game_state.dart';
import '../design_system/tokens.dart';
import '../game_controller.dart';

/// Internal tooling (section 47): give armies, force a conquest, jump
/// phases, grant a card, instantly win, reset. Only ever reachable when
/// `kDebugMode` is true — absent entirely from release builds.
void showDebugPanel(BuildContext context, WidgetRef ref, GameState state, String? selectedTerritoryId) {
  showModalBottomSheet(
    context: context,
    backgroundColor: ReinosColors.surface,
    builder: (sheetContext) {
      final controller = ref.read(gameControllerProvider.notifier);
      return Padding(
        padding: const EdgeInsets.all(ReinosSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('🐛 Debug Mode', style: ReinosTypography.heading),
            const SizedBox(height: ReinosSpacing.sm),
            Text(
              selectedTerritoryId == null
                  ? 'Selecione um território no mapa para usar ações que dependem de alvo.'
                  : 'Território selecionado: $selectedTerritoryId',
              style: ReinosTypography.label,
            ),
            const SizedBox(height: ReinosSpacing.md),
            Wrap(
              spacing: ReinosSpacing.sm,
              runSpacing: ReinosSpacing.sm,
              children: [
                ElevatedButton(
                  onPressed: selectedTerritoryId == null
                      ? null
                      : () => controller.debugGiveArmies(selectedTerritoryId, 5),
                  child: const Text('+5 tropas'),
                ),
                ElevatedButton(
                  onPressed: selectedTerritoryId == null
                      ? null
                      : () => controller.debugConquerTerritory(selectedTerritoryId),
                  child: const Text('Conquistar território'),
                ),
                ElevatedButton(
                  onPressed: controller.debugGiveCard,
                  child: const Text('Dar carta'),
                ),
                ElevatedButton(
                  onPressed: () => controller.debugSkipToPhase(GamePhase.attack),
                  child: const Text('Ir para Ataque'),
                ),
                ElevatedButton(
                  onPressed: () => controller.debugSkipToPhase(GamePhase.fortification),
                  child: const Text('Ir para Movimentação'),
                ),
                ElevatedButton(
                  onPressed: controller.debugCompleteObjective,
                  style: ElevatedButton.styleFrom(backgroundColor: ReinosColors.success),
                  child: const Text('Completar objetivo (vencer)'),
                ),
                ElevatedButton(
                  onPressed: () {
                    controller.debugResetMatch();
                    Navigator.of(sheetContext).popUntil((route) => route.isFirst);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: ReinosColors.danger),
                  child: const Text('Resetar partida'),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

/// Whether debug-only UI entry points should render at all.
const bool isDebugModeAvailable = kDebugMode;
