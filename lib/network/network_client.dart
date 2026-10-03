import 'dart:async';
import 'dart:convert';

import 'package:reinos_engine/game_engine/state/game_action.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Thin JSON-over-WebSocket client for the REINOS online-multiplayer relay
/// (section 36/37). Speaks the exact same `type`-tagged message protocol
/// documented in `server/README.md` — this class owns no game rules of its
/// own; `GameController` decides what each message means.
class NetworkClient {
  final WebSocketChannel _channel;
  final StreamController<Map<String, dynamic>> _messages =
      StreamController<Map<String, dynamic>>.broadcast();
  StreamSubscription<dynamic>? _subscription;

  NetworkClient._(this._channel) {
    _subscription = _channel.stream.listen(
      (raw) => _messages.add(jsonDecode(raw as String) as Map<String, dynamic>),
      onDone: () => _messages.close(),
      onError: (Object error, StackTrace stack) => _messages.addError(error, stack),
    );
  }

  factory NetworkClient.connect(String serverUrl) {
    return NetworkClient._(WebSocketChannel.connect(Uri.parse(serverUrl)));
  }

  Stream<Map<String, dynamic>> get messages => _messages.stream;

  void _send(Map<String, dynamic> message) => _channel.sink.add(jsonEncode(message));

  void createRoom({
    required String mapId,
    required String hostPlayerId,
    required int seed,
    required List<Map<String, dynamic>> players,
  }) {
    _send({
      'type': 'createRoom',
      'mapId': mapId,
      'hostPlayerId': hostPlayerId,
      'seed': seed,
      'players': players,
    });
  }

  void joinRoom({required String roomCode, required String playerId}) {
    _send({'type': 'joinRoom', 'roomCode': roomCode, 'playerId': playerId});
  }

  void sendAction({
    required String roomCode,
    required String playerId,
    required GameAction action,
  }) {
    _send({
      'type': 'action',
      'roomCode': roomCode,
      'playerId': playerId,
      'action': action.toJson(),
    });
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _channel.sink.close();
    if (!_messages.isClosed) await _messages.close();
  }
}
