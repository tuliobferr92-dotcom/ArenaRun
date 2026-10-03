/// Base class for every mutation of [GameState]. Every action is
/// serializable and timestamped so the full match can be replayed from the
/// action log — a prerequisite for save/load, reconnect and the
/// server-authoritative multiplayer mode (section 36/37): the server and
/// every client decode the exact same JSON shape via [gameActionFromJson].
abstract class GameAction {
  final String gameId;
  final String playerId;
  final DateTime timestamp;
  final int sequenceNumber;

  const GameAction({
    required this.gameId,
    required this.playerId,
    required this.timestamp,
    required this.sequenceNumber,
  });

  /// Discriminator used by [gameActionFromJson] to pick the right subclass.
  String get type;

  Map<String, dynamic> toJson();

  Map<String, dynamic> _baseJson() => {
        'type': type,
        'gameId': gameId,
        'playerId': playerId,
        'timestamp': timestamp.toIso8601String(),
        'sequenceNumber': sequenceNumber,
      };
}

class PlaceArmyAction extends GameAction {
  final String territoryId;
  final int count;

  const PlaceArmyAction({
    required super.gameId,
    required super.playerId,
    required super.timestamp,
    required super.sequenceNumber,
    required this.territoryId,
    this.count = 1,
  });

  @override
  String get type => 'placeArmy';

  @override
  Map<String, dynamic> toJson() => {
        ..._baseJson(),
        'territoryId': territoryId,
        'count': count,
      };

  factory PlaceArmyAction.fromJson(Map<String, dynamic> json) => PlaceArmyAction(
        gameId: json['gameId'] as String,
        playerId: json['playerId'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        sequenceNumber: json['sequenceNumber'] as int,
        territoryId: json['territoryId'] as String,
        count: json['count'] as int,
      );
}

class ReinforceAction extends GameAction {
  final Map<String, int> armiesByTerritory;

  const ReinforceAction({
    required super.gameId,
    required super.playerId,
    required super.timestamp,
    required super.sequenceNumber,
    required this.armiesByTerritory,
  });

  @override
  String get type => 'reinforce';

  @override
  Map<String, dynamic> toJson() => {
        ..._baseJson(),
        'armiesByTerritory': armiesByTerritory,
      };

  factory ReinforceAction.fromJson(Map<String, dynamic> json) => ReinforceAction(
        gameId: json['gameId'] as String,
        playerId: json['playerId'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        sequenceNumber: json['sequenceNumber'] as int,
        armiesByTerritory: (json['armiesByTerritory'] as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, v as int)),
      );
}

class AttackAction extends GameAction {
  final String fromTerritoryId;
  final String toTerritoryId;
  final int troopCount;

  const AttackAction({
    required super.gameId,
    required super.playerId,
    required super.timestamp,
    required super.sequenceNumber,
    required this.fromTerritoryId,
    required this.toTerritoryId,
    required this.troopCount,
  });

  @override
  String get type => 'attack';

  @override
  Map<String, dynamic> toJson() => {
        ..._baseJson(),
        'fromTerritoryId': fromTerritoryId,
        'toTerritoryId': toTerritoryId,
        'troopCount': troopCount,
      };

  factory AttackAction.fromJson(Map<String, dynamic> json) => AttackAction(
        gameId: json['gameId'] as String,
        playerId: json['playerId'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        sequenceNumber: json['sequenceNumber'] as int,
        fromTerritoryId: json['fromTerritoryId'] as String,
        toTerritoryId: json['toTerritoryId'] as String,
        troopCount: json['troopCount'] as int,
      );
}

/// Troop movement into a just-conquered territory, or a fortification move
/// between two owned, connected territories.
class MoveArmyAction extends GameAction {
  final String fromTerritoryId;
  final String toTerritoryId;
  final int count;

  const MoveArmyAction({
    required super.gameId,
    required super.playerId,
    required super.timestamp,
    required super.sequenceNumber,
    required this.fromTerritoryId,
    required this.toTerritoryId,
    required this.count,
  });

  @override
  String get type => 'moveArmy';

  @override
  Map<String, dynamic> toJson() => {
        ..._baseJson(),
        'fromTerritoryId': fromTerritoryId,
        'toTerritoryId': toTerritoryId,
        'count': count,
      };

  factory MoveArmyAction.fromJson(Map<String, dynamic> json) => MoveArmyAction(
        gameId: json['gameId'] as String,
        playerId: json['playerId'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        sequenceNumber: json['sequenceNumber'] as int,
        fromTerritoryId: json['fromTerritoryId'] as String,
        toTerritoryId: json['toTerritoryId'] as String,
        count: json['count'] as int,
      );
}

class PlayCardAction extends GameAction {
  final List<String> cardIds;

  const PlayCardAction({
    required super.gameId,
    required super.playerId,
    required super.timestamp,
    required super.sequenceNumber,
    required this.cardIds,
  });

  @override
  String get type => 'playCard';

  @override
  Map<String, dynamic> toJson() => {
        ..._baseJson(),
        'cardIds': cardIds,
      };

  factory PlayCardAction.fromJson(Map<String, dynamic> json) => PlayCardAction(
        gameId: json['gameId'] as String,
        playerId: json['playerId'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        sequenceNumber: json['sequenceNumber'] as int,
        cardIds: (json['cardIds'] as List).map((e) => e as String).toList(),
      );
}

/// Records that a player answered a Bible challenge (section 22/31). The
/// engine never judges the answer itself — whether [correct] is true is
/// decided by `BibleChallengeEngine.isCorrect` in the content layer before
/// this action is dispatched, keeping `game_engine` free of any
/// dependency on biblical content.
class AnswerChallengeAction extends GameAction {
  final String challengeId;
  final bool correct;

  const AnswerChallengeAction({
    required super.gameId,
    required super.playerId,
    required super.timestamp,
    required super.sequenceNumber,
    required this.challengeId,
    required this.correct,
  });

  @override
  String get type => 'answerChallenge';

  @override
  Map<String, dynamic> toJson() => {
        ..._baseJson(),
        'challengeId': challengeId,
        'correct': correct,
      };

  factory AnswerChallengeAction.fromJson(Map<String, dynamic> json) => AnswerChallengeAction(
        gameId: json['gameId'] as String,
        playerId: json['playerId'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        sequenceNumber: json['sequenceNumber'] as int,
        challengeId: json['challengeId'] as String,
        correct: json['correct'] as bool,
      );
}

/// Plays a special event card (section 20). [targetTerritoryId] is only
/// used by `reconstrucao` (which owned territory to reinforce) — the
/// other two types ignore it.
class PlayEventCardAction extends GameAction {
  final String eventCardId;
  final String? targetTerritoryId;

  const PlayEventCardAction({
    required super.gameId,
    required super.playerId,
    required super.timestamp,
    required super.sequenceNumber,
    required this.eventCardId,
    this.targetTerritoryId,
  });

  @override
  String get type => 'playEventCard';

  @override
  Map<String, dynamic> toJson() => {
        ..._baseJson(),
        'eventCardId': eventCardId,
        'targetTerritoryId': targetTerritoryId,
      };

  factory PlayEventCardAction.fromJson(Map<String, dynamic> json) => PlayEventCardAction(
        gameId: json['gameId'] as String,
        playerId: json['playerId'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        sequenceNumber: json['sequenceNumber'] as int,
        eventCardId: json['eventCardId'] as String,
        targetTerritoryId: json['targetTerritoryId'] as String?,
      );
}

class EndPhaseAction extends GameAction {
  const EndPhaseAction({
    required super.gameId,
    required super.playerId,
    required super.timestamp,
    required super.sequenceNumber,
  });

  @override
  String get type => 'endPhase';

  @override
  Map<String, dynamic> toJson() => _baseJson();

  factory EndPhaseAction.fromJson(Map<String, dynamic> json) => EndPhaseAction(
        gameId: json['gameId'] as String,
        playerId: json['playerId'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        sequenceNumber: json['sequenceNumber'] as int,
      );
}

/// Decodes any [GameAction] subclass from the JSON its own [GameAction.toJson]
/// produced, dispatching on the `type` discriminator. Used by save/load,
/// the action-log replay, and the multiplayer wire protocol — the one place
/// that needs to know every concrete subclass.
GameAction gameActionFromJson(Map<String, dynamic> json) {
  final type = json['type'] as String;
  switch (type) {
    case 'placeArmy':
      return PlaceArmyAction.fromJson(json);
    case 'reinforce':
      return ReinforceAction.fromJson(json);
    case 'attack':
      return AttackAction.fromJson(json);
    case 'moveArmy':
      return MoveArmyAction.fromJson(json);
    case 'playCard':
      return PlayCardAction.fromJson(json);
    case 'answerChallenge':
      return AnswerChallengeAction.fromJson(json);
    case 'playEventCard':
      return PlayEventCardAction.fromJson(json);
    case 'endPhase':
      return EndPhaseAction.fromJson(json);
    default:
      throw ArgumentError('Unknown GameAction type: $type');
  }
}
