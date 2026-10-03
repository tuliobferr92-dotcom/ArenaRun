import 'dart:convert';
import 'dart:io';

import 'package:async/async.dart' show StreamQueue;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:reinos_server/relay_server.dart';
import 'package:reinos_server/room_registry.dart';
import 'package:reinos_server/server_content_repository.dart';

/// End-to-end: boots the real relay server (same `RelayServer` the
/// production `bin/server.dart` serves) on an ephemeral local port and
/// drives it with two live WebSocket clients, exactly as two phones would.
/// This is the local verification step for task #43/#45 — proof the
/// server-authoritative flow actually works end to end, not just that
/// its pieces compile.
void main() {
  late HttpServer httpServer;
  late String wsUrl;

  setUp(() async {
    final relay = RelayServer(rooms: RoomRegistry(), content: ServerContentRepository());
    final pipeline = const Pipeline().addHandler(relay.handler);
    httpServer = await shelf_io.serve(pipeline, InternetAddress.loopbackIPv4, 0);
    wsUrl = 'ws://127.0.0.1:${httpServer.port}';
  });

  tearDown(() async {
    await httpServer.close(force: true);
  });

  Future<Map<String, dynamic>> nextMessage(StreamQueue<dynamic> queue) async {
    final raw = await queue.next;
    return jsonDecode(raw as String) as Map<String, dynamic>;
  }

  test('two human players can create, join and play through a real room', () async {
    final host = WebSocketChannel.connect(Uri.parse(wsUrl));
    final guest = WebSocketChannel.connect(Uri.parse(wsUrl));
    final hostQueue = StreamQueue(host.stream);
    final guestQueue = StreamQueue(guest.stream);

    host.sink.add(jsonEncode({
      'type': 'createRoom',
      'mapId': 'biblical_lands_v1',
      'hostPlayerId': 'p0',
      'seed': 1,
      'players': [
        {'id': 'p0', 'displayName': 'Jogador 1', 'color': 'blue'},
        {'id': 'p1', 'displayName': 'Jogador 2', 'color': 'red'},
      ],
    }));

    final created = await nextMessage(hostQueue);
    expect(created['type'], 'roomCreated');
    final roomCode = created['roomCode'] as String;
    expect(roomCode, startsWith('REINO-'));
    expect(created['state'], isNotNull);

    guest.sink.add(jsonEncode({'type': 'joinRoom', 'roomCode': roomCode, 'playerId': 'p1'}));
    final joined = await nextMessage(guestQueue);
    expect(joined['type'], 'joined');
    expect(joined['roomCode'], roomCode);

    // `playerConnected` is broadcast to every socket in the room, including
    // the one that just joined — both queues have it next.
    final hostNotifiedOfJoin = await nextMessage(hostQueue);
    expect(hostNotifiedOfJoin['type'], 'playerConnected');
    expect(hostNotifiedOfJoin['playerId'], 'p1');
    final guestNotifiedOfJoin = await nextMessage(guestQueue);
    expect(guestNotifiedOfJoin['type'], 'playerConnected');

    final currentPlayerId = _currentPlayerId(joined['state'] as Map<String, dynamic>);

    final actingSocket = currentPlayerId == 'p0' ? host : guest;
    final actingQueue = currentPlayerId == 'p0' ? hostQueue : guestQueue;
    final observerQueue = currentPlayerId == 'p0' ? guestQueue : hostQueue;

    actingSocket.sink.add(jsonEncode({
      'type': 'action',
      'roomCode': roomCode,
      'playerId': currentPlayerId,
      'action': {
        'type': 'placeArmy',
        'gameId': created['state']['gameId'],
        'playerId': currentPlayerId,
        'timestamp': DateTime.now().toIso8601String(),
        'sequenceNumber': 0,
        'territoryId': _firstOwnedTerritory(
          joined['state'] as Map<String, dynamic>,
          currentPlayerId!,
        ),
        'count': 1,
      },
    }));

    final updateOnActor = await nextMessage(actingQueue);
    expect(updateOnActor['type'], 'stateUpdate');
    expect(updateOnActor['roomCode'], roomCode);
    expect(updateOnActor['appliedActions'], isNotEmpty);

    final updateOnObserver = await nextMessage(observerQueue);
    expect(updateOnObserver['type'], 'stateUpdate');
    expect(updateOnObserver['state'], updateOnActor['state']);

    await host.sink.close();
    await guest.sink.close();
  });

  test('a room rejects an action sent on behalf of another player', () async {
    final host = WebSocketChannel.connect(Uri.parse(wsUrl));
    final hostQueue = StreamQueue(host.stream);

    host.sink.add(jsonEncode({
      'type': 'createRoom',
      'mapId': 'biblical_lands_v1',
      'hostPlayerId': 'p0',
      'seed': 1,
      'players': [
        {'id': 'p0', 'displayName': 'Jogador 1', 'color': 'blue'},
        {'id': 'p1', 'displayName': 'Jogador 2', 'color': 'red', 'isBot': true},
      ],
    }));
    final created = await nextMessage(hostQueue);
    final roomCode = created['roomCode'] as String;

    host.sink.add(jsonEncode({
      'type': 'action',
      'roomCode': roomCode,
      'playerId': 'p0',
      'action': {
        'type': 'placeArmy',
        'gameId': created['state']['gameId'],
        'playerId': 'p1', // spoofing another seat
        'timestamp': DateTime.now().toIso8601String(),
        'sequenceNumber': 0,
        'territoryId': 'jerusalem',
        'count': 1,
      },
    }));

    final response = await nextMessage(hostQueue);
    expect(response['type'], 'error');

    await host.sink.close();
  });
}

String? _currentPlayerId(Map<String, dynamic> state) {
  final players = state['players'] as List<dynamic>;
  final index = state['currentPlayerIndex'] as int;
  return (players[index] as Map<String, dynamic>)['id'] as String;
}

String _firstOwnedTerritory(Map<String, dynamic> state, String playerId) {
  final territories = state['territories'] as List<dynamic>;
  final owned = territories.firstWhere(
    (t) => (t as Map<String, dynamic>)['ownerId'] == playerId,
  ) as Map<String, dynamic>;
  return owned['id'] as String;
}
