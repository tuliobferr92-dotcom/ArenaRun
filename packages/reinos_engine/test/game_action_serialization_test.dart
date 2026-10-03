import 'package:test/test.dart';

import 'package:reinos_engine/game_engine/state/game_action.dart';

void main() {
  group('GameAction JSON round-trip', () {
    final ts = DateTime.utc(2026, 1, 1, 12, 30);

    void expectRoundTrip(GameAction action) {
      final decoded = gameActionFromJson(action.toJson());
      expect(decoded.runtimeType, action.runtimeType);
      expect(decoded.toJson(), action.toJson());
    }

    test('PlaceArmyAction', () {
      expectRoundTrip(PlaceArmyAction(
        gameId: 'g1',
        playerId: 'p1',
        timestamp: ts,
        sequenceNumber: 1,
        territoryId: 't1',
        count: 3,
      ));
    });

    test('ReinforceAction', () {
      expectRoundTrip(ReinforceAction(
        gameId: 'g1',
        playerId: 'p1',
        timestamp: ts,
        sequenceNumber: 2,
        armiesByTerritory: const {'t1': 2, 't2': 1},
      ));
    });

    test('AttackAction', () {
      expectRoundTrip(AttackAction(
        gameId: 'g1',
        playerId: 'p1',
        timestamp: ts,
        sequenceNumber: 3,
        fromTerritoryId: 't1',
        toTerritoryId: 't2',
        troopCount: 5,
      ));
    });

    test('MoveArmyAction', () {
      expectRoundTrip(MoveArmyAction(
        gameId: 'g1',
        playerId: 'p1',
        timestamp: ts,
        sequenceNumber: 4,
        fromTerritoryId: 't1',
        toTerritoryId: 't2',
        count: 4,
      ));
    });

    test('PlayCardAction', () {
      expectRoundTrip(PlayCardAction(
        gameId: 'g1',
        playerId: 'p1',
        timestamp: ts,
        sequenceNumber: 5,
        cardIds: const ['c1', 'c2', 'c3'],
      ));
    });

    test('AnswerChallengeAction', () {
      expectRoundTrip(AnswerChallengeAction(
        gameId: 'g1',
        playerId: 'p1',
        timestamp: ts,
        sequenceNumber: 6,
        challengeId: 'bc1',
        correct: true,
      ));
    });

    test('PlayEventCardAction with target territory', () {
      expectRoundTrip(PlayEventCardAction(
        gameId: 'g1',
        playerId: 'p1',
        timestamp: ts,
        sequenceNumber: 7,
        eventCardId: 'reconstrucao',
        targetTerritoryId: 't1',
      ));
    });

    test('PlayEventCardAction without target territory', () {
      expectRoundTrip(PlayEventCardAction(
        gameId: 'g1',
        playerId: 'p1',
        timestamp: ts,
        sequenceNumber: 8,
        eventCardId: 'sabedoria',
      ));
    });

    test('EndPhaseAction', () {
      expectRoundTrip(EndPhaseAction(
        gameId: 'g1',
        playerId: 'p1',
        timestamp: ts,
        sequenceNumber: 9,
      ));
    });

    test('unknown type throws', () {
      expect(() => gameActionFromJson({'type': 'notARealType'}), throwsArgumentError);
    });
  });
}
