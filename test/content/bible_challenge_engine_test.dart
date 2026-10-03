import 'package:flutter_test/flutter_test.dart';
import 'package:reinos/content/domain/bible_challenge.dart';
import 'package:reinos/content/domain/content_review_status.dart';
import 'package:reinos/content/engine/bible_challenge_engine.dart';

BibleChallenge _challenge(String id, String territoryId, {int correctIndex = 0}) {
  return BibleChallenge(
    id: id,
    territoryId: territoryId,
    question: 'q',
    options: const ['a', 'b'],
    correctOptionIndex: correctIndex,
    explanation: 'e',
    biblicalReferences: const ['Ref 1'],
    category: ChallengeCategory.geography,
    difficulty: ChallengeDifficulty.beginner,
    reviewStatus: ContentReviewStatus.published,
    sourceMetadata: const {},
  );
}

void main() {
  group('BibleChallengeEngine.nextChallengeForTerritory', () {
    test('returns a challenge for the given territory that has not been answered', () {
      final challenges = [_challenge('c1', 'jerico'), _challenge('c2', 'hebrom')];

      final result = BibleChallengeEngine.nextChallengeForTerritory(challenges, 'jerico', {});

      expect(result?.id, 'c1');
    });

    test('skips already-answered challenges', () {
      final challenges = [_challenge('c1', 'jerico'), _challenge('c2', 'jerico')];

      final result =
          BibleChallengeEngine.nextChallengeForTerritory(challenges, 'jerico', {'c1'});

      expect(result?.id, 'c2');
    });

    test('returns null when there is no challenge for that territory', () {
      final challenges = [_challenge('c1', 'jerico')];

      final result = BibleChallengeEngine.nextChallengeForTerritory(challenges, 'hebrom', {});

      expect(result, isNull);
    });

    test('returns null once every challenge for that territory has been answered', () {
      final challenges = [_challenge('c1', 'jerico')];

      final result =
          BibleChallengeEngine.nextChallengeForTerritory(challenges, 'jerico', {'c1'});

      expect(result, isNull);
    });
  });

  group('BibleChallengeEngine.isCorrect', () {
    test('true when the chosen index matches the correct option', () {
      final challenge = _challenge('c1', 'jerico', correctIndex: 1);
      expect(BibleChallengeEngine.isCorrect(challenge, 1), isTrue);
    });

    test('false otherwise', () {
      final challenge = _challenge('c1', 'jerico', correctIndex: 1);
      expect(BibleChallengeEngine.isCorrect(challenge, 0), isFalse);
    });
  });
}
