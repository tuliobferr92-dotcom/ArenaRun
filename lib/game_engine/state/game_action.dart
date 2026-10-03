/// Base class for every mutation of [GameState]. Every action is
/// serializable and timestamped so the full match can be replayed from the
/// action log — a prerequisite for save/load, reconnect and a future
/// server-authoritative multiplayer mode (section 36/37).
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
}

class EndPhaseAction extends GameAction {
  const EndPhaseAction({
    required super.gameId,
    required super.playerId,
    required super.timestamp,
    required super.sequenceNumber,
  });
}
