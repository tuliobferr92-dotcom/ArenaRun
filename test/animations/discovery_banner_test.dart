import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reinos/animations/discovery_banner.dart';
import 'package:reinos/content/domain/bible_challenge.dart';
import 'package:reinos/content/domain/content_review_status.dart';

BibleChallenge _challenge() => const BibleChallenge(
      id: 'c1',
      territoryId: 'jerico',
      question: 'Pergunta de teste?',
      options: ['Certa', 'Errada'],
      correctOptionIndex: 0,
      explanation: 'Explicação de teste.',
      biblicalReferences: ['Josué 6'],
      category: ChallengeCategory.events,
      difficulty: ChallengeDifficulty.beginner,
      reviewStatus: ContentReviewStatus.published,
      sourceMetadata: {},
    );

void main() {
  testWidgets('shows the territory name and reference, with no quiz button when there is no challenge',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DiscoveryBanner(
          territoryName: 'Jericó',
          biblicalReferences: const ['Josué 6'],
          challenge: null,
          onAnswered: (_, _) {},
          onDismiss: () {},
        ),
      ),
    );

    expect(find.text('JERICÓ'), findsOneWidget);
    expect(find.text('Josué 6'), findsOneWidget);
    expect(find.text('CONTINUAR JOGANDO'), findsOneWidget);
    expect(find.text('VER AGORA'), findsNothing);
  });

  testWidgets('CONTINUAR JOGANDO dismisses without ever opening a challenge', (tester) async {
    var dismissed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: DiscoveryBanner(
          territoryName: 'Jericó',
          biblicalReferences: const ['Josué 6'],
          challenge: _challenge(),
          onAnswered: (_, _) {},
          onDismiss: () => dismissed = true,
        ),
      ),
    );

    await tester.tap(find.text('CONTINUAR JOGANDO'));
    await tester.pumpAndSettle();

    expect(dismissed, isTrue);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('VER AGORA opens the challenge; answering calls onAnswered and dismisses on close',
      (tester) async {
    var dismissed = false;
    String? answeredId;
    bool? wasCorrect;

    await tester.pumpWidget(
      MaterialApp(
        home: DiscoveryBanner(
          territoryName: 'Jericó',
          biblicalReferences: const ['Josué 6'],
          challenge: _challenge(),
          onAnswered: (id, correct) {
            answeredId = id;
            wasCorrect = correct;
          },
          onDismiss: () => dismissed = true,
        ),
      ),
    );

    await tester.tap(find.text('VER AGORA'));
    await tester.pumpAndSettle();

    expect(find.text('Pergunta de teste?'), findsOneWidget);

    await tester.tap(find.text('Certa'));
    await tester.pump();

    expect(answeredId, 'c1');
    expect(wasCorrect, isTrue);
    expect(find.text('Explicação de teste.'), findsOneWidget);

    await tester.tap(find.text('Fechar'));
    await tester.pumpAndSettle();

    expect(dismissed, isTrue);
  });
}
