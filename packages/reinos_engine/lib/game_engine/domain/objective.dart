/// Secret objective types. Phase 1 implements [controlTerritoryCount] and
/// [controlRegions]; the rest are modeled now so the engine never needs a
/// breaking change to support them later (section 18).
enum ObjectiveType {
  controlTerritoryCount,
  controlRegions,
  controlSpecificTerritories,
  eliminatePlayer,
  hybrid,
}

class Objective {
  final String id;
  final ObjectiveType type;
  final String description;

  /// Interpretation depends on [type]:
  /// - controlTerritoryCount: `{'count': int}`
  /// - controlRegions: `{'regionIds': List<String>}`
  /// - controlSpecificTerritories: `{'territoryIds': List<String>}`
  /// - eliminatePlayer: `{'targetPlayerId': String?}` (null = "a chosen rival")
  final Map<String, dynamic> params;

  const Objective({
    required this.id,
    required this.type,
    required this.description,
    required this.params,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'description': description,
        'params': params,
      };

  factory Objective.fromJson(Map<String, dynamic> json) {
    return Objective(
      id: json['id'] as String,
      type: ObjectiveType.values.byName(json['type'] as String),
      description: json['description'] as String,
      params: Map<String, dynamic>.from(json['params'] as Map),
    );
  }
}
