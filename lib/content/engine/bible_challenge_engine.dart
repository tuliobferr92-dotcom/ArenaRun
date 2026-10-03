import '../domain/bible_challenge.dart';

/// Picks *when and which* challenge to offer (section 22). Deliberately
/// not wired to every attack — the only call site that matters today is
/// "a territory was just discovered for the first time" (section 24/30).
/// Pure selection logic: no I/O, no randomness tied to match RNG (this is
/// presentation/education, never a mechanic `BattleEngine` depends on).
class BibleChallengeEngine {
  /// The first not-yet-answered challenge for [territoryId], or null if
  /// there is no challenge for it yet or the player has answered them all.
  static BibleChallenge? nextChallengeForTerritory(
    List<BibleChallenge> allChallenges,
    String territoryId,
    Set<String> answeredChallengeIds,
  ) {
    for (final challenge in allChallenges) {
      if (challenge.territoryId == territoryId &&
          !answeredChallengeIds.contains(challenge.id)) {
        return challenge;
      }
    }
    return null;
  }

  static bool isCorrect(BibleChallenge challenge, int chosenOptionIndex) {
    return chosenOptionIndex == challenge.correctOptionIndex;
  }
}
