import 'bot_difficulty.dart';
import 'event_card.dart';
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

  /// Bible challenges this player has already answered this match (right
  /// or wrong — never asked twice) and how many of those were correct
  /// (section 31/32 "Sua Jornada" / Biblical Knowledge).
  final Set<String> answeredChallengeIds;
  final int correctChallengeAnswers;

  /// Special event cards in hand (section 20) — earned by answering a
  /// Bible challenge correctly (GAME_RULES.md "Cartas de evento").
  final List<EventCard> eventCards;

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
    this.answeredChallengeIds = const {},
    this.correctChallengeAnswers = 0,
    this.eventCards = const [],
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
        'answeredChallengeIds': answeredChallengeIds.toList(),
        'correctChallengeAnswers': correctChallengeAnswers,
        'eventCards': eventCards.map((c) => c.toJson()).toList(),
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
      answeredChallengeIds:
          (json['answeredChallengeIds'] as List? ?? []).cast<String>().toSet(),
      correctChallengeAnswers: json['correctChallengeAnswers'] as int? ?? 0,
      eventCards: (json['eventCards'] as List? ?? [])
          .map((c) => EventCard.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }

  Player copyWith({
    List<TerritoryCard>? cards,
    int? wisdomPoints,
    int? xp,
    bool? isEliminated,
    Set<String>? answeredChallengeIds,
    int? correctChallengeAnswers,
    List<EventCard>? eventCards,
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
      answeredChallengeIds: answeredChallengeIds ?? this.answeredChallengeIds,
      correctChallengeAnswers: correctChallengeAnswers ?? this.correctChallengeAnswers,
      eventCards: eventCards ?? this.eventCards,
    );
  }
}
