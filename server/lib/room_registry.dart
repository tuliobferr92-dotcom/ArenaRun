import 'dart:math';

import 'package:reinos_engine/game_engine/domain/bot_difficulty.dart';
import 'package:reinos_engine/game_engine/domain/game_map.dart';
import 'package:reinos_engine/game_engine/domain/player_color.dart';
import 'package:reinos_engine/game_engine/domain/rules_config.dart';
import 'package:reinos_engine/game_engine/engine/game_engine.dart';

import 'room.dart';

/// Decodes the `players` array of a `createRoom` message into
/// [PlayerConfig]s. Thrown as [FormatException] on anything malformed so
/// the caller can turn it into a clean `error` reply instead of crashing
/// the connection.
List<PlayerConfig> decodePlayerConfigs(List<dynamic> raw) {
  return raw.map((entry) {
    final map = entry as Map<String, dynamic>;
    final isBot = map['isBot'] as bool? ?? false;
    final difficultyName = map['botDifficulty'] as String?;
    return PlayerConfig(
      id: map['id'] as String,
      displayName: map['displayName'] as String,
      color: PlayerColor.values.byName(map['color'] as String),
      isBot: isBot,
      botDifficulty:
          difficultyName == null ? null : BotDifficulty.values.byName(difficultyName),
    );
  }).toList();
}

/// Holds every in-progress [Room], keyed by its human-readable room code
/// (e.g. "REINO-7281"). One process-wide instance per server (section 36).
class RoomRegistry {
  final Map<String, Room> _rooms = {};
  final Random _random = Random.secure();

  Room? find(String code) => _rooms[code];

  Room createRoom({
    required GameMap map,
    required RulesConfig rules,
    required List<PlayerConfig> players,
    required int seed,
  }) {
    final state = GameEngine.newMatch(map: map, configs: players, rules: rules, seed: seed);
    final code = _generateUniqueCode();
    final room = Room(code: code, state: state);
    _rooms[code] = room;
    return room;
  }

  /// Drops a room once every connection has left it, so a finished or
  /// abandoned match doesn't leak memory for the life of the process.
  void removeIfEmpty(String code) {
    final room = _rooms[code];
    if (room != null && room.isEmpty) {
      _rooms.remove(code);
    }
  }

  String _generateUniqueCode() {
    String code;
    do {
      final digits = _random.nextInt(10000).toString().padLeft(4, '0');
      code = 'REINO-$digits';
    } while (_rooms.containsKey(code));
    return code;
  }
}
