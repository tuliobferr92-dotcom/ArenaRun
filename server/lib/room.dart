import 'dart:convert';

import 'package:reinos_engine/game_engine/engine/game_engine.dart';
import 'package:reinos_engine/game_engine/engine/game_exceptions.dart';
import 'package:reinos_engine/game_engine/state/game_action.dart';
import 'package:reinos_engine/game_engine/state/game_state.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'bot_driver.dart';

/// One online match: the authoritative [GameState], every connected
/// human player's socket, and the strictly increasing action log that
/// [GameEngine.apply] has replayed to reach the current state.
///
/// The server is the single source of truth (section 36/37) — a client
/// never applies its own optimistic [GameAction]; it sends the action and
/// waits for the broadcast `stateUpdate` the server computes here.
class Room {
  final String code;
  GameState state;
  final List<GameAction> actionLog = [];

  /// Connected sockets, keyed by playerId. A player slot from the
  /// original `GameEngine.newMatch` configs with no entry here is either
  /// a bot or a human who hasn't connected yet.
  final Map<String, WebSocketChannel> sockets = {};

  int _sequence = 0;

  Room({required this.code, required this.state});

  int get _nextSeq => _sequence++;

  /// All non-bot player ids from the match configuration, in player order.
  List<String> get humanPlayerIds =>
      state.players.where((p) => !p.isBot).map((p) => p.id).toList();

  void attach(String playerId, WebSocketChannel socket) {
    sockets[playerId] = socket;
  }

  void detach(String playerId) {
    sockets.remove(playerId);
  }

  bool get isEmpty => sockets.isEmpty;

  /// Validates and applies a client-submitted action, then drives any
  /// consecutive bot turns. Throws [InvalidActionException] on a rule
  /// violation and [StateError] if [senderPlayerId] doesn't match the
  /// action's own `playerId` (a client can only ever act as itself —
  /// never on behalf of another seat, bot or human).
  List<GameAction> applyFromClient(String senderPlayerId, GameAction action) {
    if (action.playerId != senderPlayerId) {
      throw StateError('Player $senderPlayerId attempted to act as ${action.playerId}');
    }
    final resequenced = _withSequence(action, _nextSeq);
    final result = BotDriver.applyAndDriveBots(state, resequenced, () => _nextSeq);
    state = result.state;
    actionLog.addAll(result.applied);
    return result.applied;
  }

  GameAction _withSequence(GameAction action, int seq) {
    return switch (action) {
      PlaceArmyAction a => PlaceArmyAction(
          gameId: a.gameId,
          playerId: a.playerId,
          timestamp: a.timestamp,
          sequenceNumber: seq,
          territoryId: a.territoryId,
          count: a.count,
        ),
      ReinforceAction a => ReinforceAction(
          gameId: a.gameId,
          playerId: a.playerId,
          timestamp: a.timestamp,
          sequenceNumber: seq,
          armiesByTerritory: a.armiesByTerritory,
        ),
      AttackAction a => AttackAction(
          gameId: a.gameId,
          playerId: a.playerId,
          timestamp: a.timestamp,
          sequenceNumber: seq,
          fromTerritoryId: a.fromTerritoryId,
          toTerritoryId: a.toTerritoryId,
          troopCount: a.troopCount,
        ),
      MoveArmyAction a => MoveArmyAction(
          gameId: a.gameId,
          playerId: a.playerId,
          timestamp: a.timestamp,
          sequenceNumber: seq,
          fromTerritoryId: a.fromTerritoryId,
          toTerritoryId: a.toTerritoryId,
          count: a.count,
        ),
      PlayCardAction a => PlayCardAction(
          gameId: a.gameId,
          playerId: a.playerId,
          timestamp: a.timestamp,
          sequenceNumber: seq,
          cardIds: a.cardIds,
        ),
      AnswerChallengeAction a => AnswerChallengeAction(
          gameId: a.gameId,
          playerId: a.playerId,
          timestamp: a.timestamp,
          sequenceNumber: seq,
          challengeId: a.challengeId,
          correct: a.correct,
        ),
      PlayEventCardAction a => PlayEventCardAction(
          gameId: a.gameId,
          playerId: a.playerId,
          timestamp: a.timestamp,
          sequenceNumber: seq,
          eventCardId: a.eventCardId,
          targetTerritoryId: a.targetTerritoryId,
        ),
      EndPhaseAction a => EndPhaseAction(
          gameId: a.gameId,
          playerId: a.playerId,
          timestamp: a.timestamp,
          sequenceNumber: seq,
        ),
      _ => throw StateError('Unhandled GameAction subtype: ${action.runtimeType}'),
    };
  }

  /// Sends [message] (a JSON-encodable map) to every connected socket.
  void broadcast(Map<String, dynamic> message) {
    final encoded = jsonEncode(message);
    for (final socket in sockets.values) {
      socket.sink.add(encoded);
    }
  }

  /// Sends [message] to just one connected player, if still connected.
  void sendTo(String playerId, Map<String, dynamic> message) {
    sockets[playerId]?.sink.add(jsonEncode(message));
  }
}
