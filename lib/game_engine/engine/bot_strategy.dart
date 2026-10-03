import '../domain/territory.dart';
import '../domain/territory_card.dart';
import '../state/game_state.dart';

class BotAttackDecision {
  final String fromTerritoryId;
  final String toTerritoryId;
  final int troopCount;

  const BotAttackDecision({
    required this.fromTerritoryId,
    required this.toTerritoryId,
    required this.troopCount,
  });
}

/// Minimal rule-based bot for Phase 1 (section 38). It never touches the
/// RNG — it only decides *which* action to request; `BattleEngine` alone
/// decides dice outcomes, so the bot can get harder without ever cheating.
class BotStrategy {
  /// Reinforcements are placed on the owned territory with the weakest
  /// army count that borders an enemy, biased toward progressing the
  /// player's own objective footprint.
  static Map<String, int> decideReinforcementPlacement(
    GameState state,
    String playerId,
    int reinforcements,
  ) {
    final frontierTerritories = state
        .territoriesOwnedBy(playerId)
        .where((t) => t.neighborIds.any((n) => state.territories[n]?.ownerId != playerId))
        .toList()
      ..sort((a, b) => a.armyCount.compareTo(b.armyCount));

    if (frontierTerritories.isEmpty) {
      final owned = state.territoriesOwnedBy(playerId);
      if (owned.isEmpty) return {};
      return {owned.first.id: reinforcements};
    }

    return {frontierTerritories.first.id: reinforcements};
  }

  /// Returns the next attack to make, or null if the bot should stop
  /// attacking this turn. Only attacks when it has a numeric advantage of
  /// at least [minAdvantage] (harder difficulties raise this threshold by
  /// being pickier, never by altering dice odds).
  static BotAttackDecision? decideNextAttack(
    GameState state,
    String playerId, {
    int minAdvantage = 1,
  }) {
    final owned = state.territoriesOwnedBy(playerId).where((t) => t.armyCount > 1);

    Territory? bestFrom;
    Territory? bestTo;
    var bestMargin = -999;

    for (final from in owned) {
      for (final neighborId in from.neighborIds) {
        final to = state.territories[neighborId];
        if (to == null || to.ownerId == playerId) continue;
        final margin = from.armyCount - to.armyCount;
        if (margin > bestMargin) {
          bestMargin = margin;
          bestFrom = from;
          bestTo = to;
        }
      }
    }

    if (bestFrom == null || bestTo == null || bestMargin < minAdvantage) return null;

    final troopCount = (bestFrom.armyCount - 1).clamp(1, 3);
    return BotAttackDecision(
      fromTerritoryId: bestFrom.id,
      toTerritoryId: bestTo.id,
      troopCount: troopCount,
    );
  }

  /// Returns 3 card ids forming a valid trade-in combo from the player's
  /// hand, or null if none exists yet. The bot always trades in as soon as
  /// it can — holding cards has no strategic upside in this ruleset, and
  /// never claiming a valid combo would make full-match simulations
  /// (test/game_engine/simulation_test.dart) under-exercise the card loop.
  static List<String>? decideCardTradeIn(GameState state, String playerId) {
    final hand = state.players.firstWhere((p) => p.id == playerId).cards;
    if (hand.length < 3) return null;

    for (var i = 0; i < hand.length; i++) {
      for (var j = i + 1; j < hand.length; j++) {
        for (var k = j + 1; k < hand.length; k++) {
          final trio = [hand[i], hand[j], hand[k]];
          if (_isValidCombo(trio)) {
            return trio.map((c) => c.id).toList();
          }
        }
      }
    }
    return null;
  }

  static bool _isValidCombo(List<TerritoryCard> cards) {
    final nonWild = cards.map((c) => c.symbol).where((s) => s != CardSymbol.wildcard).toList();
    if (nonWild.length <= 2) return true;
    final distinct = nonWild.toSet().length;
    return distinct == 1 || distinct == nonWild.length;
  }
}
