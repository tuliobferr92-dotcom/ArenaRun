import 'package:reinos_engine/game_engine/engine/bot_strategy.dart';
import 'package:reinos_engine/game_engine/engine/game_engine.dart';
import 'package:reinos_engine/game_engine/state/game_action.dart';
import 'package:reinos_engine/game_engine/state/game_phase.dart';
import 'package:reinos_engine/game_engine/state/game_state.dart';

/// Server-side mirror of `GameController._runBotLoopIfNeeded`/`_stepBot`
/// (the Flutter app's client-side bot driver). Online matches have no
/// client to drive bots — if a room includes `isBot` players, the server
/// itself must call `BotStrategy` after every state change, exactly as the
/// offline app does, so a bot opponent works the same in both modes.
///
/// Never touches the RNG directly: it only decides which [GameAction] to
/// dispatch — `BattleEngine` alone resolves dice, from the same
/// `GameEngine.apply` used for every other action (section 38/44).
class BotDriver {
  /// Applies [action] via [GameEngine.apply], then drives every
  /// consecutive bot turn until a human must act or the match ends.
  /// [nextSeq] supplies a fresh, monotonically increasing sequence number
  /// for each bot-generated action, so the room's action log stays
  /// strictly ordered. Returns the resulting state and the full ordered
  /// list of actions applied (the triggering action first, then any bot
  /// actions), so the caller can broadcast each step for replay-quality
  /// logs.
  static ({GameState state, List<GameAction> applied}) applyAndDriveBots(
    GameState state,
    GameAction action,
    int Function() nextSeq,
  ) {
    var next = GameEngine.apply(state, action);
    final applied = <GameAction>[action];

    var guard = 0;
    while (next.phase != GamePhase.gameOver && next.currentPlayer.isBot && guard < 200) {
      guard++;
      final botAction = _decideBotAction(next, nextSeq);
      if (botAction == null) break;
      final after = GameEngine.apply(next, botAction);
      applied.add(botAction);
      if (after == next) break; // safety: avoid infinite loop on no-op
      next = after;
    }

    return (state: next, applied: applied);
  }

  static GameAction? _decideBotAction(GameState s, int Function() nextSeq) {
    final playerId = s.currentPlayer.id;
    switch (s.phase) {
      case GamePhase.reinforcement:
        final tradeIn = BotStrategy.decideCardTradeIn(s, playerId);
        if (tradeIn != null) {
          return PlayCardAction(
            gameId: s.gameId,
            playerId: playerId,
            timestamp: DateTime.now(),
            sequenceNumber: nextSeq(),
            cardIds: tradeIn,
          );
        }
        return _reinforcementAction(s, playerId, nextSeq);

      case GamePhase.initialPlacement:
        return _reinforcementAction(s, playerId, nextSeq);

      case GamePhase.attack:
        final decision =
            BotStrategy.decideNextAttack(s, playerId, difficulty: s.currentPlayer.botDifficulty);
        if (decision == null) {
          return EndPhaseAction(
            gameId: s.gameId,
            playerId: playerId,
            timestamp: DateTime.now(),
            sequenceNumber: nextSeq(),
          );
        }
        return AttackAction(
          gameId: s.gameId,
          playerId: playerId,
          timestamp: DateTime.now(),
          sequenceNumber: nextSeq(),
          fromTerritoryId: decision.fromTerritoryId,
          toTerritoryId: decision.toTerritoryId,
          troopCount: decision.troopCount,
        );

      case GamePhase.fortification:
        return EndPhaseAction(
          gameId: s.gameId,
          playerId: playerId,
          timestamp: DateTime.now(),
          sequenceNumber: nextSeq(),
        );

      default:
        return null;
    }
  }

  static GameAction? _reinforcementAction(
    GameState s,
    String playerId,
    int Function() nextSeq,
  ) {
    if (s.pendingReinforcements <= 0) {
      return EndPhaseAction(
        gameId: s.gameId,
        playerId: playerId,
        timestamp: DateTime.now(),
        sequenceNumber: nextSeq(),
      );
    }
    final placement = BotStrategy.decideReinforcementPlacement(
      s,
      playerId,
      s.pendingReinforcements,
      difficulty: s.currentPlayer.botDifficulty,
    );
    if (placement.isEmpty) {
      return EndPhaseAction(
        gameId: s.gameId,
        playerId: playerId,
        timestamp: DateTime.now(),
        sequenceNumber: nextSeq(),
      );
    }
    if (s.phase == GamePhase.initialPlacement) {
      final entry = placement.entries.first;
      return PlaceArmyAction(
        gameId: s.gameId,
        playerId: playerId,
        timestamp: DateTime.now(),
        sequenceNumber: nextSeq(),
        territoryId: entry.key,
        count: entry.value,
      );
    }
    return ReinforceAction(
      gameId: s.gameId,
      playerId: playerId,
      timestamp: DateTime.now(),
      sequenceNumber: nextSeq(),
      armiesByTerritory: placement,
    );
  }
}
