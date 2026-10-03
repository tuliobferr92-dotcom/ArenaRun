import '../domain/objective.dart';
import '../state/game_state.dart';

/// Checks whether a player's secret objective is complete. Only the two
/// Phase 1 types are evaluated; the rest are modeled in [ObjectiveType] for
/// later phases (GAME_RULES.md "Objetivos secretos").
class ObjectiveEngine {
  static bool isComplete(GameState state, String playerId) {
    final player = state.players.firstWhere((p) => p.id == playerId);
    final objective = player.objective;

    switch (objective.type) {
      case ObjectiveType.controlTerritoryCount:
        final count = objective.params['count'] as int;
        return state.territoriesOwnedBy(playerId).length >= count;

      case ObjectiveType.controlRegions:
        final regionIds = (objective.params['regionIds'] as List).cast<String>();
        return regionIds.every((id) => state.playerControlsRegion(playerId, id));

      case ObjectiveType.controlSpecificTerritories:
        final territoryIds = (objective.params['territoryIds'] as List).cast<String>();
        return territoryIds.every((id) => state.territories[id]?.ownerId == playerId);

      case ObjectiveType.eliminatePlayer:
      case ObjectiveType.hybrid:
        // Implemented in a later phase.
        return false;
    }
  }

  /// Fallback win condition: a single player controls the whole map.
  static String? soleSurvivor(GameState state) {
    final alive = state.players.where((p) => !p.isEliminated).toList();
    if (alive.length == 1) return alive.first.id;
    return null;
  }
}
