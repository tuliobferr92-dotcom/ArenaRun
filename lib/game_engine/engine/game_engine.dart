import '../domain/bot_difficulty.dart';
import '../domain/event_card.dart';
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
  final BotDifficulty? botDifficulty;

  const PlayerConfig({
    required this.id,
    required this.displayName,
    required this.color,
    this.isBot = false,
    this.botDifficulty,
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
      final rivalId = configs[(i + 1) % configs.length].id;
      final objective = _assignObjective(i, map, rules, rivalId);
      players.add(Player(
        id: config.id,
        displayName: config.displayName,
        color: config.color,
        isBot: config.isBot,
        botDifficulty: config.botDifficulty,
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

  /// Cycles through all 5 `ObjectiveType`s (section 18) so every match
  /// exercises the full variety, not just the two simplest ones.
  static Objective _assignObjective(
    int playerIndex,
    GameMap map,
    RulesConfig rules,
    String rivalId,
  ) {
    switch (playerIndex % 5) {
      case 0:
        return Objective(
          id: 'obj_count_$playerIndex',
          type: ObjectiveType.controlTerritoryCount,
          description:
              'Controle ${rules.minTerritoriesForObjective} territórios simultaneamente.',
          params: {'count': rules.minTerritoriesForObjective},
        );
      case 1:
        return Objective(
          id: 'obj_regions_$playerIndex',
          type: ObjectiveType.controlRegions,
          description: 'Controle totalmente duas regiões do mapa.',
          params: {'regionIds': map.regions.keys.take(2).toList()},
        );
      case 2:
        final targets = map.territories.keys.take(5).toList();
        return Objective(
          id: 'obj_specific_$playerIndex',
          type: ObjectiveType.controlSpecificTerritories,
          description: 'Controle ${targets.length} territórios específicos.',
          params: {'territoryIds': targets},
        );
      case 3:
        return Objective(
          id: 'obj_eliminate_$playerIndex',
          type: ObjectiveType.eliminatePlayer,
          description: 'Elimine um rival específico do jogo.',
          params: {'targetPlayerId': rivalId},
        );
      default:
        return Objective(
          id: 'obj_hybrid_$playerIndex',
          type: ObjectiveType.hybrid,
          description: 'Controle uma região inteira E um número mínimo de territórios.',
          params: {
            'conditions': [
              {
                'type': ObjectiveType.controlRegions.name,
                'params': {'regionIds': map.regions.keys.take(1).toList()},
              },
              {
                'type': ObjectiveType.controlTerritoryCount.name,
                'params': {'count': (rules.minTerritoriesForObjective * 0.6).round()},
              },
            ],
          },
        );
    }
  }

  /// One card per territory, symbols cycled evenly, plus two wildcards
  /// (territoryId left empty — a wildcard represents no specific place).
  /// Rarity is purely cosmetic (never gates the trade-in reward) and is
  /// assigned with a simple weighted roll: ~70% common, ~25% rare, ~5%
  /// legendary.
  static List<TerritoryCard> _buildDeck(GameMap map, SeededRandom rng) {
    final symbols = CardSymbol.values.where((s) => s != CardSymbol.wildcard).toList();
    final ids = map.territories.keys.toList();
    final cards = <TerritoryCard>[];
    for (var i = 0; i < ids.length; i++) {
      cards.add(TerritoryCard(
        id: 'card_${ids[i]}',
        territoryId: ids[i],
        symbol: symbols[i % symbols.length],
        rarity: _rollRarity(rng),
      ));
    }
    for (var i = 0; i < 2; i++) {
      cards.add(TerritoryCard(
        id: 'card_wildcard_$i',
        territoryId: '',
        symbol: CardSymbol.wildcard,
        rarity: CardRarity.legendary,
      ));
    }
    return rng.shuffled(cards);
  }

  static CardRarity _rollRarity(SeededRandom rng) {
    final roll = rng.nextInt(100);
    if (roll < 70) return CardRarity.common;
    if (roll < 95) return CardRarity.rare;
    return CardRarity.legendary;
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
      AnswerChallengeAction a => _answerChallenge(state, a),
      PlayEventCardAction a => _playEventCard(state, a),
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
        defenderId: to.ownerId!,
        fromTerritoryId: from.id,
        toTerritoryId: to.id,
        rolls: [roll],
      ),
      conqueredTerritoryThisTurn: state.conqueredTerritoryThisTurn || conquered,
      clearNewlyDominatedRegion: true,
      clearNewlyDiscoveredTerritory: true,
    );

    if (conquered) {
      next = _checkEliminationAndEliminate(next);
      final newlyDominated = _findNewlyDominatedRegion(state, next, action.playerId);
      if (newlyDominated != null) {
        next = next.copyWith(newlyDominatedRegionId: newlyDominated);
      }
      if (!state.discoveredTerritoryIds.contains(to.id)) {
        next = next.copyWith(
          discoveredTerritoryIds: {...next.discoveredTerritoryIds, to.id},
          newlyDiscoveredTerritoryId: to.id,
        );
      }
    }

    return next;
  }

  /// Compares region control before/after a conquest: returns the id of a
  /// region the player did *not* fully control before this attack but does
  /// now, or null. `ReinforcementCalculator` already grants the bonus
  /// every turn regardless — this is purely for the one-shot UI banner.
  static String? _findNewlyDominatedRegion(
    GameState before,
    GameState after,
    String playerId,
  ) {
    for (final regionId in after.regions.keys) {
      final controlledBefore = before.playerControlsRegion(playerId, regionId);
      final controlledAfter = after.playerControlsRegion(playerId, regionId);
      if (!controlledBefore && controlledAfter) return regionId;
    }
    return null;
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
  // BIBLE CHALLENGES (section 22/31) — the engine only records that a
  // challenge was answered and whether it was correct; judging the answer
  // itself happens in the content layer (`BibleChallengeEngine`), which
  // `game_engine` never depends on.
  // ---------------------------------------------------------------------

  static GameState _answerChallenge(GameState state, AnswerChallengeAction action) {
    final player = state.currentPlayer;
    if (player.answeredChallengeIds.contains(action.challengeId)) {
      throw const InvalidActionException('Este desafio já foi respondido.');
    }

    // A correct answer earns a random event card (section 20) — the
    // tangible reward loop the product vision calls for: GAME → CURIOSIDADE
    // → DESCOBERTA → BÍBLIA, and back into the game as a strategic option.
    EventCard? earnedCard;
    if (action.correct) {
      final type = EventCardType.values[state.rng.nextInt(EventCardType.values.length)];
      earnedCard = EventCard(id: 'event_${action.challengeId}_${player.id}', type: type);
    }

    final players = state.players.map((p) {
      if (p.id != player.id) return p;
      return p.copyWith(
        answeredChallengeIds: {...p.answeredChallengeIds, action.challengeId},
        correctChallengeAnswers: p.correctChallengeAnswers + (action.correct ? 1 : 0),
        eventCards: earnedCard != null ? [...p.eventCards, earnedCard] : p.eventCards,
      );
    }).toList();

    return state.copyWith(players: players);
  }

  // ---------------------------------------------------------------------
  // EVENT CARDS (section 20) — mechanically-themed effects; see
  // BIBLE_CONTENT_GUIDELINES.md rule 3: the effect is never presented as
  // literally being the biblical event itself.
  // ---------------------------------------------------------------------

  static GameState _playEventCard(GameState state, PlayEventCardAction action) {
    final player = state.currentPlayer;
    EventCard? card;
    for (final c in player.eventCards) {
      if (c.id == action.eventCardId) {
        card = c;
        break;
      }
    }
    if (card == null) {
      throw const InvalidActionException('Jogador não possui esta carta de evento.');
    }
    final playedCardId = card.id;

    GameState next;
    switch (card.type) {
      case EventCardType.reconstrucao:
        final targetId = action.targetTerritoryId;
        final target = targetId != null ? state.territories[targetId] : null;
        if (target == null || target.ownerId != player.id) {
          throw const InvalidActionException(
              'Reconstrução exige um território próprio como alvo.');
        }
        final territories = Map.of(state.territories);
        territories[target.id] =
            target.copyWith(armyCount: target.armyCount + state.rules.eventCardReconstrucaoBonus);
        next = state.copyWith(territories: territories);

      case EventCardType.sabedoria:
        if (state.phase != GamePhase.reinforcement) {
          throw const InvalidActionException(
              'Sabedoria só pode ser usada durante a fase de reforços.');
        }
        next = state.copyWith(
          pendingReinforcements: state.pendingReinforcements + state.rules.eventCardSabedoriaBonus,
        );

      case EventCardType.tempoDeFartura:
        if (state.deck.isEmpty) {
          throw const InvalidActionException('O baralho de cartas territoriais está vazio.');
        }
        final deck = List.of(state.deck);
        final drawn = deck.removeAt(0);
        final players = state.players
            .map((p) => p.id == player.id ? p.copyWith(cards: [...p.cards, drawn]) : p)
            .toList();
        next = state.copyWith(deck: deck, players: players);
    }

    final updatedPlayers = next.players
        .map((p) => p.id == player.id
            ? p.copyWith(eventCards: p.eventCards.where((c) => c.id != playedCardId).toList())
            : p)
        .toList();
    return next.copyWith(players: updatedPlayers);
  }

  // ---------------------------------------------------------------------
  // CARDS
  // ---------------------------------------------------------------------

  static GameState _playCard(GameState state, PlayCardAction action) {
    if (state.phase != GamePhase.reinforcement) {
      throw const InvalidActionException(
          'Só é possível trocar cartas no início da fase de reforços.');
    }
    if (action.cardIds.length != 3) {
      throw const InvalidActionException('Troque exatamente 3 cartas por vez.');
    }

    final player = state.currentPlayer;
    final owned = {for (final c in player.cards) c.id: c};
    if (!action.cardIds.every(owned.containsKey)) {
      throw const InvalidActionException('Jogador não possui essas cartas.');
    }

    final chosen = action.cardIds.map((id) => owned[id]!).toList();
    if (!_isValidCardCombo(chosen)) {
      throw const InvalidActionException(
          'Combinação de cartas inválida (use 3 iguais ou 3 símbolos diferentes).');
    }

    final remainingCards = player.cards.where((c) => !action.cardIds.contains(c.id)).toList();
    final players = state.players
        .map((p) => p.id == player.id ? p.copyWith(cards: remainingCards) : p)
        .toList();

    final reward = state.rules.cardTradeInReward(state.cardTradeInsCompleted);

    return state.copyWith(
      players: players,
      discardPile: [...state.discardPile, ...chosen],
      pendingReinforcements: state.pendingReinforcements + reward,
      cardTradeInsCompleted: state.cardTradeInsCompleted + 1,
    );
  }

  /// A combo is valid iff the non-wildcard symbols among the 3 chosen
  /// cards are either all the same (a triple) or all distinct (a set) —
  /// wildcards fill in for whichever symbol is missing. Two-of-a-kind plus
  /// one different non-wild symbol is the only invalid shape (GAME_RULES.md
  /// "Cartas territoriais").
  static bool _isValidCardCombo(List<TerritoryCard> cards) {
    final nonWild = cards.map((c) => c.symbol).where((s) => s != CardSymbol.wildcard).toList();
    if (nonWild.length <= 2) return true;
    final distinct = nonWild.toSet().length;
    return distinct == 1 || distinct == nonWild.length;
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
        return state.copyWith(
          phase: GamePhase.fortification,
          clearActiveBattle: true,
          clearNewlyDominatedRegion: true,
          clearNewlyDiscoveredTerritory: true,
        );

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
