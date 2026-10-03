import 'package:flutter_test/flutter_test.dart';
import 'package:reinos/game_engine/domain/event_card.dart';
import 'package:reinos/game_engine/engine/game_engine.dart';
import 'package:reinos/game_engine/engine/game_exceptions.dart';
import 'package:reinos/game_engine/state/game_action.dart';
import 'package:reinos/game_engine/state/game_phase.dart';

import 'test_fixtures.dart';

GameAction _answer(String challengeId, bool correct, {String playerId = 'p0', int seq = 0}) {
  return AnswerChallengeAction(
    gameId: 'g',
    playerId: playerId,
    timestamp: DateTime.now(),
    sequenceNumber: seq,
    challengeId: challengeId,
    correct: correct,
  );
}

GameAction _playEventCard(String cardId, {String? targetId, String playerId = 'p0', int seq = 0}) {
  return PlayEventCardAction(
    gameId: 'g',
    playerId: playerId,
    timestamp: DateTime.now(),
    sequenceNumber: seq,
    eventCardId: cardId,
    targetTerritoryId: targetId,
  );
}

void main() {
  group('GameEngine — earning event cards', () {
    test('a correct answer grants exactly one event card', () {
      final state = freshTestState();
      final result = GameEngine.apply(state, _answer('chal_1', true));

      expect(result.currentPlayer.eventCards.length, 1);
    });

    test('an incorrect answer grants no event card', () {
      final state = freshTestState();
      final result = GameEngine.apply(state, _answer('chal_1', false));

      expect(result.currentPlayer.eventCards, isEmpty);
    });
  });

  group('GameEngine.apply — PlayEventCardAction', () {
    test('rejects playing a card the player does not have', () {
      final state = freshTestState();

      expect(
        () => GameEngine.apply(state, _playEventCard('nope')),
        throwsA(isA<InvalidActionException>()),
      );
    });

    test('reconstrucao reinforces the chosen owned territory and consumes the card', () {
      var state = withOwnership(freshTestState(), {'t1': 'p0'}, {'t1': 5});
      state = state.copyWith(
        players: state.players
            .map((p) => p.id == 'p0'
                ? p.copyWith(eventCards: const [EventCard(id: 'ec1', type: EventCardType.reconstrucao)])
                : p)
            .toList(),
      );

      final result = GameEngine.apply(state, _playEventCard('ec1', targetId: 't1'));

      expect(result.territories['t1']!.armyCount, 5 + testRules.eventCardReconstrucaoBonus);
      expect(result.currentPlayer.eventCards, isEmpty);
    });

    test('reconstrucao rejects a target the player does not own', () {
      var state = withOwnership(freshTestState(), {'t1': 'p1'}, {'t1': 5});
      state = state.copyWith(
        players: state.players
            .map((p) => p.id == 'p0'
                ? p.copyWith(eventCards: const [EventCard(id: 'ec1', type: EventCardType.reconstrucao)])
                : p)
            .toList(),
      );

      expect(
        () => GameEngine.apply(state, _playEventCard('ec1', targetId: 't1')),
        throwsA(isA<InvalidActionException>()),
      );
    });

    test('sabedoria grants immediate reinforcements during the reinforcement phase', () {
      var state = freshTestState().copyWith(
        phase: GamePhase.reinforcement,
        pendingReinforcements: 3,
      );
      state = state.copyWith(
        players: state.players
            .map((p) => p.id == 'p0'
                ? p.copyWith(eventCards: const [EventCard(id: 'ec1', type: EventCardType.sabedoria)])
                : p)
            .toList(),
      );

      final result = GameEngine.apply(state, _playEventCard('ec1'));

      expect(result.pendingReinforcements, 3 + testRules.eventCardSabedoriaBonus);
      expect(result.currentPlayer.eventCards, isEmpty);
    });

    test('sabedoria is rejected outside the reinforcement phase', () {
      var state = freshTestState().copyWith(phase: GamePhase.attack);
      state = state.copyWith(
        players: state.players
            .map((p) => p.id == 'p0'
                ? p.copyWith(eventCards: const [EventCard(id: 'ec1', type: EventCardType.sabedoria)])
                : p)
            .toList(),
      );

      expect(
        () => GameEngine.apply(state, _playEventCard('ec1')),
        throwsA(isA<InvalidActionException>()),
      );
    });

    test('tempoDeFartura draws one territorial card from the deck', () {
      var state = freshTestState();
      final deckSizeBefore = state.deck.length;
      state = state.copyWith(
        players: state.players
            .map((p) => p.id == 'p0'
                ? p.copyWith(eventCards: const [EventCard(id: 'ec1', type: EventCardType.tempoDeFartura)])
                : p)
            .toList(),
      );

      final result = GameEngine.apply(state, _playEventCard('ec1'));

      expect(result.currentPlayer.cards.length, 1);
      expect(result.deck.length, deckSizeBefore - 1);
      expect(result.currentPlayer.eventCards, isEmpty);
    });
  });
}
