import 'package:flutter_test/flutter_test.dart';
import 'package:reinos/ui/widgets/pass_and_play.dart';
import 'package:reinos_engine/game_engine/domain/bot_difficulty.dart';
import 'package:reinos_engine/game_engine/domain/game_map.dart';
import 'package:reinos_engine/game_engine/domain/player_color.dart';
import 'package:reinos_engine/game_engine/domain/region.dart';
import 'package:reinos_engine/game_engine/domain/rules_config.dart';
import 'package:reinos_engine/game_engine/domain/territory.dart';
import 'package:reinos_engine/game_engine/engine/game_engine.dart';

/// A tiny 2-territory map — just enough for `GameEngine.newMatch` to build
/// a structurally valid `GameState`; this test only exercises
/// `needsPassAndPlay`'s gating logic, not board geometry.
GameMap _tinyMap() {
  Territory t(String id, List<String> neighbors) => Territory(
        id: id,
        name: id,
        regionId: 'r',
        neighborIds: neighbors,
        polygon: const [Offset2D(0, 0), Offset2D(1, 0), Offset2D(1, 1), Offset2D(0, 1)],
        centroid: const Offset2D(0.5, 0.5),
        biblicalReferences: const [],
        historicalPeriodId: 'test',
        description: '',
      );
  return GameMap(
    id: 'tiny_map',
    name: 'Tiny Map',
    periodId: 'test',
    regions: {'r': const Region(id: 'r', name: 'r', territoryIds: ['t1', 't2'], controlBonus: 0)},
    territories: {'t1': t('t1', ['t2']), 't2': t('t2', ['t1'])},
  );
}

void main() {
  group('needsPassAndPlay', () {
    test('false with a single human (no one to hide the board from)', () {
      final state = GameEngine.newMatch(
        map: _tinyMap(),
        configs: const [
          PlayerConfig(id: 'p0', displayName: 'Jogador 1', color: PlayerColor.blue),
          PlayerConfig(id: 'p1', displayName: 'Bot', color: PlayerColor.red, isBot: true),
        ],
        rules: RulesConfig.defaults,
        seed: 1,
      );

      expect(needsPassAndPlay(state, null), isFalse);
    });

    test('true for the first human turn of a multi-human match (nobody has confirmed yet)', () {
      final state = GameEngine.newMatch(
        map: _tinyMap(),
        configs: const [
          PlayerConfig(id: 'p0', displayName: 'Jogador 1', color: PlayerColor.blue),
          PlayerConfig(id: 'p1', displayName: 'Jogador 2', color: PlayerColor.red),
        ],
        rules: RulesConfig.defaults,
        seed: 1,
      );

      expect(needsPassAndPlay(state, null), isTrue);
    });

    test('false once the current player has already confirmed', () {
      final state = GameEngine.newMatch(
        map: _tinyMap(),
        configs: const [
          PlayerConfig(id: 'p0', displayName: 'Jogador 1', color: PlayerColor.blue),
          PlayerConfig(id: 'p1', displayName: 'Jogador 2', color: PlayerColor.red),
        ],
        rules: RulesConfig.defaults,
        seed: 1,
      );

      expect(needsPassAndPlay(state, state.currentPlayer.id), isFalse);
    });

    test('true again once the turn passes to the other human', () {
      final state = GameEngine.newMatch(
        map: _tinyMap(),
        configs: const [
          PlayerConfig(id: 'p0', displayName: 'Jogador 1', color: PlayerColor.blue),
          PlayerConfig(id: 'p1', displayName: 'Jogador 2', color: PlayerColor.red),
        ],
        rules: RulesConfig.defaults,
        seed: 1,
      );
      final confirmedForP0 = state.currentPlayer.id;
      final movedToOtherPlayer = state.copyWith(
        currentPlayerIndex: (state.currentPlayerIndex + 1) % state.players.length,
      );

      expect(needsPassAndPlay(movedToOtherPlayer, confirmedForP0), isTrue);
    });

    test('never gates on a bot\'s turn, even with multiple humans elsewhere', () {
      final state = GameEngine.newMatch(
        map: _tinyMap(),
        configs: const [
          PlayerConfig(id: 'p0', displayName: 'Jogador 1', color: PlayerColor.blue),
          PlayerConfig(id: 'p1', displayName: 'Jogador 2', color: PlayerColor.red),
          PlayerConfig(
            id: 'p2',
            displayName: 'Bot',
            color: PlayerColor.green,
            isBot: true,
            botDifficulty: BotDifficulty.normal,
          ),
        ],
        rules: RulesConfig.defaults,
        seed: 1,
      );
      final botTurn = state.copyWith(currentPlayerIndex: 2);

      expect(needsPassAndPlay(botTurn, null), isFalse);
    });
  });
}
