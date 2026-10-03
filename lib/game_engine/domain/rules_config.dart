/// All tunable numbers for the engine live here, loaded from
/// `data/rules/default_rules.json` — never as magic numbers inside
/// `GameEngine`/`BattleEngine` (section 19/21).
class RulesConfig {
  final int minReinforcements;
  final int territoriesPerReinforcement;
  final int maxDiceAttacker;
  final int maxDiceDefender;
  final int startingArmiesPerTerritory;
  final int initialPlacementExtraArmies;
  final int minTerritoriesForObjective;

  /// Reinforcements granted for the 1st, 2nd, 3rd, ... card trade-in of the
  /// match (shared across all players, as in GAME_RULES.md "Fase 4"). Once
  /// exhausted, [cardTradeInIncrementAfterSequence] is added for each
  /// further trade-in instead of indexing past the list.
  final List<int> cardTradeInSequence;
  final int cardTradeInIncrementAfterSequence;

  const RulesConfig({
    required this.minReinforcements,
    required this.territoriesPerReinforcement,
    required this.maxDiceAttacker,
    required this.maxDiceDefender,
    required this.startingArmiesPerTerritory,
    required this.initialPlacementExtraArmies,
    required this.minTerritoriesForObjective,
    this.cardTradeInSequence = const [4, 6, 8, 10, 12, 15],
    this.cardTradeInIncrementAfterSequence = 5,
  });

  int cardTradeInReward(int tradeInsCompletedBefore) {
    if (tradeInsCompletedBefore < cardTradeInSequence.length) {
      return cardTradeInSequence[tradeInsCompletedBefore];
    }
    final stepsPastSequence = tradeInsCompletedBefore - cardTradeInSequence.length + 1;
    return cardTradeInSequence.last + stepsPastSequence * cardTradeInIncrementAfterSequence;
  }

  factory RulesConfig.fromJson(Map<String, dynamic> json) {
    return RulesConfig(
      minReinforcements: json['minReinforcements'] as int,
      territoriesPerReinforcement: json['territoriesPerReinforcement'] as int,
      maxDiceAttacker: json['maxDiceAttacker'] as int,
      maxDiceDefender: json['maxDiceDefender'] as int,
      startingArmiesPerTerritory: json['startingArmiesPerTerritory'] as int,
      initialPlacementExtraArmies: json['initialPlacementExtraArmies'] as int,
      minTerritoriesForObjective: json['minTerritoriesForObjective'] as int? ?? 18,
      cardTradeInSequence: json['cardTradeInSequence'] != null
          ? (json['cardTradeInSequence'] as List).cast<int>()
          : const [4, 6, 8, 10, 12, 15],
      cardTradeInIncrementAfterSequence:
          json['cardTradeInIncrementAfterSequence'] as int? ?? 5,
    );
  }

  Map<String, dynamic> toJson() => {
        'minReinforcements': minReinforcements,
        'territoriesPerReinforcement': territoriesPerReinforcement,
        'maxDiceAttacker': maxDiceAttacker,
        'maxDiceDefender': maxDiceDefender,
        'startingArmiesPerTerritory': startingArmiesPerTerritory,
        'initialPlacementExtraArmies': initialPlacementExtraArmies,
        'minTerritoriesForObjective': minTerritoriesForObjective,
        'cardTradeInSequence': cardTradeInSequence,
        'cardTradeInIncrementAfterSequence': cardTradeInIncrementAfterSequence,
      };

  static const RulesConfig defaults = RulesConfig(
    minReinforcements: 3,
    territoriesPerReinforcement: 3,
    maxDiceAttacker: 3,
    maxDiceDefender: 2,
    startingArmiesPerTerritory: 2,
    initialPlacementExtraArmies: 3,
    minTerritoriesForObjective: 10,
  );
}
