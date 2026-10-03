import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../content/content_repository.dart';
import '../content/domain/bible_challenge.dart';
import '../game_engine/domain/game_map.dart';
import '../game_engine/engine/bot_strategy.dart';
import '../game_engine/engine/game_engine.dart';
import '../game_engine/engine/game_exceptions.dart';
import '../game_engine/state/game_action.dart';
import '../game_engine/state/game_phase.dart';
import '../game_engine/state/game_state.dart';
import '../services/audio_service.dart';
import '../services/save_game_service.dart';

final contentRepositoryProvider = Provider<ContentRepository>((ref) {
  return AssetContentRepository();
});

final saveGameServiceProvider = Provider<SaveGameService>((ref) {
  return FileSaveGameService();
});

final audioServiceProvider = Provider<AudioService>((ref) {
  return NoOpAudioService();
});

final bibleChallengesProvider = FutureProvider<List<BibleChallenge>>((ref) {
  return ref.read(contentRepositoryProvider).loadBibleChallenges();
});

final gameControllerProvider =
    StateNotifierProvider<GameController, GameState?>((ref) {
  return GameController(ref.read(contentRepositoryProvider), ref.read(saveGameServiceProvider));
});

/// Bridges `GameEngine` (pure Dart) to the widget tree. Holds no rules of
/// its own — every state change goes through `GameEngine.apply` — but owns
/// the bot "AI turn loop" so human players never have to drive bot actions.
class GameController extends StateNotifier<GameState?> {
  final ContentRepository _content;
  final SaveGameService _saves;
  int _sequence = 0;
  String? _lastError;

  GameController(this._content, this._saves) : super(null);

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

  /// Persists the current match (section 39). Safe to call mid-turn — the
  /// full `GameState` (including the RNG's exact position) is captured, so
  /// resuming later produces an identical continuation.
  Future<void> saveMatch() async {
    final current = state;
    if (current == null) return;
    await _saves.save(current);
  }

  Future<List<SaveSummary>> listSaves() => _saves.listSaves();

  Future<void> loadMatch(String gameId) async {
    final loaded = await _saves.load(gameId);
    if (loaded == null) return;
    state = loaded;
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

  void playCards(List<String> cardIds) {
    _dispatch((gameId, seq) => PlayCardAction(
          gameId: gameId,
          playerId: state!.currentPlayer.id,
          timestamp: DateTime.now(),
          sequenceNumber: seq,
          cardIds: cardIds,
        ));
    _runBotLoopIfNeeded();
  }

  void answerChallenge(String challengeId, bool correct) {
    _dispatch((gameId, seq) => AnswerChallengeAction(
          gameId: gameId,
          playerId: state!.currentPlayer.id,
          timestamp: DateTime.now(),
          sequenceNumber: seq,
          challengeId: challengeId,
          correct: correct,
        ));
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
      case GamePhase.reinforcement:
        final tradeIn = BotStrategy.decideCardTradeIn(s, playerId);
        if (tradeIn != null) {
          _dispatchPlayCards(tradeIn);
          return;
        }
        _stepReinforcement(s, playerId);
        return;

      case GamePhase.initialPlacement:
        _stepReinforcement(s, playerId);
        return;

      case GamePhase.attack:
        final decision =
            BotStrategy.decideNextAttack(s, playerId, difficulty: s.currentPlayer.botDifficulty);
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

  void _stepReinforcement(GameState s, String playerId) {
    if (s.pendingReinforcements > 0) {
      final placement = BotStrategy.decideReinforcementPlacement(
        s,
        playerId,
        s.pendingReinforcements,
        difficulty: s.currentPlayer.botDifficulty,
      );
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
  }

  void _dispatchPlayCards(List<String> cardIds) {
    _dispatch((gameId, seq) => PlayCardAction(
          gameId: gameId,
          playerId: state!.currentPlayer.id,
          timestamp: DateTime.now(),
          sequenceNumber: seq,
          cardIds: cardIds,
        ));
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

  // ---------------------------------------------------------------------
  // DEBUG MODE (section 47) — direct state edits that bypass GameEngine
  // validation entirely. Gated by kDebugMode so they are physically absent
  // from release builds, never just hidden in the UI.
  // ---------------------------------------------------------------------

  void debugGiveArmies(String territoryId, int count) {
    if (!kDebugMode) return;
    final current = state;
    if (current == null) return;
    final territory = current.territories[territoryId];
    if (territory == null) return;
    final territories = Map.of(current.territories);
    territories[territoryId] = territory.copyWith(armyCount: territory.armyCount + count);
    state = current.copyWith(territories: territories);
  }

  void debugConquerTerritory(String territoryId) {
    if (!kDebugMode) return;
    final current = state;
    if (current == null) return;
    final territory = current.territories[territoryId];
    if (territory == null) return;
    final territories = Map.of(current.territories);
    territories[territoryId] =
        territory.copyWith(ownerId: current.currentPlayer.id, armyCount: 1);
    state = current.copyWith(territories: territories, conqueredTerritoryThisTurn: true);
  }

  void debugSkipToPhase(GamePhase phase) {
    if (!kDebugMode) return;
    final current = state;
    if (current == null) return;
    state = current.copyWith(phase: phase, pendingReinforcements: 0, clearActiveBattle: true);
  }

  void debugCompleteObjective() {
    if (!kDebugMode) return;
    final current = state;
    if (current == null) return;
    state = current.copyWith(phase: GamePhase.gameOver, winnerId: current.currentPlayer.id);
  }

  void debugGiveCard() {
    if (!kDebugMode) return;
    final current = state;
    if (current == null || current.deck.isEmpty) return;
    final deck = List.of(current.deck);
    final drawn = deck.removeAt(0);
    final players = current.players
        .map((p) => p.id == current.currentPlayer.id ? p.copyWith(cards: [...p.cards, drawn]) : p)
        .toList();
    state = current.copyWith(deck: deck, players: players);
  }

  void debugResetMatch() {
    if (!kDebugMode) return;
    state = null;
  }
}
