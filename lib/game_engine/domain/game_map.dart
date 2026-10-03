import 'region.dart';
import 'territory.dart';

/// Static map definition loaded from `data/maps/*.json`. Never hardcoded in
/// the UI — see ARCHITECTURE.md section 7/8.
class GameMap {
  final String id;
  final String name;
  final String periodId;
  final Map<String, Region> regions;

  /// Base (unowned, starting-army) territory definitions. Live ownership and
  /// army counts during a match are tracked in [GameState.territories], not
  /// here — this is the immutable map template.
  final Map<String, Territory> territories;

  const GameMap({
    required this.id,
    required this.name,
    required this.periodId,
    required this.regions,
    required this.territories,
  });

  List<String> neighborsOf(String territoryId) =>
      territories[territoryId]?.neighborIds ?? const [];

  factory GameMap.fromJson(Map<String, dynamic> json) {
    final regions = <String, Region>{};
    for (final r in (json['regions'] as List)) {
      final region = Region.fromJson(r as Map<String, dynamic>);
      regions[region.id] = region;
    }
    final territories = <String, Territory>{};
    for (final t in (json['territories'] as List)) {
      final territory = Territory.fromJson(t as Map<String, dynamic>);
      territories[territory.id] = territory;
    }
    return GameMap(
      id: json['id'] as String,
      name: json['name'] as String,
      periodId: json['periodId'] as String? ?? '',
      regions: regions,
      territories: territories,
    );
  }
}
