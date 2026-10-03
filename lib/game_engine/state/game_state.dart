import '../domain/player.dart';
import '../domain/region.dart';
import '../domain/rules_config.dart';
import '../domain/territory.dart';
import '../domain/territory_card.dart';
import '../rng/seeded_random.dart';
import 'battle_state.dart';
import 'game_action.dart';
import 'game_phase.dart';

/// The single source of truth for a match. Widgets only ever *read* this
/// (via Riverpod) and dispatch [GameAction]s to `GameEngine` — never mutate
/// it directly (section 44).
class GameState {
  final String gameId;
  final String mapId;

  /// Static region definitions for the loaded map (control-bonus lookups).
  final Map<String, Region> regions;

  /// Live territory state: ownership + army count, keyed by territory id.
  final Map<String, Territory> territories;

  final List<Player> players;
  final int currentPlayerIndex;
  final GamePhase phase;
  final int turnNumber;

  final List<TerritoryCard> deck;
  final List<TerritoryCard> discardPile;

  final BattleState? activeBattle;
  final int pendingReinforcements;

  /// Whether the current player has conquered at least one territory this
  /// turn (drives the card-reward phase, section 13 fase 4).
  final bool conqueredTerritoryThisTurn;

  final List<GameAction> actionHistory;
  final SeededRandom rng;
  final RulesConfig rules;
  final String? winnerId;

  const GameState({
    required this.gameId,
    required this.mapId,
    required this.regions,
    required this.territories,
    required this.players,
    required this.currentPlayerIndex,
    required this.phase,
    required this.turnNumber,
    required this.deck,
    required this.discardPile,
    required this.rng,
    required this.rules,
    this.activeBattle,
    this.pendingReinforcements = 0,
    this.conqueredTerritoryThisTurn = false,
    this.actionHistory = const [],
    this.winnerId,
  });

  Player get currentPlayer => players[currentPlayerIndex];

  List<Territory> territoriesOwnedBy(String playerId) =>
      territories.values.where((t) => t.ownerId == playerId).toList();

  bool playerControlsRegion(String playerId, String regionId) {
    final region = regions[regionId];
    if (region == null) return false;
    return region.territoryIds.every((id) => territories[id]?.ownerId == playerId);
  }

  GameState copyWith({
    Map<String, Territory>? territories,
    List<Player>? players,
    int? currentPlayerIndex,
    GamePhase? phase,
    int? turnNumber,
    List<TerritoryCard>? deck,
    List<TerritoryCard>? discardPile,
    BattleState? activeBattle,
    bool clearActiveBattle = false,
    int? pendingReinforcements,
    bool? conqueredTerritoryThisTurn,
    List<GameAction>? actionHistory,
    String? winnerId,
  }) {
    return GameState(
      gameId: gameId,
      mapId: mapId,
      regions: regions,
      territories: territories ?? this.territories,
      players: players ?? this.players,
      currentPlayerIndex: currentPlayerIndex ?? this.currentPlayerIndex,
      phase: phase ?? this.phase,
      turnNumber: turnNumber ?? this.turnNumber,
      deck: deck ?? this.deck,
      discardPile: discardPile ?? this.discardPile,
      rng: rng,
      rules: rules,
      activeBattle: clearActiveBattle ? null : (activeBattle ?? this.activeBattle),
      pendingReinforcements: pendingReinforcements ?? this.pendingReinforcements,
      conqueredTerritoryThisTurn:
          conqueredTerritoryThisTurn ?? this.conqueredTerritoryThisTurn,
      actionHistory: actionHistory ?? this.actionHistory,
      winnerId: winnerId ?? this.winnerId,
    );
  }
}
