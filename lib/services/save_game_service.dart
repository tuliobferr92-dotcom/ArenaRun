import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../game_engine/state/game_state.dart';

/// Metadata shown in a "Continuar Partida" / save-slot list without
/// deserializing the full match.
class SaveSummary {
  final String gameId;
  final String mapId;
  final int turnNumber;
  final DateTime savedAt;

  const SaveSummary({
    required this.gameId,
    required this.mapId,
    required this.turnNumber,
    required this.savedAt,
  });
}

/// Abstraction over where paused matches live (section 39). The default
/// implementation writes one JSON file per save slot to app-local storage;
/// nothing in `GameEngine`/UI depends on *how* persistence happens, so a
/// future cloud-save or multiplayer-snapshot backend can replace this
/// without touching game logic.
abstract class SaveGameService {
  Future<void> save(GameState state);
  Future<GameState?> load(String gameId);
  Future<List<SaveSummary>> listSaves();
  Future<void> delete(String gameId);
}

class FileSaveGameService implements SaveGameService {
  Future<Directory> _saveDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/reinos_saves');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  @override
  Future<void> save(GameState state) async {
    final dir = await _saveDir();
    final file = File('${dir.path}/${state.gameId}.json');
    final payload = {
      'savedAt': DateTime.now().toIso8601String(),
      'state': state.toJson(),
    };
    await file.writeAsString(jsonEncode(payload));
  }

  @override
  Future<GameState?> load(String gameId) async {
    final dir = await _saveDir();
    final file = File('${dir.path}/$gameId.json');
    if (!await file.exists()) return null;
    final payload = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return GameState.fromJson(payload['state'] as Map<String, dynamic>);
  }

  @override
  Future<List<SaveSummary>> listSaves() async {
    final dir = await _saveDir();
    if (!await dir.exists()) return [];
    final summaries = <SaveSummary>[];
    for (final entity in dir.listSync()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      try {
        final payload = jsonDecode(await entity.readAsString()) as Map<String, dynamic>;
        final state = payload['state'] as Map<String, dynamic>;
        summaries.add(SaveSummary(
          gameId: state['gameId'] as String,
          mapId: state['mapId'] as String,
          turnNumber: state['turnNumber'] as int,
          savedAt: DateTime.parse(payload['savedAt'] as String),
        ));
      } catch (_) {
        // Corrupted/partial save file — skip it rather than crash the list.
        continue;
      }
    }
    summaries.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return summaries;
  }

  @override
  Future<void> delete(String gameId) async {
    final dir = await _saveDir();
    final file = File('${dir.path}/$gameId.json');
    if (await file.exists()) await file.delete();
  }
}
