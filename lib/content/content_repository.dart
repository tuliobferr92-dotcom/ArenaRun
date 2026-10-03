import 'dart:convert';

import 'package:flutter/services.dart';

import '../game_engine/domain/game_map.dart';
import '../game_engine/domain/rules_config.dart';

/// Single point of access for everything that lives in `data/` (section 49).
/// Nothing in `game_engine` reads assets directly — only this repository
/// does, so a future backend/CMS can replace the asset-based implementation
/// without touching engine or UI code.
abstract class ContentRepository {
  Future<GameMap> loadMap(String mapId);
  Future<RulesConfig> loadRules();
}

class AssetContentRepository implements ContentRepository {
  @override
  Future<GameMap> loadMap(String mapId) async {
    final raw = await rootBundle.loadString('data/maps/$mapId.json');
    return GameMap.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<RulesConfig> loadRules() async {
    final raw = await rootBundle.loadString('data/rules/default_rules.json');
    return RulesConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }
}
