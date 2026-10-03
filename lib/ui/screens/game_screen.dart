import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../animations/battle_sequence_overlay.dart';
import '../../animations/discovery_banner.dart';
import '../../animations/regional_dominance_banner.dart';
import '../../content/engine/bible_challenge_engine.dart';
import '../../game_engine/domain/player.dart';
import '../../game_engine/domain/territory.dart';
import '../../game_engine/state/battle_state.dart';
import '../../game_engine/state/game_phase.dart';
import '../../game_engine/state/game_state.dart';
import '../design_system/tokens.dart';
import '../game_controller.dart';
import '../widgets/card_hand_sheet.dart';
import '../widgets/debug_panel.dart';
import '../widgets/event_card_sheet.dart';
import '../widgets/hud.dart';
import '../widgets/map_view.dart';
import 'home_screen.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen>
    with SingleTickerProviderStateMixin {
  String? _selectedOwnId;

  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  )..addListener(() => setState(() {}));
  String? _pulsingTerritoryId;

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  /// Brief glowing ring around a just-conquered territory (section 15/17)
  /// — a lightweight, map-level echo of the conquest the overlay already
  /// announced, so the board itself visibly reacts to ownership changing.
  Future<void> _triggerConquestPulse(String territoryId) async {
    setState(() => _pulsingTerritoryId = territoryId);
    for (var i = 0; i < 2 && mounted; i++) {
      await _pulseController.forward(from: 0);
    }
    if (mounted) setState(() => _pulsingTerritoryId = null);
  }

  Player _playerById(GameState state, String id) =>
      state.players.firstWhere((p) => p.id == id);

  Color _playerColor(GameState state, String playerId) {
    final index = state.players.indexWhere((p) => p.id == playerId);
    return ReinosColors.playerColors[index % ReinosColors.playerColors.length];
  }

  void _showBattleOverlay(GameState afterState, BattleState battle) {
    final roll = battle.rolls.last;
    final conquered = roll.territoryConquered;
    final territoryName = afterState.territories[battle.toTerritoryId]!.name;

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: Duration.zero,
      pageBuilder: (dialogContext, _, _) => BattleSequenceOverlay(
        attackerName: _playerById(afterState, battle.attackerId).displayName,
        defenderName: _playerById(afterState, battle.defenderId).displayName,
        attackerColor: _playerColor(afterState, battle.attackerId),
        defenderColor: _playerColor(afterState, battle.defenderId),
        roll: roll,
        conquered: conquered,
        territoryName: territoryName,
        audio: ref.read(audioServiceProvider),
        onDismiss: () {
          Navigator.of(dialogContext).pop();
          if (conquered) _afterConquestDismissed(afterState, battle.toTerritoryId);
        },
      ),
    );
  }

  /// Chains the post-conquest beats (section 15/17/30) one at a time, in
  /// order, so they never pile up on screen together: map pulse (fire and
  /// forget — purely cosmetic), then the regional-dominance banner if this
  /// conquest completed a region, then the discovery banner if this is the
  /// territory's first-ever conquest this match.
  Future<void> _afterConquestDismissed(GameState afterState, String territoryId) async {
    _triggerConquestPulse(territoryId);

    final regionId = afterState.newlyDominatedRegionId;
    if (regionId != null) {
      await _showRegionalDominanceBanner(afterState, regionId);
    }

    if (afterState.newlyDiscoveredTerritoryId == territoryId) {
      await _showDiscoveryBanner(afterState, territoryId);
    }
  }

  Future<void> _showRegionalDominanceBanner(GameState state, String regionId) {
    final region = state.regions[regionId]!;
    return showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: Duration.zero,
      pageBuilder: (dialogContext, _, _) => RegionalDominanceBanner(
        regionName: region.name,
        reinforcementBonus: region.controlBonus,
        onDismiss: () => Navigator.of(dialogContext).pop(),
      ),
    );
  }

  Future<void> _showDiscoveryBanner(GameState state, String territoryId) async {
    final territory = state.territories[territoryId]!;
    final challenges = await ref.read(bibleChallengesProvider.future);
    final challenge = BibleChallengeEngine.nextChallengeForTerritory(
      challenges,
      territoryId,
      state.currentPlayer.answeredChallengeIds,
    );
    if (!mounted) return;

    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: Duration.zero,
      pageBuilder: (dialogContext, _, _) => DiscoveryBanner(
        territoryName: territory.name,
        biblicalReferences: territory.biblicalReferences,
        challenge: challenge,
        onAnswered: (challengeId, correct) =>
            ref.read(gameControllerProvider.notifier).answerChallenge(challengeId, correct),
        onDismiss: () => Navigator.of(dialogContext).pop(),
      ),
    );
  }

  void _handleTap(GameState state, String tappedId) {
    final currentPlayerId = state.currentPlayer.id;
    final tapped = state.territories[tappedId]!;
    final selected = _selectedOwnId != null ? state.territories[_selectedOwnId] : null;

    if (selected != null && selected.id != tapped.id && selected.isAdjacentTo(tapped.id)) {
      final isOwnTarget = tapped.ownerId == currentPlayerId;
      if (isOwnTarget && state.phase == GamePhase.fortification) {
        _openMoveDialog(state, selected, tapped);
        return;
      }
      final canAttackNow = state.phase == GamePhase.attack ||
          (state.phase == GamePhase.reinforcement && state.pendingReinforcements == 0);
      if (!isOwnTarget && canAttackNow) {
        _openAttackDialog(state, selected, tapped);
        return;
      }
    }

    setState(() {
      _selectedOwnId = tapped.ownerId == currentPlayerId ? tapped.id : null;
    });

    if (tapped.ownerId != currentPlayerId) {
      _showInfoSheet(tapped);
    }
  }

  void _showInfoSheet(Territory territory) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ReinosColors.surface,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(ReinosSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(territory.name, style: ReinosTypography.heading),
            const SizedBox(height: ReinosSpacing.sm),
            Text(territory.description, style: ReinosTypography.body),
            if (territory.biblicalReferences.isNotEmpty) ...[
              const SizedBox(height: ReinosSpacing.sm),
              Text('📖 ${territory.biblicalReferences.join(', ')}',
                  style: ReinosTypography.label),
            ],
          ],
        ),
      ),
    );
  }

  void _openAttackDialog(GameState state, Territory from, Territory to) {
    int troopCount = (from.armyCount - 1).clamp(1, state.rules.maxDiceAttacker);
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: ReinosColors.surface,
          title: Text('Atacar ${to.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('De ${from.name} (${from.armyCount} exércitos)'),
              Slider(
                value: troopCount.toDouble(),
                min: 1,
                max: (from.armyCount - 1).clamp(1, 99).toDouble(),
                divisions: (from.armyCount - 1) > 1 ? from.armyCount - 2 : null,
                label: '$troopCount',
                onChanged: (v) => setDialogState(() => troopCount = v.round()),
              ),
              Text('Tropas atacantes: $troopCount'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final controller = ref.read(gameControllerProvider.notifier);
                controller.attack(from.id, to.id, troopCount);
                Navigator.of(dialogContext).pop();

                final afterState = ref.read(gameControllerProvider);
                final battle = afterState?.activeBattle;
                if (controller.lastError == null && battle != null) {
                  _showBattleOverlay(afterState!, battle);
                }
              },
              child: const Text('ATACAR'),
            ),
          ],
        ),
      ),
    );
  }

  void _openMoveDialog(GameState state, Territory from, Territory to) {
    int count = 1;
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: ReinosColors.surface,
          title: Text('Mover para ${to.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Slider(
                value: count.toDouble(),
                min: 1,
                max: (from.armyCount - 1).clamp(1, 99).toDouble(),
                divisions: (from.armyCount - 1) > 1 ? from.armyCount - 2 : null,
                label: '$count',
                onChanged: (v) => setDialogState(() => count = v.round()),
              ),
              Text('Tropas a mover: $count'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                ref.read(gameControllerProvider.notifier).moveArmy(from.id, to.id, count);
                Navigator.of(dialogContext).pop();
              },
              child: const Text('MOVER'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveAndExit() async {
    await ref.read(gameControllerProvider.notifier).saveMatch();
    if (!mounted) return;
    // Pushes a fresh HomeScreen (rather than popping back to a stale one)
    // so its save-slot list re-reads disk and immediately reflects this save.
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  void _showHand(GameState state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ReinosColors.surface,
      isScrollControlled: true,
      builder: (sheetContext) => CardHandSheet(
        cards: state.currentPlayer.cards,
        onTradeIn: (cardIds) {
          final controller = ref.read(gameControllerProvider.notifier);
          controller.playCards(cardIds);
          final error = controller.lastError;
          if (error != null) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
          } else {
            Navigator.of(sheetContext).pop();
          }
        },
      ),
    );
  }

  void _showEventCards(GameState state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ReinosColors.surface,
      isScrollControlled: true,
      builder: (sheetContext) => EventCardSheet(
        eventCards: state.currentPlayer.eventCards,
        selectedOwnTerritoryId: _selectedOwnId,
        onPlay: (eventCardId, {targetTerritoryId}) {
          final controller = ref.read(gameControllerProvider.notifier);
          controller.playEventCard(eventCardId, targetTerritoryId: targetTerritoryId);
          final error = controller.lastError;
          if (error != null) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
          } else {
            Navigator.of(sheetContext).pop();
          }
        },
      ),
    );
  }

  void _showObjective(GameState state) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: ReinosColors.surface,
        title: const Text('🎯 Objetivo Secreto'),
        content: Text(state.currentPlayer.objective.description),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(gameControllerProvider);
    if (state == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (state.phase == GamePhase.gameOver) {
      return _GameOverView(state: state);
    }

    final selected = _selectedOwnId != null ? state.territories[_selectedOwnId] : null;
    final canEndPhase = switch (state.phase) {
      GamePhase.reinforcement => state.pendingReinforcements == 0,
      GamePhase.attack => true,
      GamePhase.fortification => true,
      _ => false,
    };

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: MapView(
              state: state,
              selectedTerritoryId: _selectedOwnId,
              onTerritoryTap: (id) => _handleTap(state, id),
              pulsingTerritoryId: _pulsingTerritoryId,
              pulseValue: _pulseController.value,
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: GameHud(
              state: state,
              canEndPhase: canEndPhase,
              onEndPhase: () => ref.read(gameControllerProvider.notifier).endPhase(),
              onShowObjective: () => _showObjective(state),
              onSaveAndExit: _saveAndExit,
              onShowHand: () => _showHand(state),
              onShowEventCards: () => _showEventCards(state),
            ),
          ),
          if (selected != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: _SelectedTerritoryPanel(
                territory: selected,
                state: state,
                onReinforce: state.phase == GamePhase.reinforcement &&
                        state.pendingReinforcements > 0
                    ? () => ref.read(gameControllerProvider.notifier).placeArmy(selected.id)
                    : null,
              ),
            ),
        ],
      ),
      floatingActionButton: isDebugModeAvailable
          ? FloatingActionButton.small(
              backgroundColor: ReinosColors.bronze,
              tooltip: 'Debug Mode',
              onPressed: () => showDebugPanel(context, ref, state, _selectedOwnId),
              child: const Icon(Icons.bug_report),
            )
          : null,
    );
  }
}

class _SelectedTerritoryPanel extends StatelessWidget {
  final Territory territory;
  final GameState state;
  final VoidCallback? onReinforce;

  const _SelectedTerritoryPanel({
    required this.territory,
    required this.state,
    required this.onReinforce,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(ReinosSpacing.md),
        padding: const EdgeInsets.all(ReinosSpacing.md),
        decoration: BoxDecoration(
          color: ReinosColors.surface,
          borderRadius: BorderRadius.circular(ReinosRadius.md),
          border: Border.all(color: ReinosColors.bronze),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(territory.name, style: ReinosTypography.heading),
                  Text('${territory.armyCount} exércitos', style: ReinosTypography.label),
                ],
              ),
            ),
            if (onReinforce != null)
              FilledButton(onPressed: onReinforce, child: const Text('+1 Reforço')),
          ],
        ),
      ),
    );
  }
}

class _GameOverView extends StatelessWidget {
  final GameState state;

  const _GameOverView({required this.state});

  @override
  Widget build(BuildContext context) {
    final winner = state.players.firstWhere((p) => p.id == state.winnerId);
    // "Sua Jornada" (section 31) is written from the human player's point
    // of view — the setup flow always seats the human as the first,
    // non-bot player.
    final human = state.players.firstWhere((p) => !p.isBot, orElse: () => state.players.first);
    final discoveredNames =
        state.discoveredTerritoryIds.map((id) => state.territories[id]!.name).toList()..sort();

    return Scaffold(
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(ReinosSpacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('FIM DE JOGO', style: ReinosTypography.title),
                const SizedBox(height: ReinosSpacing.md),
                Text('${winner.displayName} venceu!', style: ReinosTypography.heading),
                const SizedBox(height: ReinosSpacing.xl),
                Text('📜 SUA JORNADA', style: ReinosTypography.heading),
                const SizedBox(height: ReinosSpacing.sm),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: ReinosSpacing.lg,
                  runSpacing: ReinosSpacing.sm,
                  children: [
                    _JourneyStat(label: 'Turnos', value: '${state.turnNumber}'),
                    _JourneyStat(
                      label: 'Territórios descobertos',
                      value: '${state.discoveredTerritoryIds.length}',
                    ),
                    _JourneyStat(
                      label: 'Desafios respondidos',
                      value:
                          '${human.correctChallengeAnswers}/${human.answeredChallengeIds.length} corretos',
                    ),
                  ],
                ),
                if (discoveredNames.isNotEmpty) ...[
                  const SizedBox(height: ReinosSpacing.lg),
                  Text('VOCÊ DESCOBRIU', style: ReinosTypography.label),
                  const SizedBox(height: ReinosSpacing.sm),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: ReinosSpacing.sm,
                    runSpacing: ReinosSpacing.sm,
                    children: discoveredNames
                        .map((name) => Chip(
                              label: Text(name),
                              backgroundColor: ReinosColors.surface,
                            ))
                        .toList(),
                  ),
                ],
                const SizedBox(height: ReinosSpacing.xl),
                FilledButton(
                  onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                    (route) => false,
                  ),
                  child: const Text('VOLTAR AO INÍCIO'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _JourneyStat extends StatelessWidget {
  final String label;
  final String value;

  const _JourneyStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: ReinosTypography.heading),
        Text(label, style: ReinosTypography.label),
      ],
    );
  }
}
