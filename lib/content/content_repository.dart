import 'dart:convert';

import 'package:flutter/services.dart';

import '../game_engine/domain/game_map.dart';
import '../game_engine/domain/rules_config.dart';
import 'domain/bible_challenge.dart';
import 'domain/content_review_status.dart';

/// Single point of access for everything that lives in `data/` (section 49).
/// Nothing in `game_engine` reads assets directly — only this repository
/// does, so a future backend/CMS can replace the asset-based implementation
/// without touching engine or UI code.
abstract class ContentRepository {
  Future<GameMap> loadMap(String mapId);
  Future<RulesConfig> loadRules();

  /// Only ever returns [ContentReviewStatus.published] items (see
  /// BIBLE_CONTENT_GUIDELINES.md section 23) — callers never see a draft.
  Future<List<BibleChallenge>> loadBibleChallenges();
}

class AssetContentRepository implements ContentRepository {
  List<BibleChallenge>? _challengesCache;

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

  @override
  Future<List<BibleChallenge>> loadBibleChallenges() async {
    final cached = _challengesCache;
    if (cached != null) return cached;

    final raw = await rootBundle.loadString('data/content/bible_challenges.json');
    final challenges = (jsonDecode(raw) as List)
        .map((c) => BibleChallenge.fromJson(c as Map<String, dynamic>))
        .where((c) => c.reviewStatus == ContentReviewStatus.published)
        .toList();
    _challengesCache = challenges;
    return challenges;
  }
}
