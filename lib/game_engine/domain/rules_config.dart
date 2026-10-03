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

  const RulesConfig({
    required this.minReinforcements,
    required this.territoriesPerReinforcement,
    required this.maxDiceAttacker,
    required this.maxDiceDefender,
    required this.startingArmiesPerTerritory,
    required this.initialPlacementExtraArmies,
    required this.minTerritoriesForObjective,
  });

  factory RulesConfig.fromJson(Map<String, dynamic> json) {
    return RulesConfig(
      minReinforcements: json['minReinforcements'] as int,
      territoriesPerReinforcement: json['territoriesPerReinforcement'] as int,
      maxDiceAttacker: json['maxDiceAttacker'] as int,
      maxDiceDefender: json['maxDiceDefender'] as int,
      startingArmiesPerTerritory: json['startingArmiesPerTerritory'] as int,
      initialPlacementExtraArmies: json['initialPlacementExtraArmies'] as int,
      minTerritoriesForObjective: json['minTerritoriesForObjective'] as int? ?? 18,
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
