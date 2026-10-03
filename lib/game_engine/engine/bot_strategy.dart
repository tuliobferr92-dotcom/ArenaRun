import '../domain/bot_difficulty.dart';
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

/// Rule-based bot (section 38). [BotDifficulty] only ever changes *which*
/// action gets requested — how picky it is about attacking, how it
/// prioritizes reinforcements — never the dice: `BattleEngine` alone rolls
/// them, from the same shared `SeededRandom`, regardless of difficulty.
class BotStrategy {
  /// Minimum numeric advantage (attacker armies minus defender armies)
  /// required before attacking at all. Easy bots will even take bad
  /// fights; hard/expert wait for a clear edge — but never so strict that
  /// a bot could refuse to attack indefinitely once armies pile up on a
  /// static front (expert gets its edge from the overextension check and
  /// threat-aware reinforcement below, not from an ever-higher threshold).
  static int _minAdvantageFor(BotDifficulty? difficulty) {
    switch (difficulty) {
      case BotDifficulty.easy:
        return -2;
      case BotDifficulty.hard:
      case BotDifficulty.expert:
        return 2;
      case BotDifficulty.normal:
      case null:
        return 1;
    }
  }

  /// Reinforcements are placed on a frontier territory (one bordering at
  /// least one enemy). Easy/normal just shore up the weakest one; hard/
  /// expert instead reinforce whichever frontier territory is under the
  /// most pressure (the most enemy-owned neighbors), since that is the one
  /// most likely to be attacked next — a "risco" read (section 38), not
  /// just a army-count tiebreaker.
  static Map<String, int> decideReinforcementPlacement(
    GameState state,
    String playerId,
    int reinforcements, {
    BotDifficulty? difficulty,
  }) {
    final frontierTerritories = state
        .territoriesOwnedBy(playerId)
        .where((t) => t.neighborIds.any((n) => state.territories[n]?.ownerId != playerId))
        .toList();

    if (frontierTerritories.isEmpty) {
      final owned = state.territoriesOwnedBy(playerId);
      if (owned.isEmpty) return {};
      return {owned.first.id: reinforcements};
    }

    final prioritizeThreat = difficulty == BotDifficulty.hard || difficulty == BotDifficulty.expert;
    if (prioritizeThreat) {
      int enemyNeighborCount(Territory t) =>
          t.neighborIds.where((n) => state.territories[n]?.ownerId != playerId).length;
      frontierTerritories.sort((a, b) {
        final byThreat = enemyNeighborCount(b).compareTo(enemyNeighborCount(a));
        return byThreat != 0 ? byThreat : a.armyCount.compareTo(b.armyCount);
      });
    } else {
      frontierTerritories.sort((a, b) => a.armyCount.compareTo(b.armyCount));
    }

    return {frontierTerritories.first.id: reinforcements};
  }

  /// Returns the next attack to make, or null if the bot should stop
  /// attacking this turn. Candidates are ranked by numeric margin and
  /// filtered by [_minAdvantageFor]; hard/expert bots additionally skip an
  /// attack that would leave the origin territory dangerously exposed to
  /// its *other* enemy neighbors (section 38 "risco") rather than blindly
  /// taking the single best-margin fight.
  static BotAttackDecision? decideNextAttack(
    GameState state,
    String playerId, {
    BotDifficulty? difficulty,
  }) {
    final minAdvantage = _minAdvantageFor(difficulty);
    final avoidOverextending =
        difficulty == BotDifficulty.hard || difficulty == BotDifficulty.expert;

    final candidates = <({Territory from, Territory to, int margin})>[];
    for (final from in state.territoriesOwnedBy(playerId).where((t) => t.armyCount > 1)) {
      for (final neighborId in from.neighborIds) {
        final to = state.territories[neighborId];
        if (to == null || to.ownerId == playerId) continue;
        candidates.add((from: from, to: to, margin: from.armyCount - to.armyCount));
      }
    }
    candidates.sort((a, b) => b.margin.compareTo(a.margin));

    final eligible =
        candidates.where((c) => c.margin >= minAdvantage).toList(growable: false);
    if (eligible.isEmpty) return null;

    // Prefer a candidate that doesn't leave the origin exposed, but a
    // legal, advantageous attack is always taken over refusing to act
    // forever — an eternally "too cautious" bot would soft-lock the match.
    final chosen = avoidOverextending
        ? eligible.firstWhere(
            (c) => !_leavesOriginExposed(state, playerId, c.from, (c.from.armyCount - 1).clamp(1, 3)),
            orElse: () => eligible.first,
          )
        : eligible.first;

    return BotAttackDecision(
      fromTerritoryId: chosen.from.id,
      toTerritoryId: chosen.to.id,
      troopCount: (chosen.from.armyCount - 1).clamp(1, 3),
    );
  }

  /// True if, after committing [troopCount] out of the origin's armies, the
  /// garrison left behind would be outnumbered by its *other* hostile
  /// neighbors combined — i.e. this attack would hand the territory back
  /// to the first enemy who counter-attacks.
  static bool _leavesOriginExposed(
    GameState state,
    String playerId,
    Territory from,
    int troopCount,
  ) {
    final remainingGarrison = from.armyCount - troopCount;
    final otherThreats = from.neighborIds
        .where((id) => state.territories[id]?.ownerId != playerId)
        .map((id) => state.territories[id]!.armyCount)
        .fold<int>(0, (sum, armies) => sum + armies);
    return remainingGarrison < otherThreats;
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
