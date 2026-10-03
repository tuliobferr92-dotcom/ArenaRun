import 'dart:convert';

import 'package:reinos_engine/game_engine/engine/game_exceptions.dart';
import 'package:reinos_engine/game_engine/state/game_action.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'room_registry.dart';
import 'server_content_repository.dart';

/// One JSON-over-WebSocket relay: every connection speaks the same small
/// protocol regardless of which room it ends up in.
///
/// Client -> server messages (`type`):
///   - `createRoom`: {mapId, players: [{id, displayName, color, isBot?,
///     botDifficulty?}], seed, hostPlayerId}
///   - `joinRoom`: {roomCode, playerId}
///   - `action`: {roomCode, playerId, action: GameAction.toJson()}
///
/// Server -> client messages (`type`):
///   - `roomCreated` / `joined`: {roomCode, playerId, state}
///   - `stateUpdate`: {roomCode, state, appliedActions: [GameAction.toJson()]}
///   - `playerConnected` / `playerDisconnected`: {roomCode, playerId}
///   - `error`: {message}
class RelayServer {
  final RoomRegistry rooms;
  final ServerContentRepository content;

  RelayServer({required this.rooms, required this.content});

  Handler get handler => webSocketHandler(_onConnect);

  void _onConnect(WebSocketChannel socket, String? protocol) {
    // The room/playerId this specific connection is attached to, once it
    // has created or joined one — a connection belongs to at most one
    // room for its whole lifetime.
    String? attachedRoomCode;
    String? attachedPlayerId;

    socket.stream.listen(
      (raw) async {
        Map<String, dynamic> message;
        try {
          message = jsonDecode(raw as String) as Map<String, dynamic>;
        } catch (_) {
          _sendError(socket, 'Malformed JSON message.');
          return;
        }

        try {
          switch (message['type']) {
            case 'createRoom':
              final result = await _handleCreateRoom(socket, message);
              attachedRoomCode = result?.roomCode;
              attachedPlayerId = result?.playerId;
              break;

            case 'joinRoom':
              final result = _handleJoinRoom(socket, message);
              attachedRoomCode = result?.roomCode;
              attachedPlayerId = result?.playerId;
              break;

            case 'action':
              _handleAction(socket, message);
              break;

            default:
              _sendError(socket, 'Unknown message type: ${message['type']}');
          }
        } catch (e) {
          _sendError(socket, e.toString());
        }
      },
      onDone: () {
        if (attachedRoomCode != null && attachedPlayerId != null) {
          final room = rooms.find(attachedRoomCode!);
          if (room != null) {
            room.detach(attachedPlayerId!);
            room.broadcast({
              'type': 'playerDisconnected',
              'roomCode': attachedRoomCode,
              'playerId': attachedPlayerId,
            });
            rooms.removeIfEmpty(attachedRoomCode!);
          }
        }
      },
    );
  }

  Future<({String roomCode, String playerId})?> _handleCreateRoom(
    WebSocketChannel socket,
    Map<String, dynamic> message,
  ) async {
    final mapId = message['mapId'] as String;
    final seed = message['seed'] as int;
    final hostPlayerId = message['hostPlayerId'] as String;
    final players = decodePlayerConfigs(message['players'] as List<dynamic>);

    final map = await content.loadMap(mapId);
    final rules = await content.loadRules();
    final room = rooms.createRoom(map: map, rules: rules, players: players, seed: seed);
    room.attach(hostPlayerId, socket);

    socket.sink.add(jsonEncode({
      'type': 'roomCreated',
      'roomCode': room.code,
      'playerId': hostPlayerId,
      'state': room.state.toJson(),
    }));
    return (roomCode: room.code, playerId: hostPlayerId);
  }

  ({String roomCode, String playerId})? _handleJoinRoom(
    WebSocketChannel socket,
    Map<String, dynamic> message,
  ) {
    final roomCode = message['roomCode'] as String;
    final playerId = message['playerId'] as String;
    final room = rooms.find(roomCode);
    if (room == null) {
      _sendError(socket, 'Room $roomCode not found.');
      return null;
    }
    final isKnownSeat = room.state.players.any((p) => p.id == playerId);
    if (!isKnownSeat) {
      _sendError(socket, 'Player $playerId is not part of room $roomCode.');
      return null;
    }

    room.attach(playerId, socket);
    socket.sink.add(jsonEncode({
      'type': 'joined',
      'roomCode': room.code,
      'playerId': playerId,
      'state': room.state.toJson(),
    }));
    room.broadcast({'type': 'playerConnected', 'roomCode': room.code, 'playerId': playerId});
    return (roomCode: roomCode, playerId: playerId);
  }

  void _handleAction(WebSocketChannel socket, Map<String, dynamic> message) {
    final roomCode = message['roomCode'] as String;
    final playerId = message['playerId'] as String;
    final room = rooms.find(roomCode);
    if (room == null) {
      _sendError(socket, 'Room $roomCode not found.');
      return;
    }

    final action = gameActionFromJson(message['action'] as Map<String, dynamic>);
    try {
      final applied = room.applyFromClient(playerId, action);
      room.broadcast({
        'type': 'stateUpdate',
        'roomCode': room.code,
        'state': room.state.toJson(),
        'appliedActions': applied.map((a) => a.toJson()).toList(),
      });
    } on InvalidActionException catch (e) {
      _sendError(socket, e.reason);
    } on StateError catch (e) {
      _sendError(socket, e.message);
    }
  }

  void _sendError(WebSocketChannel socket, String message) {
    socket.sink.add(jsonEncode({'type': 'error', 'message': message}));
  }
}
