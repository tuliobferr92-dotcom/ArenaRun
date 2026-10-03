/// Result of a single dice-resolution step, kept around so the UI can
/// animate it (section 15) without the engine waiting on the animation.
class DiceRollResult {
  final List<int> attackerDice;
  final List<int> defenderDice;
  final int attackerLosses;
  final int defenderLosses;
  final bool territoryConquered;

  const DiceRollResult({
    required this.attackerDice,
    required this.defenderDice,
    required this.attackerLosses,
    required this.defenderLosses,
    required this.territoryConquered,
  });
}

/// Transient state describing an in-progress attack, cleared once the
/// attacker stops attacking or the territory is conquered.
class BattleState {
  final String attackerId;
  final String fromTerritoryId;
  final String toTerritoryId;
  final List<DiceRollResult> rolls;

  const BattleState({
    required this.attackerId,
    required this.fromTerritoryId,
    required this.toTerritoryId,
    this.rolls = const [],
  });

  BattleState copyWith({List<DiceRollResult>? rolls}) => BattleState(
        attackerId: attackerId,
        fromTerritoryId: fromTerritoryId,
        toTerritoryId: toTerritoryId,
        rolls: rolls ?? this.rolls,
      );
}
