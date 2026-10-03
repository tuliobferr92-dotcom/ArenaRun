import '../domain/rules_config.dart';
import '../rng/seeded_random.dart';
import '../state/battle_state.dart';

/// Resolves a single round of dice combat. Pure function of its inputs plus
/// the shared [SeededRandom] — the UI never decides a result, only renders
/// one already computed here (section 14).
class BattleEngine {
  /// [attackingTroops]/[defendingTroops] are the *troops committed*, already
  /// validated by `GameEngine` against territory army counts and
  /// [RulesConfig] dice caps.
  static DiceRollResult resolveRound({
    required int attackingTroops,
    required int defendingTroops,
    required RulesConfig rules,
    required SeededRandom rng,
  }) {
    final attackerDiceCount = attackingTroops.clamp(0, rules.maxDiceAttacker);
    final defenderDiceCount = defendingTroops.clamp(0, rules.maxDiceDefender);

    final attackerDice = List.generate(attackerDiceCount, (_) => rng.nextDie(6))
      ..sort((a, b) => b.compareTo(a));
    final defenderDice = List.generate(defenderDiceCount, (_) => rng.nextDie(6))
      ..sort((a, b) => b.compareTo(a));

    var attackerLosses = 0;
    var defenderLosses = 0;
    final comparisons = attackerDice.length < defenderDice.length
        ? attackerDice.length
        : defenderDice.length;

    for (var i = 0; i < comparisons; i++) {
      if (attackerDice[i] > defenderDice[i]) {
        defenderLosses++;
      } else {
        // Ties favor the defender (GAME_RULES.md Fase 2).
        attackerLosses++;
      }
    }

    final remainingDefenders = defendingTroops - defenderLosses;

    return DiceRollResult(
      attackerDice: attackerDice,
      defenderDice: defenderDice,
      attackerLosses: attackerLosses,
      defenderLosses: defenderLosses,
      territoryConquered: remainingDefenders <= 0,
    );
  }
}
