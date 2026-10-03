import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:reinos_engine/game_engine/domain/game_map.dart';
import 'package:reinos_engine/game_engine/domain/rules_config.dart';

/// File-based mirror of the app's `AssetContentRepository` (section 49) —
/// the server has no Flutter `rootBundle`, so it reads the same map/rules
/// JSON from `server/data/` instead. Keep these files in sync with
/// `data/maps/` and `data/rules/` at the repo root whenever the map or
/// default rules change.
class ServerContentRepository {
  final String dataDir;

  ServerContentRepository({String? dataDir})
      : dataDir = dataDir ?? p.join(Directory.current.path, 'data');

  Future<GameMap> loadMap(String mapId) async {
    final file = File(p.join(dataDir, 'maps', '$mapId.json'));
    final raw = await file.readAsString();
    return GameMap.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<RulesConfig> loadRules() async {
    final file = File(p.join(dataDir, 'rules', 'default_rules.json'));
    final raw = await file.readAsString();
    return RulesConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }
}
