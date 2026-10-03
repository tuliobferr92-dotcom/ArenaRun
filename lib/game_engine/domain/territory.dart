/// A single territory on a [GameMap]. Immutable; mutations (ownership, army
/// count) happen by producing a new [Territory] via [copyWith], never in
/// place — the engine always works with fresh [GameState] snapshots.
class Territory {
  final String id;
  final String name;
  final String regionId;
  final List<String> neighborIds;

  /// Polygon vertices in normalized map space (0..1000 on each axis), so the
  /// UI can scale to any screen size without re-authoring map data.
  final List<Offset2D> polygon;
  final Offset2D centroid;

  final List<String> biblicalReferences;
  final String historicalPeriodId;
  final String description;

  /// Null while unclaimed (should not normally happen after setup).
  final String? ownerId;
  final int armyCount;

  const Territory({
    required this.id,
    required this.name,
    required this.regionId,
    required this.neighborIds,
    required this.polygon,
    required this.centroid,
    required this.biblicalReferences,
    required this.historicalPeriodId,
    required this.description,
    this.ownerId,
    this.armyCount = 0,
  });

  Territory copyWith({String? ownerId, bool clearOwner = false, int? armyCount}) {
    return Territory(
      id: id,
      name: name,
      regionId: regionId,
      neighborIds: neighborIds,
      polygon: polygon,
      centroid: centroid,
      biblicalReferences: biblicalReferences,
      historicalPeriodId: historicalPeriodId,
      description: description,
      ownerId: clearOwner ? null : (ownerId ?? this.ownerId),
      armyCount: armyCount ?? this.armyCount,
    );
  }

  bool isAdjacentTo(String territoryId) => neighborIds.contains(territoryId);

  factory Territory.fromJson(Map<String, dynamic> json) {
    return Territory(
      id: json['id'] as String,
      name: json['name'] as String,
      regionId: json['regionId'] as String,
      neighborIds: (json['neighbors'] as List).cast<String>(),
      polygon: (json['polygon'] as List)
          .map((p) => Offset2D((p[0] as num).toDouble(), (p[1] as num).toDouble()))
          .toList(),
      centroid: Offset2D(
        (json['centroid'][0] as num).toDouble(),
        (json['centroid'][1] as num).toDouble(),
      ),
      biblicalReferences: (json['biblicalReferences'] as List? ?? []).cast<String>(),
      historicalPeriodId: json['historicalPeriodId'] as String? ?? '',
      description: json['description'] as String? ?? '',
      ownerId: json['ownerId'] as String?,
      armyCount: json['armyCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'regionId': regionId,
        'neighbors': neighborIds,
        'polygon': polygon.map((p) => [p.dx, p.dy]).toList(),
        'centroid': [centroid.dx, centroid.dy],
        'biblicalReferences': biblicalReferences,
        'historicalPeriodId': historicalPeriodId,
        'description': description,
        'ownerId': ownerId,
        'armyCount': armyCount,
      };
}

/// Lightweight 2D point so `game_engine` never depends on `package:flutter`.
class Offset2D {
  final double dx;
  final double dy;
  const Offset2D(this.dx, this.dy);
}
