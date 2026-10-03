/// A group of territories that grants a reinforcement bonus when a single
/// player controls every territory in it.
class Region {
  final String id;
  final String name;
  final List<String> territoryIds;
  final int controlBonus;

  const Region({
    required this.id,
    required this.name,
    required this.territoryIds,
    required this.controlBonus,
  });

  factory Region.fromJson(Map<String, dynamic> json) {
    return Region(
      id: json['id'] as String,
      name: json['name'] as String,
      territoryIds: (json['territoryIds'] as List).cast<String>(),
      controlBonus: json['controlBonus'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'territoryIds': territoryIds,
        'controlBonus': controlBonus,
      };
}
