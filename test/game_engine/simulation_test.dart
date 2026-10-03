// Full-match simulation: drives every player as a bot, from `newMatch` all
// the way to `GamePhase.gameOver`, across many seeds and player counts, on
// the real production map (`data/maps/biblical_lands_v1.json`). This is the
// strongest signal that the core loop (section 51) actually works end to
// end — a unit test can pass while a full match still deadlocks or throws.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:reinos_engine/game_engine/domain/bot_difficulty.dart';
import 'package:reinos_engine/game_engine/domain/game_map.dart';
import 'package:reinos_engine/game_engine/domain/player_color.dart';
import 'package:reinos_engine/game_engine/domain/rules_config.dart';
import 'package:reinos_engine/game_engine/engine/bot_strategy.dart';
import 'package:reinos_engine/game_engine/engine/game_engine.dart';
import 'package:reinos_engine/game_engine/state/game_action.dart';
import 'package:reinos_engine/game_engine/state/game_phase.dart';
import 'package:reinos_engine/game_engine/state/game_state.dart';

GameMap loadProductionMap() {
  final raw = File('data/maps/biblical_lands_v1.json').readAsStringSync();
  return GameMap.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

RulesConfig loadProductionRules() {
  final raw = File('data/rules/default_rules.json').readAsStringSync();
  return RulesConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

/// Minimal standalone bot driver (deliberately independent of
/// `GameController`/Riverpod, so this test exercises nothing but
/// `game_engine` + `BotStrategy`). Mirrors the same decision logic the real
/// UI controller uses to drive bot turns.
class _MatchSimulation {
  GameState state;
  int _sequence = 0;

  _MatchSimulation(this.state);

  GameAction _withSeq(GameAction Function(int seq) build) => build(_sequence++);

  GameState run({int maxActions = 4000}) {
    for (var i = 0; i < maxActions; i++) {
      if (state.phase == GamePhase.gameOver) return state;
      _step();
    }
    throw StateError(
        'Match did not reach gameOver within $maxActions actions (possible soft-lock).');
  }

  void _step() {
    final playerId = state.currentPlayer.id;
    switch (state.phase) {
      case GamePhase.reinforcement:
        final tradeIn = BotStrategy.decideCardTradeIn(state, playerId);
        if (tradeIn != null) {
          state = GameEngine.apply(
            state,
            _withSeq((seq) => PlayCardAction(
                  gameId: state.gameId,
                  playerId: playerId,
                  timestamp: DateTime.now(),
                  sequenceNumber: seq,
                  cardIds: tradeIn,
                )),
          );
          return;
        }
        continue reinforcementPlacement;

      reinforcementPlacement:
      case GamePhase.initialPlacement:
        if (state.pendingReinforcements > 0) {
          final placement = BotStrategy.decideReinforcementPlacement(
            state,
            playerId,
            state.pendingReinforcements,
            difficulty: state.currentPlayer.botDifficulty,
          );
          if (placement.isEmpty) {
            _endPhase(playerId);
          } else if (state.phase == GamePhase.initialPlacement) {
            final entry = placement.entries.first;
            state = GameEngine.apply(
              state,
              _withSeq((seq) => PlaceArmyAction(
                    gameId: state.gameId,
                    playerId: playerId,
                    timestamp: DateTime.now(),
                    sequenceNumber: seq,
                    territoryId: entry.key,
                    count: entry.value,
                  )),
            );
          } else {
            state = GameEngine.apply(
              state,
              _withSeq((seq) => ReinforceAction(
                    gameId: state.gameId,
                    playerId: playerId,
                    timestamp: DateTime.now(),
                    sequenceNumber: seq,
                    armiesByTerritory: placement,
                  )),
            );
          }
        } else {
          _endPhase(playerId);
        }
        return;

      case GamePhase.attack:
        final decision = BotStrategy.decideNextAttack(
          state,
          playerId,
          difficulty: state.currentPlayer.botDifficulty,
        );
        if (decision == null) {
          _endPhase(playerId);
        } else {
          state = GameEngine.apply(
            state,
            _withSeq((seq) => AttackAction(
                  gameId: state.gameId,
                  playerId: playerId,
                  timestamp: DateTime.now(),
                  sequenceNumber: seq,
                  fromTerritoryId: decision.fromTerritoryId,
                  toTerritoryId: decision.toTerritoryId,
                  troopCount: decision.troopCount,
                )),
          );
        }
        return;

      case GamePhase.fortification:
        _endPhase(playerId);
        return;

      default:
        throw StateError('Unexpected phase during simulation: ${state.phase}');
    }
  }

  void _endPhase(String playerId) {
    state = GameEngine.apply(
      state,
      _withSeq((seq) => EndPhaseAction(
            gameId: state.gameId,
            playerId: playerId,
            timestamp: DateTime.now(),
            sequenceNumber: seq,
          )),
    );
  }
}

void main() {
  final map = loadProductionMap();
  final rules = loadProductionRules();

  group('Full-match simulation on the production map', () {
    for (final playerCount in [2, 3, 4]) {
      for (final seed in List.generate(30, (i) => i + 1)) {
        test('$playerCount bots, seed=$seed reach gameOver with a valid winner', () {
          final configs = [
            for (var i = 0; i < playerCount; i++)
              PlayerConfig(
                id: 'p$i',
                displayName: 'Bot $i',
                color: PlayerColor.values[i],
                isBot: true,
                // Cycle every difficulty so the simulation exercises all of
                // BotStrategy's difficulty-dependent branches, not just the
                // (unspecified-difficulty) default.
                botDifficulty: BotDifficulty.values[i % BotDifficulty.values.length],
              ),
          ];
          final initial =
              GameEngine.newMatch(map: map, configs: configs, rules: rules, seed: seed * 1000);
          final simulation = _MatchSimulation(initial);

          final result = simulation.run();

          expect(result.phase, GamePhase.gameOver);
          expect(result.winnerId, isNotNull);
          expect(configs.map((c) => c.id), contains(result.winnerId));

          // Total armies on the board must never exceed what a fully-loaded
          // map could plausibly hold — guards against a duplication bug in
          // conquest/reinforcement arithmetic.
          final totalArmies =
              result.territories.values.fold<int>(0, (sum, t) => sum + t.armyCount);
          expect(totalArmies, greaterThan(0));
          expect(totalArmies, lessThan(2000));

          // Every territory still belongs to a player who is alive.
          for (final territory in result.territories.values) {
            final owner = result.players.firstWhere((p) => p.id == territory.ownerId);
            expect(owner.isEliminated, isFalse,
                reason: '${territory.id} is owned by an eliminated player');
          }
        });
      }
    }
  });
}
