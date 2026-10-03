// Validates the seed content file itself (data/content/bible_challenges.json)
// without going through Flutter's asset bundle — this is a pure Dart/JSON
// sanity check: every challenge decodes, every correctOptionIndex is in
// range, and every referenced territoryId exists on the production map
// (data/maps/biblical_lands_v1.json). Catches a broken seed file before it
// ever reaches a device.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:reinos_engine/content/domain/bible_challenge.dart';
import 'package:reinos_engine/content/domain/content_review_status.dart';
import 'package:reinos_engine/game_engine/domain/game_map.dart';

List<BibleChallenge> _loadChallenges() {
  final raw = File('data/content/bible_challenges.json').readAsStringSync();
  return (jsonDecode(raw) as List)
      .map((c) => BibleChallenge.fromJson(c as Map<String, dynamic>))
      .toList();
}

GameMap _loadMap() {
  final raw = File('data/maps/biblical_lands_v1.json').readAsStringSync();
  return GameMap.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

void main() {
  test('every seed challenge is well-formed and published', () {
    final challenges = _loadChallenges();
    expect(challenges, isNotEmpty);

    for (final challenge in challenges) {
      expect(challenge.options.length, greaterThanOrEqualTo(2));
      expect(challenge.correctOptionIndex, inInclusiveRange(0, challenge.options.length - 1));
      expect(challenge.biblicalReferences, isNotEmpty);
      expect(challenge.reviewStatus, ContentReviewStatus.published);
    }
  });

  test('every challenge references a territory that exists on the production map', () {
    final challenges = _loadChallenges();
    final map = _loadMap();

    for (final challenge in challenges) {
      expect(
        map.territories.containsKey(challenge.territoryId),
        isTrue,
        reason: '${challenge.id} references unknown territory ${challenge.territoryId}',
      );
    }
  });

  test('no challenge ids are duplicated', () {
    final challenges = _loadChallenges();
    final ids = challenges.map((c) => c.id).toList();
    expect(ids.toSet().length, ids.length);
  });
}
