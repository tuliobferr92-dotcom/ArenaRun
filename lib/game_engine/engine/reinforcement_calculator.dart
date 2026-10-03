import '../domain/rules_config.dart';
import '../state/game_state.dart';

/// Computes reinforcements for the current player (GAME_RULES.md Fase 1).
class ReinforcementCalculator {
  static int calculate(GameState state, String playerId, RulesConfig rules) {
    final owned = state.territoriesOwnedBy(playerId);
    final fromTerritories = (owned.length / rules.territoriesPerReinforcement).floor();
    final base = fromTerritories > rules.minReinforcements
        ? fromTerritories
        : rules.minReinforcements;

    var regionBonus = 0;
    for (final region in state.regions.values) {
      if (state.playerControlsRegion(playerId, region.id)) {
        regionBonus += region.controlBonus;
      }
    }

    return base + regionBonus;
  }
}
