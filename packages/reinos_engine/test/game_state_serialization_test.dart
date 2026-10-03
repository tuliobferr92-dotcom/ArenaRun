import 'package:test/test.dart';
import 'package:reinos_engine/game_engine/state/game_phase.dart';
import 'package:reinos_engine/game_engine/state/game_state.dart';

import 'test_fixtures.dart';

void main() {
  group('GameState JSON round-trip (save/load, section 39)', () {
    test('restores every field exactly, including mid-match progress', () {
      var state = withOwnership(freshTestState(playerCount: 3), {
        't1': 'p0', 't2': 'p1', 't3': 'p1', 't4': 'p2',
      }, {'t1': 5, 't2': 2, 't3': 3, 't4': 1});
      // A non-empty hand for p0, so card round-tripping is also exercised.
      final deck = List.of(state.deck);
      final drawnCard = deck.removeAt(0);
      final players = state.players
          .map((p) => p.id == 'p0' ? p.copyWith(cards: [drawnCard]) : p)
          .toList();

      state = state.copyWith(
        phase: GamePhase.reinforcement,
        pendingReinforcements: 4,
        currentPlayerIndex: 0,
        turnNumber: 7,
        conqueredTerritoryThisTurn: true,
        deck: deck,
        players: players,
      );

      final restored = GameState.fromJson(state.toJson());

      expect(restored.gameId, state.gameId);
      expect(restored.mapId, state.mapId);
      expect(restored.phase, state.phase);
      expect(restored.turnNumber, state.turnNumber);
      expect(restored.currentPlayerIndex, state.currentPlayerIndex);
      expect(restored.pendingReinforcements, state.pendingReinforcements);
      expect(restored.conqueredTerritoryThisTurn, state.conqueredTerritoryThisTurn);
      expect(restored.winnerId, state.winnerId);
      expect(restored.rng.state, state.rng.state);

      for (final id in state.territories.keys) {
        expect(restored.territories[id]!.ownerId, state.territories[id]!.ownerId);
        expect(restored.territories[id]!.armyCount, state.territories[id]!.armyCount);
        expect(restored.territories[id]!.neighborIds, state.territories[id]!.neighborIds);
      }

      expect(restored.players.length, state.players.length);
      for (var i = 0; i < state.players.length; i++) {
        expect(restored.players[i].id, state.players[i].id);
        expect(restored.players[i].objective.type, state.players[i].objective.type);
        expect(restored.players[i].objective.params, state.players[i].objective.params);
        expect(restored.players[i].cards.length, state.players[i].cards.length);
      }

      expect(restored.deck.length, state.deck.length);
      expect(restored.rules.minReinforcements, state.rules.minReinforcements);
      expect(restored.rules.maxDiceAttacker, state.rules.maxDiceAttacker);
    });

    test('a restored RNG continues the exact same dice sequence as the original', () {
      final state = freshTestState();
      final restored = GameState.fromJson(state.toJson());

      final originalRolls = List.generate(10, (_) => state.rng.nextDie(6));
      final restoredRolls = List.generate(10, (_) => restored.rng.nextDie(6));

      expect(restoredRolls, originalRolls);
    });
  });
}
