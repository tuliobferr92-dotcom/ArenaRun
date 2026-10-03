import '../domain/game_map.dart';
import '../domain/objective.dart';
import '../domain/player.dart';
import '../domain/player_color.dart';
import '../domain/rules_config.dart';
import '../domain/territory_card.dart';
import '../rng/seeded_random.dart';
import '../state/battle_state.dart';
import '../state/game_action.dart';
import '../state/game_phase.dart';
import '../state/game_state.dart';
import 'battle_engine.dart';
import 'game_exceptions.dart';
import 'objective_engine.dart';
import 'reinforcement_calculator.dart';

class PlayerConfig {
  final String id;
  final String displayName;
  final PlayerColor color;
  final bool isBot;

  const PlayerConfig({
    required this.id,
    required this.displayName,
    required this.color,
    this.isBot = false,
  });
}

/// The only place match rules are enforced (section 6/12/44/45). Pure Dart,
/// no Flutter import — `GameEngine.apply` is a deterministic reducer:
/// `GameState -> GameAction -> GameState`, suitable for client prediction
/// today and a server-authoritative implementation later.
class GameEngine {
  /// Builds the initial [GameState]: territories distributed round-robin,
  /// objectives assigned, phase set to [GamePhase.initialPlacement].
  static GameState newMatch({
    required GameMap map,
    required List<PlayerConfig> configs,
    required RulesConfig rules,
    required int seed,
  }) {
    final rng = SeededRandom(seed);

    final players = <Player>[];
    for (var i = 0; i < configs.length; i++) {
      final config = configs[i];
      final objective = i.isEven
          ? Objective(
              id: 'obj_count_$i',
              type: ObjectiveType.controlTerritoryCount,
              description:
                  'Controle ${rules.minTerritoriesForObjective} territórios simultaneamente.',
              params: {'count': rules.minTerritoriesForObjective},
            )
          : Objective(
              id: 'obj_regions_$i',
              type: ObjectiveType.controlRegions,
              description: 'Controle totalmente duas regiões do mapa.',
              params: {
                'regionIds': map.regions.keys.take(2).toList(),
              },
            );
      players.add(Player(
        id: config.id,
        displayName: config.displayName,
        color: config.color,
        isBot: config.isBot,
        objective: objective,
      ));
    }

    final territoryIds = rng.shuffled(map.territories.keys.toList());
    final territories = Map.of(map.territories);
    for (var i = 0; i < territoryIds.length; i++) {
      final ownerId = players[i % players.length].id;
      final id = territoryIds[i];
      territories[id] = territories[id]!
          .copyWith(ownerId: ownerId, armyCount: rules.startingArmiesPerTerritory);
    }

    final deck = _buildDeck(map, rng);

    return GameState(
      gameId: 'game_${DateTime.now().microsecondsSinceEpoch}',
      mapId: map.id,
      regions: map.regions,
      territories: territories,
      players: players,
      currentPlayerIndex: 0,
      phase: GamePhase.initialPlacement,
      turnNumber: 1,
      deck: deck,
      discardPile: const [],
      rng: rng,
      rules: rules,
      pendingReinforcements: rules.initialPlacementExtraArmies,
    );
  }

  static List<TerritoryCard> _buildDeck(GameMap map, SeededRandom rng) {
    final symbols = CardSymbol.values.where((s) => s != CardSymbol.wildcard).toList();
    final ids = map.territories.keys.toList();
    final cards = <TerritoryCard>[];
    for (var i = 0; i < ids.length; i++) {
      cards.add(TerritoryCard(
        id: 'card_${ids[i]}',
        territoryId: ids[i],
        symbol: symbols[i % symbols.length],
      ));
    }
    return rng.shuffled(cards);
  }

  /// Applies [action] to [state], returning a brand new [GameState].
  /// Throws [InvalidActionException] if the action is illegal in the
  /// current phase — never silently ignored (section 6).
  static GameState apply(GameState state, GameAction action) {
    _assertCurrentPlayer(state, action.playerId);

    GameState next = switch (action) {
      PlaceArmyAction a => _placeArmy(state, a),
      ReinforceAction a => _reinforce(state, a),
      AttackAction a => _attack(state, a),
      MoveArmyAction a => _moveArmy(state, a),
      PlayCardAction a => _playCard(state, a),
      EndPhaseAction a => _endPhase(state, a),
      _ => throw InvalidActionException('Ação desconhecida: ${action.runtimeType}'),
    };

    next = next.copyWith(actionHistory: [...next.actionHistory, action]);
    return next;
  }

  static void _assertCurrentPlayer(GameState state, String playerId) {
    if (state.phase == GamePhase.gameOver) {
      throw const InvalidActionException('A partida já terminou.');
    }
    if (state.currentPlayer.id != playerId) {
      throw const InvalidActionException('Não é o turno deste jogador.');
    }
  }

  // ---------------------------------------------------------------------
  // INITIAL PLACEMENT / REINFORCEMENT
  // ---------------------------------------------------------------------

  static GameState _placeArmy(GameState state, PlaceArmyAction action) {
    if (state.phase != GamePhase.initialPlacement && state.phase != GamePhase.reinforcement) {
      throw const InvalidActionException(
          'Só é possível posicionar exércitos durante posicionamento inicial ou reforços.');
    }
    final territory = state.territories[action.territoryId];
    if (territory == null || territory.ownerId != action.playerId) {
      throw const InvalidActionException('Território inválido ou não pertence ao jogador.');
    }
    if (action.count > state.pendingReinforcements) {
      throw const InvalidActionException('Reforços insuficientes para essa quantidade.');
    }

    final territories = Map.of(state.territories);
    territories[action.territoryId] =
        territory.copyWith(armyCount: territory.armyCount + action.count);

    var next = state.copyWith(
      territories: territories,
      pendingReinforcements: state.pendingReinforcements - action.count,
    );

    if (next.pendingReinforcements > 0) return next;

    if (state.phase == GamePhase.initialPlacement) {
      return _advanceInitialPlacement(next);
    }
    // Reinforcement phase: all reinforcements placed; player must still
    // explicitly end the phase (they may want to review before attacking).
    return next;
  }

  static GameState _advanceInitialPlacement(GameState state) {
    final isLastPlayer = state.currentPlayerIndex == state.players.length - 1;
    if (!isLastPlayer) {
      return state.copyWith(
        currentPlayerIndex: state.currentPlayerIndex + 1,
        pendingReinforcements: state.rules.initialPlacementExtraArmies,
      );
    }
    return _enterTurnStart(state.copyWith(currentPlayerIndex: 0));
  }

  static GameState _enterTurnStart(GameState state) {
    final started = state.copyWith(phase: GamePhase.turnStart);
    final reinforcements =
        ReinforcementCalculator.calculate(started, started.currentPlayer.id, started.rules);
    return started.copyWith(
      phase: GamePhase.reinforcement,
      pendingReinforcements: reinforcements,
      conqueredTerritoryThisTurn: false,
    );
  }

  static GameState _reinforce(GameState state, ReinforceAction action) {
    if (state.phase != GamePhase.reinforcement) {
      throw const InvalidActionException('Fora da fase de reforços.');
    }
    final total = action.armiesByTerritory.values.fold(0, (a, b) => a + b);
    if (total != state.pendingReinforcements) {
      throw const InvalidActionException('A soma dos reforços não corresponde ao disponível.');
    }
    final territories = Map.of(state.territories);
    for (final entry in action.armiesByTerritory.entries) {
      final territory = territories[entry.key];
      if (territory == null || territory.ownerId != action.playerId) {
        throw const InvalidActionException('Território inválido para reforço.');
      }
      territories[entry.key] = territory.copyWith(armyCount: territory.armyCount + entry.value);
    }
    return state.copyWith(territories: territories, pendingReinforcements: 0);
  }

  // ---------------------------------------------------------------------
  // ATTACK / BATTLE / CONQUEST
  // ---------------------------------------------------------------------

  static GameState _attack(GameState state, AttackAction action) {
    if (state.phase != GamePhase.reinforcement && state.phase != GamePhase.attack) {
      throw const InvalidActionException('Fora da fase de ataque.');
    }
    if (state.phase == GamePhase.reinforcement && state.pendingReinforcements > 0) {
      throw const InvalidActionException('Distribua todos os reforços antes de atacar.');
    }

    final from = state.territories[action.fromTerritoryId];
    final to = state.territories[action.toTerritoryId];
    if (from == null || to == null) {
      throw const InvalidActionException('Território inexistente.');
    }
    if (from.ownerId != action.playerId) {
      throw const InvalidActionException('O atacante não controla o território de origem.');
    }
    if (to.ownerId == action.playerId) {
      throw const InvalidActionException('Não é possível atacar território próprio.');
    }
    if (!from.isAdjacentTo(to.id)) {
      throw const InvalidActionException('Territórios não são adjacentes.');
    }
    if (action.troopCount < 1 || action.troopCount > from.armyCount - 1) {
      throw const InvalidActionException('Quantidade de tropas de ataque inválida.');
    }

    final roll = BattleEngine.resolveRound(
      attackingTroops: action.troopCount,
      defendingTroops: to.armyCount,
      rules: state.rules,
      rng: state.rng,
    );

    final territories = Map.of(state.territories);
    var updatedFrom = from.copyWith(armyCount: from.armyCount - roll.attackerLosses);
    var updatedTo = to.copyWith(armyCount: to.armyCount - roll.defenderLosses);

    var conquered = false;
    if (roll.territoryConquered) {
      conquered = true;
      final survivors = (action.troopCount - roll.attackerLosses).clamp(1, updatedFrom.armyCount);
      updatedFrom = updatedFrom.copyWith(armyCount: updatedFrom.armyCount - survivors);
      updatedTo = updatedTo.copyWith(
        ownerId: action.playerId,
        armyCount: survivors,
      );
    }

    territories[from.id] = updatedFrom;
    territories[to.id] = updatedTo;

    var next = state.copyWith(
      phase: GamePhase.attack,
      territories: territories,
      activeBattle: BattleState(
        attackerId: action.playerId,
        fromTerritoryId: from.id,
        toTerritoryId: to.id,
        rolls: [roll],
      ),
      conqueredTerritoryThisTurn: state.conqueredTerritoryThisTurn || conquered,
    );

    if (conquered) {
      next = _checkEliminationAndEliminate(next);
    }

    return next;
  }

  static GameState _checkEliminationAndEliminate(GameState state) {
    final players = state.players.map((p) {
      final hasTerritory = state.territories.values.any((t) => t.ownerId == p.id);
      return hasTerritory ? p : p.copyWith(isEliminated: true);
    }).toList();
    return state.copyWith(players: players);
  }

  // ---------------------------------------------------------------------
  // FORTIFICATION
  // ---------------------------------------------------------------------

  static GameState _moveArmy(GameState state, MoveArmyAction action) {
    if (state.phase != GamePhase.attack && state.phase != GamePhase.fortification) {
      throw const InvalidActionException('Fora da fase de movimentação.');
    }
    final from = state.territories[action.fromTerritoryId];
    final to = state.territories[action.toTerritoryId];
    if (from == null || to == null) {
      throw const InvalidActionException('Território inexistente.');
    }
    if (from.ownerId != action.playerId || to.ownerId != action.playerId) {
      throw const InvalidActionException('Movimentação exige controlar ambos os territórios.');
    }
    if (!from.isAdjacentTo(to.id)) {
      throw const InvalidActionException('Territórios não são adjacentes.');
    }
    if (action.count < 1 || action.count > from.armyCount - 1) {
      throw const InvalidActionException('Quantidade de tropas inválida para movimentação.');
    }

    final territories = Map.of(state.territories);
    territories[from.id] = from.copyWith(armyCount: from.armyCount - action.count);
    territories[to.id] = to.copyWith(armyCount: to.armyCount + action.count);

    return state.copyWith(phase: GamePhase.fortification, territories: territories);
  }

  // ---------------------------------------------------------------------
  // CARDS
  // ---------------------------------------------------------------------

  static GameState _playCard(GameState state, PlayCardAction action) {
    // Card trade-in mechanics land in Phase 2 (ROADMAP.md). Validate shape
    // now so the action type is already exercised by tests/UI.
    final player = state.currentPlayer;
    final owned = player.cards.map((c) => c.id).toSet();
    if (!action.cardIds.every(owned.contains)) {
      throw const InvalidActionException('Jogador não possui essas cartas.');
    }
    final remainingCards = player.cards.where((c) => !action.cardIds.contains(c.id)).toList();
    final discarded = player.cards.where((c) => action.cardIds.contains(c.id)).toList();
    final players = state.players
        .map((p) => p.id == player.id ? p.copyWith(cards: remainingCards) : p)
        .toList();
    return state.copyWith(players: players, discardPile: [...state.discardPile, ...discarded]);
  }

  // ---------------------------------------------------------------------
  // PHASE TRANSITIONS
  // ---------------------------------------------------------------------

  static GameState _endPhase(GameState state, EndPhaseAction action) {
    switch (state.phase) {
      case GamePhase.reinforcement:
        if (state.pendingReinforcements > 0) {
          throw const InvalidActionException('Distribua todos os reforços antes de avançar.');
        }
        return state.copyWith(phase: GamePhase.attack, clearActiveBattle: true);

      case GamePhase.attack:
        return state.copyWith(phase: GamePhase.fortification, clearActiveBattle: true);

      case GamePhase.fortification:
        return _enterCardReward(state);

      default:
        throw InvalidActionException('Não é possível avançar a partir de ${state.phase}.');
    }
  }

  static GameState _enterCardReward(GameState state) {
    var next = state.copyWith(phase: GamePhase.cardReward);
    if (next.conqueredTerritoryThisTurn && next.deck.isNotEmpty) {
      final deck = List.of(next.deck);
      final drawn = deck.removeAt(0);
      final players = next.players
          .map((p) => p.id == next.currentPlayer.id ? p.copyWith(cards: [...p.cards, drawn]) : p)
          .toList();
      next = next.copyWith(deck: deck, players: players);
    }
    return _enterTurnEnd(next);
  }

  static GameState _enterTurnEnd(GameState state) {
    var next = state.copyWith(phase: GamePhase.turnEnd);

    if (ObjectiveEngine.isComplete(next, next.currentPlayer.id)) {
      return next.copyWith(phase: GamePhase.gameOver, winnerId: next.currentPlayer.id);
    }
    final sole = ObjectiveEngine.soleSurvivor(next);
    if (sole != null) {
      return next.copyWith(phase: GamePhase.gameOver, winnerId: sole);
    }

    final nextIndex = _nextAlivePlayerIndex(next);
    final wrapped = nextIndex <= next.currentPlayerIndex;
    next = next.copyWith(
      currentPlayerIndex: nextIndex,
      turnNumber: wrapped ? next.turnNumber + 1 : next.turnNumber,
    );
    return _enterTurnStart(next);
  }

  static int _nextAlivePlayerIndex(GameState state) {
    var index = state.currentPlayerIndex;
    for (var i = 0; i < state.players.length; i++) {
      index = (index + 1) % state.players.length;
      if (!state.players[index].isEliminated) return index;
    }
    return state.currentPlayerIndex;
  }
}
