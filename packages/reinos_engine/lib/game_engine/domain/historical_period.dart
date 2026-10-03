/// Groups territories/maps into a historically coherent period so different
/// maps (Exodus, New Testament, Paul's journeys, ...) never imply that
/// politically distinct eras coexisted.
class HistoricalPeriod {
  final String id;
  final String name;
  final String description;

  const HistoricalPeriod({
    required this.id,
    required this.name,
    required this.description,
  });

  factory HistoricalPeriod.fromJson(Map<String, dynamic> json) {
    return HistoricalPeriod(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
    );
  }
}
