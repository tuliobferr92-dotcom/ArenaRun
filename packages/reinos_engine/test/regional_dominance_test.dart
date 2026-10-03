import 'package:test/test.dart';
import 'package:reinos_engine/game_engine/engine/game_engine.dart';
import 'package:reinos_engine/game_engine/state/game_action.dart';
import 'package:reinos_engine/game_engine/state/game_phase.dart';

import 'test_fixtures.dart';

GameAction _attack(String from, String to, int troops, {String playerId = 'p0', int seq = 0}) {
  return AttackAction(
    gameId: 'g',
    playerId: playerId,
    timestamp: DateTime.now(),
    sequenceNumber: seq,
    fromTerritoryId: from,
    toTerritoryId: to,
    troopCount: troops,
  );
}

void main() {
  group('GameEngine — regional dominance (section 17)', () {
    test('conquering the last territory of a region sets newlyDominatedRegionId', () {
      // t1 and t2 together make up regionA (test_fixtures.dart). p0 already
      // owns t1; conquering t2 completes the region.
      var state = withOwnership(freshTestState(), {
        't1': 'p0', 't2': 'p1', 't3': 'p1', 't4': 'p1',
      }, {'t1': 10, 't2': 1});
      state = state.copyWith(phase: GamePhase.attack, pendingReinforcements: 0);

      var dominated = false;
      for (var i = 0; i < 9 && !dominated; i++) {
        final from = state.territories['t1']!;
        if (from.armyCount <= 1) break;
        final troops = (from.armyCount - 1).clamp(1, 3);
        state = GameEngine.apply(state, _attack('t1', 't2', troops, seq: i));
        dominated = state.newlyDominatedRegionId == 'regionA';
      }

      expect(dominated, isTrue, reason: 'Expected regionA domination within a few attacks');
    });

    test('does not re-flag a region the player already fully controlled before this attack', () {
      // p0 already owns all of regionA (t1, t2). Conquering t3 (adjacent to
      // t2) does not complete regionB (p1 still holds t4), and regionA was
      // never "newly" dominated by this attack — it already was.
      var state = withOwnership(freshTestState(), {
        't1': 'p0', 't2': 'p0', 't3': 'p1', 't4': 'p1',
      }, {'t2': 10, 't3': 1});
      state = state.copyWith(phase: GamePhase.attack, pendingReinforcements: 0);

      var conquered = false;
      for (var i = 0; i < 9 && !conquered; i++) {
        final from = state.territories['t2']!;
        if (from.armyCount <= 1) break;
        final troops = (from.armyCount - 1).clamp(1, 3);
        state = GameEngine.apply(state, _attack('t2', 't3', troops, seq: i));
        conquered = state.territories['t3']!.ownerId == 'p0';
      }

      expect(conquered, isTrue);
      expect(state.newlyDominatedRegionId, isNull);
    });

    test('attacking without completing a region leaves newlyDominatedRegionId null', () {
      var state = withOwnership(freshTestState(), {
        't1': 'p0', 't2': 'p1', 't3': 'p1', 't4': 'p1',
      }, {'t1': 10, 't2': 5});
      state = state.copyWith(phase: GamePhase.attack, pendingReinforcements: 0);

      // Attack but with defender strong enough that conquest is very
      // unlikely on the very first roll — instead, directly assert the
      // *shape* of the rule using a losing/partial roll: run one attack and
      // check that whenever the territory is not conquered, the flag stays
      // null regardless of RNG outcome.
      final result = GameEngine.apply(state, _attack('t1', 't2', 3, seq: 0));
      if (!result.activeBattle!.rolls.last.territoryConquered) {
        expect(result.newlyDominatedRegionId, isNull);
      }
    });
  });
}
