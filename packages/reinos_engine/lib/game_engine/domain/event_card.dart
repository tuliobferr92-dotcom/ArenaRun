/// Special event cards (section 20) — mechanically inspired by these
/// biblical themes, never a literal claim that the in-game effect *is*
/// the theological meaning of the text (BIBLE_CONTENT_GUIDELINES.md rule 3).
enum EventCardType {
  /// Theme: Neemias rebuilding Jerusalem's walls. Effect: temporary
  /// fortification — instantly reinforces one owned territory.
  reconstrucao,

  /// Theme: Salomão's wisdom. Effect: a burst of strategic insight —
  /// extra reinforcements right away.
  sabedoria,

  /// Theme: José's years of abundance in Egypt. Effect: extra resources —
  /// draws one territorial card immediately, without needing a conquest.
  tempoDeFartura,
}

class EventCard {
  final String id;
  final EventCardType type;

  const EventCard({required this.id, required this.type});

  Map<String, dynamic> toJson() => {'id': id, 'type': type.name};

  factory EventCard.fromJson(Map<String, dynamic> json) {
    return EventCard(
      id: json['id'] as String,
      type: EventCardType.values.byName(json['type'] as String),
    );
  }
}
