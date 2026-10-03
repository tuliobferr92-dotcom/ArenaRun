import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../content/content_repository.dart';
import '../game_engine/domain/game_map.dart';
import '../game_engine/engine/bot_strategy.dart';
import '../game_engine/engine/game_engine.dart';
import '../game_engine/engine/game_exceptions.dart';
import '../game_engine/state/game_action.dart';
import '../game_engine/state/game_phase.dart';
import '../game_engine/state/game_state.dart';

final contentRepositoryProvider = Provider<ContentRepository>((ref) {
  return AssetContentRepository();
});

final gameControllerProvider =
    StateNotifierProvider<GameController, GameState?>((ref) {
  return GameController(ref.read(contentRepositoryProvider));
});

/// Bridges `GameEngine` (pure Dart) to the widget tree. Holds no rules of
/// its own — every state change goes through `GameEngine.apply` — but owns
/// the bot "AI turn loop" so human players never have to drive bot actions.
class GameController extends StateNotifier<GameState?> {
  final ContentRepository _content;
  int _sequence = 0;
  String? _lastError;

  GameController(this._content) : super(null);

  String? get lastError => _lastError;

  Future<void> startMatch({
    required String mapId,
    required List<PlayerConfig> players,
    int seed = 1,
  }) async {
    final GameMap map = await _content.loadMap(mapId);
    final rules = await _content.loadRules();
    state = GameEngine.newMatch(map: map, configs: players, rules: rules, seed: seed);
    await _runBotLoopIfNeeded();
  }

  void _dispatch(GameAction Function(String gameId, int seq) build) {
    final current = state;
    if (current == null) return;
    final action = build(current.gameId, _sequence++);
    try {
      state = GameEngine.apply(current, action);
      _lastError = null;
    } on InvalidActionException catch (e) {
      _lastError = e.reason;
    }
  }

  void placeArmy(String territoryId, {int count = 1}) {
    _dispatch((gameId, seq) => PlaceArmyAction(
          gameId: gameId,
          playerId: state!.currentPlayer.id,
          timestamp: DateTime.now(),
          sequenceNumber: seq,
          territoryId: territoryId,
          count: count,
        ));
    _runBotLoopIfNeeded();
  }

  void reinforce(Map<String, int> armiesByTerritory) {
    _dispatch((gameId, seq) => ReinforceAction(
          gameId: gameId,
          playerId: state!.currentPlayer.id,
          timestamp: DateTime.now(),
          sequenceNumber: seq,
          armiesByTerritory: armiesByTerritory,
        ));
    _runBotLoopIfNeeded();
  }

  void attack(String fromId, String toId, int troopCount) {
    _dispatch((gameId, seq) => AttackAction(
          gameId: gameId,
          playerId: state!.currentPlayer.id,
          timestamp: DateTime.now(),
          sequenceNumber: seq,
          fromTerritoryId: fromId,
          toTerritoryId: toId,
          troopCount: troopCount,
        ));
    _runBotLoopIfNeeded();
  }

  void moveArmy(String fromId, String toId, int count) {
    _dispatch((gameId, seq) => MoveArmyAction(
          gameId: gameId,
          playerId: state!.currentPlayer.id,
          timestamp: DateTime.now(),
          sequenceNumber: seq,
          fromTerritoryId: fromId,
          toTerritoryId: toId,
          count: count,
        ));
    _runBotLoopIfNeeded();
  }

  void endPhase() {
    _dispatch((gameId, seq) => EndPhaseAction(
          gameId: gameId,
          playerId: state!.currentPlayer.id,
          timestamp: DateTime.now(),
          sequenceNumber: seq,
        ));
    _runBotLoopIfNeeded();
  }

  /// Drives every bot turn automatically. Never touches the RNG directly —
  /// it only decides which `GameAction` to dispatch; `BattleEngine` alone
  /// resolves dice (section 38).
  Future<void> _runBotLoopIfNeeded() async {
    var guard = 0;
    while (state != null &&
        state!.phase != GamePhase.gameOver &&
        state!.currentPlayer.isBot &&
        guard < 200) {
      guard++;
      final before = state!;
      _stepBot(before);
      if (state == before) break; // safety: avoid infinite loop on no-op
    }
  }

  /// Same actions as the public API, but dispatched without re-triggering
  /// the bot loop (the caller, `_runBotLoopIfNeeded`, already owns the
  /// loop) — avoids redundant nested iteration.
  void _stepBot(GameState s) {
    final playerId = s.currentPlayer.id;
    switch (s.phase) {
      case GamePhase.initialPlacement:
      case GamePhase.reinforcement:
        if (s.pendingReinforcements > 0) {
          final placement =
              BotStrategy.decideReinforcementPlacement(s, playerId, s.pendingReinforcements);
          if (placement.isEmpty) {
            _dispatchEndPhase();
          } else if (s.phase == GamePhase.initialPlacement) {
            final entry = placement.entries.first;
            _dispatchPlaceArmy(entry.key, entry.value);
          } else {
            _dispatchReinforce(placement);
          }
        } else {
          _dispatchEndPhase();
        }
        return;

      case GamePhase.attack:
        final decision = BotStrategy.decideNextAttack(s, playerId);
        if (decision == null) {
          _dispatchEndPhase();
        } else {
          _dispatchAttack(decision.fromTerritoryId, decision.toTerritoryId, decision.troopCount);
        }
        return;

      case GamePhase.fortification:
        _dispatchEndPhase();
        return;

      default:
        return;
    }
  }

  void _dispatchPlaceArmy(String territoryId, int count) {
    _dispatch((gameId, seq) => PlaceArmyAction(
          gameId: gameId,
          playerId: state!.currentPlayer.id,
          timestamp: DateTime.now(),
          sequenceNumber: seq,
          territoryId: territoryId,
          count: count,
        ));
  }

  void _dispatchReinforce(Map<String, int> armiesByTerritory) {
    _dispatch((gameId, seq) => ReinforceAction(
          gameId: gameId,
          playerId: state!.currentPlayer.id,
          timestamp: DateTime.now(),
          sequenceNumber: seq,
          armiesByTerritory: armiesByTerritory,
        ));
  }

  void _dispatchAttack(String fromId, String toId, int troopCount) {
    _dispatch((gameId, seq) => AttackAction(
          gameId: gameId,
          playerId: state!.currentPlayer.id,
          timestamp: DateTime.now(),
          sequenceNumber: seq,
          fromTerritoryId: fromId,
          toTerritoryId: toId,
          troopCount: troopCount,
        ));
  }

  void _dispatchEndPhase() {
    _dispatch((gameId, seq) => EndPhaseAction(
          gameId: gameId,
          playerId: state!.currentPlayer.id,
          timestamp: DateTime.now(),
          sequenceNumber: seq,
        ));
  }
}
