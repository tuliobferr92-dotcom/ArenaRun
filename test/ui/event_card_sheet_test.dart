import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reinos/game_engine/domain/event_card.dart';
import 'package:reinos/ui/widgets/event_card_sheet.dart';

void main() {
  testWidgets('shows a hint when the player has no event cards yet', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EventCardSheet(
          eventCards: const [],
          selectedOwnTerritoryId: null,
          onPlay: (_, {targetTerritoryId}) {},
        ),
      ),
    );

    expect(find.textContaining('Responda desafios bíblicos'), findsOneWidget);
  });

  testWidgets('disables Usar for reconstrucao until a territory is selected', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EventCardSheet(
          eventCards: const [EventCard(id: 'ec1', type: EventCardType.reconstrucao)],
          selectedOwnTerritoryId: null,
          onPlay: (_, {targetTerritoryId}) {},
        ),
      ),
    );

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('enables Usar for reconstrucao once a territory is selected, and passes it through',
      (tester) async {
    String? playedId;
    String? playedTarget;

    await tester.pumpWidget(
      MaterialApp(
        home: EventCardSheet(
          eventCards: const [EventCard(id: 'ec1', type: EventCardType.reconstrucao)],
          selectedOwnTerritoryId: 't1',
          onPlay: (id, {targetTerritoryId}) {
            playedId = id;
            playedTarget = targetTerritoryId;
          },
        ),
      ),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Usar'));
    await tester.pump();

    expect(playedId, 'ec1');
    expect(playedTarget, 't1');
  });

  testWidgets('sabedoria and tempoDeFartura never need a target to be enabled', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EventCardSheet(
          eventCards: const [
            EventCard(id: 'ec1', type: EventCardType.sabedoria),
            EventCard(id: 'ec2', type: EventCardType.tempoDeFartura),
          ],
          selectedOwnTerritoryId: null,
          onPlay: (_, {targetTerritoryId}) {},
        ),
      ),
    );

    for (final button in tester.widgetList<FilledButton>(find.byType(FilledButton))) {
      expect(button.onPressed, isNotNull);
    }
  });
}
