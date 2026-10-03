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
