import '../domain/objective.dart';
import '../state/game_state.dart';

/// Checks whether a player's secret objective is complete (GAME_RULES.md
/// "Objetivos secretos"). All five [ObjectiveType]s from section 18 are
/// evaluated here.
class ObjectiveEngine {
  static bool isComplete(GameState state, String playerId) {
    final player = state.players.firstWhere((p) => p.id == playerId);
    return _evaluate(state, playerId, player.objective.type, player.objective.params);
  }

  static bool _evaluate(
    GameState state,
    String playerId,
    ObjectiveType type,
    Map<String, dynamic> params,
  ) {
    switch (type) {
      case ObjectiveType.controlTerritoryCount:
        final count = params['count'] as int;
        return state.territoriesOwnedBy(playerId).length >= count;

      case ObjectiveType.controlRegions:
        final regionIds = (params['regionIds'] as List).cast<String>();
        return regionIds.every((id) => state.playerControlsRegion(playerId, id));

      case ObjectiveType.controlSpecificTerritories:
        final territoryIds = (params['territoryIds'] as List).cast<String>();
        return territoryIds.every((id) => state.territories[id]?.ownerId == playerId);

      case ObjectiveType.eliminatePlayer:
        // Assigned with a concrete rival id (GameEngine.newMatch never
        // leaves this null); a null target can never be satisfied — it is
        // not the same claim as "be the sole survivor", which is already
        // covered by `soleSurvivor` as a separate, unconditional fallback.
        final targetPlayerId = params['targetPlayerId'] as String?;
        if (targetPlayerId == null) return false;
        return state.players.any((p) => p.id == targetPlayerId && p.isEliminated);

      case ObjectiveType.hybrid:
        // All sub-conditions must hold simultaneously — a harder objective
        // than any single type alone (section 18's hybrid examples).
        final conditions = (params['conditions'] as List).cast<Map<String, dynamic>>();
        return conditions.every((condition) {
          final subType = ObjectiveType.values.byName(condition['type'] as String);
          final subParams = Map<String, dynamic>.from(condition['params'] as Map);
          return _evaluate(state, playerId, subType, subParams);
        });
    }
  }

  /// Fallback win condition: a single player controls the whole map.
  static String? soleSurvivor(GameState state) {
    final alive = state.players.where((p) => !p.isEliminated).toList();
    if (alive.length == 1) return alive.first.id;
    return null;
  }
}
