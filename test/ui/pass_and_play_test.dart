import 'package:flutter_test/flutter_test.dart';
import 'package:reinos/game_engine/domain/bot_difficulty.dart';
import 'package:reinos/game_engine/domain/player_color.dart';
import 'package:reinos/game_engine/engine/game_engine.dart';
import 'package:reinos/ui/widgets/pass_and_play.dart';

import '../game_engine/test_fixtures.dart';

void main() {
  group('needsPassAndPlay', () {
    test('false with a single human (no one to hide the board from)', () {
      final state = GameEngine.newMatch(
        map: buildTestMap(),
        configs: const [
          PlayerConfig(id: 'p0', displayName: 'Jogador 1', color: PlayerColor.blue),
          PlayerConfig(id: 'p1', displayName: 'Bot', color: PlayerColor.red, isBot: true),
        ],
        rules: testRules,
        seed: 1,
      );

      expect(needsPassAndPlay(state, null), isFalse);
    });

    test('true for the first human turn of a multi-human match (nobody has confirmed yet)', () {
      final state = GameEngine.newMatch(
        map: buildTestMap(),
        configs: const [
          PlayerConfig(id: 'p0', displayName: 'Jogador 1', color: PlayerColor.blue),
          PlayerConfig(id: 'p1', displayName: 'Jogador 2', color: PlayerColor.red),
        ],
        rules: testRules,
        seed: 1,
      );

      expect(needsPassAndPlay(state, null), isTrue);
    });

    test('false once the current player has already confirmed', () {
      final state = GameEngine.newMatch(
        map: buildTestMap(),
        configs: const [
          PlayerConfig(id: 'p0', displayName: 'Jogador 1', color: PlayerColor.blue),
          PlayerConfig(id: 'p1', displayName: 'Jogador 2', color: PlayerColor.red),
        ],
        rules: testRules,
        seed: 1,
      );

      expect(needsPassAndPlay(state, state.currentPlayer.id), isFalse);
    });

    test('true again once the turn passes to the other human', () {
      final state = GameEngine.newMatch(
        map: buildTestMap(),
        configs: const [
          PlayerConfig(id: 'p0', displayName: 'Jogador 1', color: PlayerColor.blue),
          PlayerConfig(id: 'p1', displayName: 'Jogador 2', color: PlayerColor.red),
        ],
        rules: testRules,
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
        map: buildTestMap(),
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
        rules: testRules,
        seed: 1,
      );
      final botTurn = state.copyWith(currentPlayerIndex: 2);

      expect(needsPassAndPlay(botTurn, null), isFalse);
    });
  });
}
