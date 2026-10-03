import 'bot_difficulty.dart';
import 'objective.dart';
import 'player_color.dart';
import 'territory_card.dart';

class Player {
  final String id;
  final String displayName;
  final PlayerColor color;
  final bool isBot;
  final BotDifficulty? botDifficulty;
  final Objective objective;
  final List<TerritoryCard> cards;
  final int wisdomPoints;
  final int xp;
  final bool isEliminated;

  const Player({
    required this.id,
    required this.displayName,
    required this.color,
    required this.objective,
    this.isBot = false,
    this.botDifficulty,
    this.cards = const [],
    this.wisdomPoints = 0,
    this.xp = 0,
    this.isEliminated = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'color': color.name,
        'isBot': isBot,
        'botDifficulty': botDifficulty?.name,
        'objective': objective.toJson(),
        'cards': cards.map((c) => c.toJson()).toList(),
        'wisdomPoints': wisdomPoints,
        'xp': xp,
        'isEliminated': isEliminated,
      };

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      color: PlayerColor.values.byName(json['color'] as String),
      isBot: json['isBot'] as bool,
      botDifficulty: json['botDifficulty'] != null
          ? BotDifficulty.values.byName(json['botDifficulty'] as String)
          : null,
      objective: Objective.fromJson(json['objective'] as Map<String, dynamic>),
      cards: (json['cards'] as List)
          .map((c) => TerritoryCard.fromJson(c as Map<String, dynamic>))
          .toList(),
      wisdomPoints: json['wisdomPoints'] as int,
      xp: json['xp'] as int,
      isEliminated: json['isEliminated'] as bool,
    );
  }

  Player copyWith({
    List<TerritoryCard>? cards,
    int? wisdomPoints,
    int? xp,
    bool? isEliminated,
  }) {
    return Player(
      id: id,
      displayName: displayName,
      color: color,
      isBot: isBot,
      botDifficulty: botDifficulty,
      objective: objective,
      cards: cards ?? this.cards,
      wisdomPoints: wisdomPoints ?? this.wisdomPoints,
      xp: xp ?? this.xp,
      isEliminated: isEliminated ?? this.isEliminated,
    );
  }
}
