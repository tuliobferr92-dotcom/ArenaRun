import 'package:flutter_test/flutter_test.dart';
import 'package:reinos/game_engine/domain/territory_card.dart';
import 'package:reinos/game_engine/engine/game_engine.dart';
import 'package:reinos/game_engine/engine/game_exceptions.dart';
import 'package:reinos/game_engine/state/game_action.dart';
import 'package:reinos/game_engine/state/game_phase.dart';

import 'test_fixtures.dart';

TerritoryCard _card(String id, CardSymbol symbol) =>
    TerritoryCard(id: id, territoryId: 't1', symbol: symbol);

GameAction _playCards(List<String> cardIds, {String playerId = 'p0', int seq = 0}) {
  return PlayCardAction(
    gameId: 'g',
    playerId: playerId,
    timestamp: DateTime.now(),
    sequenceNumber: seq,
    cardIds: cardIds,
  );
}

void main() {
  group('GameEngine.apply — card trade-ins', () {
    test('three cards of the same symbol is a valid combo', () {
      var state = freshTestState().copyWith(phase: GamePhase.reinforcement, pendingReinforcements: 0);
      final hand = [
        _card('c1', CardSymbol.shield),
        _card('c2', CardSymbol.shield),
        _card('c3', CardSymbol.shield),
      ];
      state = state.copyWith(
        players: state.players.map((p) => p.id == 'p0' ? p.copyWith(cards: hand) : p).toList(),
      );

      final result = GameEngine.apply(state, _playCards(['c1', 'c2', 'c3']));

      expect(result.pendingReinforcements, state.rules.cardTradeInReward(0));
      expect(result.cardTradeInsCompleted, 1);
      expect(result.currentPlayer.cards, isEmpty);
      expect(result.discardPile.length, 3);
    });

    test('three different symbols is a valid combo', () {
      var state = freshTestState().copyWith(phase: GamePhase.reinforcement, pendingReinforcements: 0);
      final hand = [
        _card('c1', CardSymbol.shield),
        _card('c2', CardSymbol.flame),
        _card('c3', CardSymbol.scroll),
      ];
      state = state.copyWith(
        players: state.players.map((p) => p.id == 'p0' ? p.copyWith(cards: hand) : p).toList(),
      );

      final result = GameEngine.apply(state, _playCards(['c1', 'c2', 'c3']));

      expect(result.pendingReinforcements, state.rules.cardTradeInReward(0));
    });

    test('a wildcard fills in to complete either a triple or a set', () {
      var state = freshTestState().copyWith(phase: GamePhase.reinforcement, pendingReinforcements: 0);
      final hand = [
        _card('c1', CardSymbol.shield),
        _card('c2', CardSymbol.shield),
        _card('c3', CardSymbol.wildcard),
      ];
      state = state.copyWith(
        players: state.players.map((p) => p.id == 'p0' ? p.copyWith(cards: hand) : p).toList(),
      );

      expect(() => GameEngine.apply(state, _playCards(['c1', 'c2', 'c3'])), returnsNormally);
    });

    test('two of a kind plus one different symbol (no wildcard) is invalid', () {
      var state = freshTestState().copyWith(phase: GamePhase.reinforcement, pendingReinforcements: 0);
      final hand = [
        _card('c1', CardSymbol.shield),
        _card('c2', CardSymbol.shield),
        _card('c3', CardSymbol.flame),
      ];
      state = state.copyWith(
        players: state.players.map((p) => p.id == 'p0' ? p.copyWith(cards: hand) : p).toList(),
      );

      expect(
        () => GameEngine.apply(state, _playCards(['c1', 'c2', 'c3'])),
        throwsA(isA<InvalidActionException>()),
      );
    });

    test('rejects trading cards the player does not own', () {
      var state = freshTestState().copyWith(phase: GamePhase.reinforcement, pendingReinforcements: 0);

      expect(
        () => GameEngine.apply(state, _playCards(['nope1', 'nope2', 'nope3'])),
        throwsA(isA<InvalidActionException>()),
      );
    });

    test('rejects trading outside the reinforcement phase', () {
      var state = freshTestState().copyWith(phase: GamePhase.attack, pendingReinforcements: 0);
      final hand = [
        _card('c1', CardSymbol.shield),
        _card('c2', CardSymbol.shield),
        _card('c3', CardSymbol.shield),
      ];
      state = state.copyWith(
        players: state.players.map((p) => p.id == 'p0' ? p.copyWith(cards: hand) : p).toList(),
      );

      expect(
        () => GameEngine.apply(state, _playCards(['c1', 'c2', 'c3'])),
        throwsA(isA<InvalidActionException>()),
      );
    });

    test('rejects trading a number of cards other than 3', () {
      var state = freshTestState().copyWith(phase: GamePhase.reinforcement, pendingReinforcements: 0);
      final hand = [_card('c1', CardSymbol.shield), _card('c2', CardSymbol.shield)];
      state = state.copyWith(
        players: state.players.map((p) => p.id == 'p0' ? p.copyWith(cards: hand) : p).toList(),
      );

      expect(
        () => GameEngine.apply(state, _playCards(['c1', 'c2'])),
        throwsA(isA<InvalidActionException>()),
      );
    });

    test('the reward escalates across consecutive trade-ins, shared match-wide', () {
      var state = freshTestState().copyWith(phase: GamePhase.reinforcement, pendingReinforcements: 0);

      final rewards = <int>[];
      for (var round = 0; round < 3; round++) {
        final hand = [
          _card('c${round}_1', CardSymbol.shield),
          _card('c${round}_2', CardSymbol.shield),
          _card('c${round}_3', CardSymbol.shield),
        ];
        state = state.copyWith(
          players: state.players.map((p) => p.id == 'p0' ? p.copyWith(cards: hand) : p).toList(),
        );
        final before = state.pendingReinforcements;
        state = GameEngine.apply(
          state,
          _playCards(['c${round}_1', 'c${round}_2', 'c${round}_3'], seq: round),
        );
        rewards.add(state.pendingReinforcements - before);
        state = state.copyWith(pendingReinforcements: 0);
      }

      expect(rewards, [
        testRules.cardTradeInReward(0),
        testRules.cardTradeInReward(1),
        testRules.cardTradeInReward(2),
      ]);
      expect(rewards[0], lessThan(rewards[1]));
      expect(rewards[1], lessThan(rewards[2]));
    });
  });
}
