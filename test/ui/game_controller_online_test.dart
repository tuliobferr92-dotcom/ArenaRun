import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import 'package:reinos/content/content_repository.dart';
import 'package:reinos/services/save_game_service.dart';
import 'package:reinos/ui/game_controller.dart';
import 'package:reinos_engine/content/domain/bible_challenge.dart';
import 'package:reinos_engine/game_engine/domain/game_map.dart';
import 'package:reinos_engine/game_engine/domain/player_color.dart';
import 'package:reinos_engine/game_engine/domain/rules_config.dart';
import 'package:reinos_engine/game_engine/engine/game_engine.dart';
import 'package:reinos_engine/game_engine/state/game_state.dart';
import 'package:reinos_server/relay_server.dart';
import 'package:reinos_server/room_registry.dart';
import 'package:reinos_server/server_content_repository.dart';

/// [ContentRepository]/[SaveGameService] are never touched by the online
/// flow (`createOnlineRoom`/`joinOnlineRoom` bypass them entirely) — these
/// throw if called, so a regression that accidentally routes through the
/// offline path fails loudly instead of silently reading real assets.
class _UnusedContentRepository implements ContentRepository {
  @override
  Future<GameMap> loadMap(String mapId) => throw UnimplementedError();
  @override
  Future<RulesConfig> loadRules() => throw UnimplementedError();
  @override
  Future<List<BibleChallenge>> loadBibleChallenges() => throw UnimplementedError();
}

class _UnusedSaveGameService implements SaveGameService {
  @override
  Future<void> save(GameState state) => throw UnimplementedError();
  @override
  Future<GameState?> load(String gameId) => throw UnimplementedError();
  @override
  Future<List<SaveSummary>> listSaves() => throw UnimplementedError();
  @override
  Future<void> delete(String gameId) => throw UnimplementedError();
}

/// End-to-end for task #44: boots the real production server package
/// (`reinos_server`) locally and drives it with two real `GameController`s
/// — the exact class `GameScreen` uses — through their public online API
/// (`createOnlineRoom`/`joinOnlineRoom`/`attack`/etc.), proving the whole
/// client networking layer actually works, not just the raw wire protocol.
void main() {
  late HttpServer httpServer;
  late String serverUrl;

  setUp(() async {
    final relay = RelayServer(
      rooms: RoomRegistry(),
      content: ServerContentRepository(dataDir: '${Directory.current.path}/server/data'),
    );
    final pipeline = const Pipeline().addHandler(relay.handler);
    httpServer = await shelf_io.serve(pipeline, InternetAddress.loopbackIPv4, 0);
    serverUrl = 'ws://127.0.0.1:${httpServer.port}';
  });

  tearDown(() async {
    await httpServer.close(force: true);
  });

  GameController newController() =>
      GameController(_UnusedContentRepository(), _UnusedSaveGameService());

  test('host and guest GameControllers converge on the same state after a move', () async {
    final host = newController();
    final guest = newController();
    addTearDown(host.dispose);
    addTearDown(guest.dispose);

    final guestJoined = Completer<void>();
    host.onPlayerConnected = (playerId) {
      if (playerId == 'p1' && !guestJoined.isCompleted) guestJoined.complete();
    };

    await host.createOnlineRoom(
      serverUrl: serverUrl,
      mapId: 'biblical_lands_v1',
      hostPlayerId: 'p0',
      seed: 7,
      players: const [
        PlayerConfig(id: 'p0', displayName: 'Host', color: PlayerColor.blue),
        PlayerConfig(id: 'p1', displayName: 'Guest', color: PlayerColor.red),
      ],
    );
    expect(host.roomCode, isNotNull);
    expect(host.isOnline, isTrue);

    await guest.joinOnlineRoom(
      serverUrl: serverUrl,
      roomCode: host.roomCode!,
      playerId: 'p1',
    );
    await guestJoined.future;

    final actingController = host.state!.currentPlayer.id == 'p0' ? host : guest;
    expect(actingController.isMyTurn, isTrue);

    final territoryId =
        actingController.state!.territories.values
            .firstWhere((t) => t.ownerId == actingController.state!.currentPlayer.id)
            .id;
    actingController.placeArmy(territoryId);

    // Let the async `stateUpdate` round-trip land on both controllers.
    await Future.delayed(const Duration(milliseconds: 200));

    expect(actingController.lastError, isNull);
    expect(host.state!.toJson(), guest.state!.toJson());
    expect(
      host.state!.territories[territoryId]!.armyCount,
      guest.state!.territories[territoryId]!.armyCount,
    );
  });

  test('a player cannot act when it is not their turn', () async {
    final host = newController();
    final guest = newController();
    addTearDown(host.dispose);
    addTearDown(guest.dispose);

    final guestJoined = Completer<void>();
    host.onPlayerConnected = (playerId) {
      if (playerId == 'p1' && !guestJoined.isCompleted) guestJoined.complete();
    };

    await host.createOnlineRoom(
      serverUrl: serverUrl,
      mapId: 'biblical_lands_v1',
      hostPlayerId: 'p0',
      seed: 7,
      players: const [
        PlayerConfig(id: 'p0', displayName: 'Host', color: PlayerColor.blue),
        PlayerConfig(id: 'p1', displayName: 'Guest', color: PlayerColor.red),
      ],
    );
    await guest.joinOnlineRoom(serverUrl: serverUrl, roomCode: host.roomCode!, playerId: 'p1');
    await guestJoined.future;

    final waitingController = host.state!.currentPlayer.id == 'p0' ? guest : host;
    expect(waitingController.isMyTurn, isFalse);

    final before = waitingController.state!.toJson();
    waitingController.endPhase();
    await Future.delayed(const Duration(milliseconds: 100));

    expect(waitingController.lastError, isNotNull);
    expect(waitingController.state!.toJson(), before);
  });
}
