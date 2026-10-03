import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../content/content_repository.dart';
import 'package:reinos_engine/content/domain/bible_challenge.dart';
import 'package:reinos_engine/game_engine/domain/game_map.dart';
import 'package:reinos_engine/game_engine/engine/bot_strategy.dart';
import 'package:reinos_engine/game_engine/engine/game_engine.dart';
import 'package:reinos_engine/game_engine/engine/game_exceptions.dart';
import 'package:reinos_engine/game_engine/state/game_action.dart';
import 'package:reinos_engine/game_engine/state/game_phase.dart';
import 'package:reinos_engine/game_engine/state/game_state.dart';
import '../network/network_client.dart';
import '../services/audio_service.dart';
import '../services/save_game_service.dart';

final contentRepositoryProvider = Provider<ContentRepository>((ref) {
  return AssetContentRepository();
});

final saveGameServiceProvider = Provider<SaveGameService>((ref) {
  return FileSaveGameService();
});

final audioServiceProvider = Provider<AudioService>((ref) {
  return AssetAudioService();
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

  // ---------------------------------------------------------------------
  // ONLINE MULTIPLAYER (section 36/37) — when `_network` is set, every
  // dispatch is sent to the server instead of applied locally; the
  // server is the sole source of truth and `state` only ever changes in
  // response to its broadcasts (see `_handleNetworkMessage`).
  // ---------------------------------------------------------------------
  NetworkClient? _network;
  StreamSubscription<Map<String, dynamic>>? _networkSub;
  String? _roomCode;
  String? _localPlayerId;
  Completer<void>? _pendingConnect;
  void Function(String playerId)? onPlayerConnected;
  void Function(String playerId)? onPlayerDisconnected;

  GameController(this._content, this._saves) : super(null);

  String? get lastError => _lastError;
  bool get isOnline => _network != null;
  String? get roomCode => _roomCode;
  String? get localPlayerId => _localPlayerId;

  /// True whenever there's no online seat to gate on (offline/pass-and-play)
  /// or it's genuinely this device's turn. UI uses this to disable action
  /// controls while waiting on the remote opponent.
  bool get isMyTurn => _localPlayerId == null || state?.currentPlayer.id == _localPlayerId;

  /// Connects to [serverUrl], creates a new online room for [players] and
  /// waits for the server's confirmation before returning. [hostPlayerId]
  /// must be one of the ids in [players] — the seat this device plays.
  Future<void> createOnlineRoom({
    required String serverUrl,
    required String mapId,
    required List<PlayerConfig> players,
    required String hostPlayerId,
    int seed = 1,
  }) async {
    _localPlayerId = hostPlayerId;
    final network = NetworkClient.connect(serverUrl);
    _network = network;
    final connected = Completer<void>();
    _pendingConnect = connected;
    _networkSub = network.messages.listen(_handleNetworkMessage);
    network.createRoom(
      mapId: mapId,
      hostPlayerId: hostPlayerId,
      seed: seed,
      players: players.map(_encodePlayerConfig).toList(),
    );
    return connected.future;
  }

  /// Connects to [serverUrl] and joins an existing room by [roomCode],
  /// taking the seat [playerId] (must match one of that room's original
  /// configs — the server rejects anything else).
  Future<void> joinOnlineRoom({
    required String serverUrl,
    required String roomCode,
    required String playerId,
  }) async {
    _localPlayerId = playerId;
    final network = NetworkClient.connect(serverUrl);
    _network = network;
    final connected = Completer<void>();
    _pendingConnect = connected;
    _networkSub = network.messages.listen(_handleNetworkMessage);
    network.joinRoom(roomCode: roomCode, playerId: playerId);
    return connected.future;
  }

  Future<void> disconnectOnline() async {
    await _networkSub?.cancel();
    await _network?.dispose();
    _network = null;
    _networkSub = null;
    _roomCode = null;
    _localPlayerId = null;
    _pendingConnect = null;
  }

  Map<String, dynamic> _encodePlayerConfig(PlayerConfig p) => {
        'id': p.id,
        'displayName': p.displayName,
        'color': p.color.name,
        'isBot': p.isBot,
        if (p.botDifficulty != null) 'botDifficulty': p.botDifficulty!.name,
      };

  void _handleNetworkMessage(Map<String, dynamic> message) {
    switch (message['type']) {
      case 'roomCreated':
      case 'joined':
        _roomCode = message['roomCode'] as String;
        state = GameState.fromJson(message['state'] as Map<String, dynamic>);
        _lastError = null;
        _pendingConnect?.complete();
        _pendingConnect = null;
        break;

      case 'stateUpdate':
        state = GameState.fromJson(message['state'] as Map<String, dynamic>);
        _lastError = null;
        break;

      case 'playerConnected':
        onPlayerConnected?.call(message['playerId'] as String);
        break;

      case 'playerDisconnected':
        onPlayerDisconnected?.call(message['playerId'] as String);
        break;

      case 'error':
        _lastError = message['message'] as String;
        if (_pendingConnect != null && !_pendingConnect!.isCompleted) {
          _pendingConnect!.completeError(StateError(_lastError!));
          _pendingConnect = null;
        }
        break;
    }
  }

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

    final network = _network;
    if (network != null) {
      // Server-authoritative: never apply locally. `state` only changes
      // once the server's `stateUpdate` broadcast comes back (section 36).
      if (_roomCode == null || _localPlayerId == null) return;
      if (current.currentPlayer.id != _localPlayerId) {
        _lastError = 'Não é sua vez.';
        return;
      }
      network.sendAction(roomCode: _roomCode!, playerId: _localPlayerId!, action: action);
      _lastError = null;
      return;
    }

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

  void playEventCard(String eventCardId, {String? targetTerritoryId}) {
    _dispatch((gameId, seq) => PlayEventCardAction(
          gameId: gameId,
          playerId: state!.currentPlayer.id,
          timestamp: DateTime.now(),
          sequenceNumber: seq,
          eventCardId: eventCardId,
          targetTerritoryId: targetTerritoryId,
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
    if (_network != null) return; // the server drives bots in online matches
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

  @override
  void dispose() {
    _networkSub?.cancel();
    _network?.dispose();
    super.dispose();
  }
}
