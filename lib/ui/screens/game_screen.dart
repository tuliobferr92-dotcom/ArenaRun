import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../game_engine/domain/territory.dart';
import '../../game_engine/state/game_phase.dart';
import '../../game_engine/state/game_state.dart';
import '../design_system/tokens.dart';
import '../game_controller.dart';
import '../widgets/debug_panel.dart';
import '../widgets/hud.dart';
import '../widgets/map_view.dart';
import 'home_screen.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  String? _selectedOwnId;

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
                ref.read(gameControllerProvider.notifier).attack(from.id, to.id, troopCount);
                Navigator.of(dialogContext).pop();
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
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('FIM DE JOGO', style: ReinosTypography.title),
            const SizedBox(height: ReinosSpacing.md),
            Text('${winner.displayName} venceu!', style: ReinosTypography.heading),
            const SizedBox(height: ReinosSpacing.lg),
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
    );
  }
}
