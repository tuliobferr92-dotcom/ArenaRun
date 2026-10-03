import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game_engine/state/battle_state.dart';
import '../services/audio_service.dart';
import '../ui/design_system/tokens.dart';

enum _BattleStage { rolling, revealed, done }

/// Full battle presentation sequence (section 15): highlight the two
/// territories, show committed troops, "roll" the dice, reveal and compare
/// them pair by pair, show losses, and — if the defender fell — a
/// conquest banner. The dice outcome itself was already decided by
/// `BattleEngine` before this widget ever runs; this only *reveals* it with
/// pacing, haptics (section 41) and sound hooks (section 40). The engine
/// never waits on this animation (section 43) — `GameState` is already
/// final by the time this shows.
class BattleSequenceOverlay extends StatefulWidget {
  final String attackerName;
  final String defenderName;
  final Color attackerColor;
  final Color defenderColor;
  final DiceRollResult roll;
  final bool conquered;
  final String territoryName;
  final AudioService audio;
  final VoidCallback onDismiss;

  const BattleSequenceOverlay({
    super.key,
    required this.attackerName,
    required this.defenderName,
    required this.attackerColor,
    required this.defenderColor,
    required this.roll,
    required this.conquered,
    required this.territoryName,
    required this.audio,
    required this.onDismiss,
  });

  @override
  State<BattleSequenceOverlay> createState() => _BattleSequenceOverlayState();
}

class _BattleSequenceOverlayState extends State<BattleSequenceOverlay>
    with SingleTickerProviderStateMixin {
  _BattleStage _stage = _BattleStage.rolling;
  late final AnimationController _spinController;

  // Explicit, cancellable timers (rather than an `await Future.delayed`
  // chain) so skipping or disposing mid-sequence never leaves a pending
  // Timer behind — `flutter_test` fails the test if one does.
  Timer? _revealTimer;
  Timer? _doneTimer;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))
      ..repeat();
    widget.audio.play(SoundEvent.diceRoll);
    _revealTimer = Timer(const Duration(milliseconds: 700), _reveal);
  }

  @override
  void dispose() {
    _revealTimer?.cancel();
    _doneTimer?.cancel();
    _spinController.dispose();
    super.dispose();
  }

  void _reveal() {
    _spinController.stop();
    setState(() => _stage = _BattleStage.revealed);
    HapticFeedback.mediumImpact();
    widget.audio.play(SoundEvent.battleImpact);
    _doneTimer = Timer(const Duration(milliseconds: 900), _finish);
  }

  void _finish() {
    setState(() => _stage = _BattleStage.done);
    if (widget.conquered) {
      HapticFeedback.heavyImpact();
      widget.audio.play(SoundEvent.territoryConquered);
    }
  }

  void _skipToEnd() {
    if (_stage == _BattleStage.done) return;
    _revealTimer?.cancel();
    _doneTimer?.cancel();
    _spinController.stop();
    _finish();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.85),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(ReinosSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Combatants(
                    attackerName: widget.attackerName,
                    defenderName: widget.defenderName,
                    attackerColor: widget.attackerColor,
                    defenderColor: widget.defenderColor,
                    territoryName: widget.territoryName,
                  ),
                  const SizedBox(height: ReinosSpacing.lg),
                  if (_stage == _BattleStage.rolling)
                    RotationTransition(
                      turns: _spinController,
                      child: const Icon(Icons.casino, size: 56, color: ReinosColors.gold),
                    )
                  else
                    _DiceComparison(roll: widget.roll),
                  const SizedBox(height: ReinosSpacing.lg),
                  if (_stage == _BattleStage.done) _ResultSummary(roll: widget.roll),
                  if (_stage == _BattleStage.done && widget.conquered) ...[
                    const SizedBox(height: ReinosSpacing.md),
                    _ConquestBanner(territoryName: widget.territoryName),
                  ],
                  const SizedBox(height: ReinosSpacing.lg),
                  if (_stage != _BattleStage.done)
                    TextButton(onPressed: _skipToEnd, child: const Text('Pular'))
                  else
                    FilledButton(onPressed: widget.onDismiss, child: const Text('CONTINUAR')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Combatants extends StatelessWidget {
  final String attackerName;
  final String defenderName;
  final Color attackerColor;
  final Color defenderColor;
  final String territoryName;

  const _Combatants({
    required this.attackerName,
    required this.defenderName,
    required this.attackerColor,
    required this.defenderColor,
    required this.territoryName,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(territoryName, style: ReinosTypography.heading),
        const SizedBox(height: ReinosSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _PlayerChip(name: attackerName, color: attackerColor),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: ReinosSpacing.sm),
              child: Icon(Icons.swap_horiz, color: ReinosColors.parchment),
            ),
            _PlayerChip(name: defenderName, color: defenderColor),
          ],
        ),
      ],
    );
  }
}

class _PlayerChip extends StatelessWidget {
  final String name;
  final Color color;

  const _PlayerChip({required this.name, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: ReinosSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(ReinosRadius.sm),
      ),
      child: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }
}

class _DiceComparison extends StatelessWidget {
  final DiceRollResult roll;

  const _DiceComparison({required this.roll});

  @override
  Widget build(BuildContext context) {
    final comparisons =
        roll.attackerDice.length < roll.defenderDice.length ? roll.attackerDice.length : roll.defenderDice.length;

    return Column(
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: ReinosSpacing.sm,
          children: [
            for (var i = 0; i < roll.attackerDice.length; i++)
              _DiceFace(
                value: roll.attackerDice[i],
                highlight: i < comparisons
                    ? (roll.attackerDice[i] > roll.defenderDice[i] ? ReinosColors.success : ReinosColors.danger)
                    : null,
              ),
          ],
        ),
        const SizedBox(height: ReinosSpacing.sm),
        const Icon(Icons.keyboard_double_arrow_down, color: ReinosColors.parchment),
        const SizedBox(height: ReinosSpacing.sm),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: ReinosSpacing.sm,
          children: [
            for (var i = 0; i < roll.defenderDice.length; i++)
              _DiceFace(
                value: roll.defenderDice[i],
                highlight: i < comparisons
                    ? (roll.defenderDice[i] >= roll.attackerDice[i] ? ReinosColors.success : ReinosColors.danger)
                    : null,
              ),
          ],
        ),
      ],
    );
  }
}

class _DiceFace extends StatelessWidget {
  final int value;
  final Color? highlight;

  const _DiceFace({required this.value, this.highlight});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: ReinosColors.parchment,
        borderRadius: BorderRadius.circular(ReinosRadius.sm),
        border: Border.all(color: highlight ?? ReinosColors.bronze, width: highlight != null ? 2.5 : 1),
      ),
      child: Text('$value', style: const TextStyle(color: ReinosColors.background, fontWeight: FontWeight.bold)),
    );
  }
}

class _ResultSummary extends StatelessWidget {
  final DiceRollResult roll;

  const _ResultSummary({required this.roll});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Atacante perdeu ${roll.attackerLosses} exército(s)', style: ReinosTypography.body),
        Text('Defensor perdeu ${roll.defenderLosses} exército(s)', style: ReinosTypography.body),
      ],
    );
  }
}

class _ConquestBanner extends StatelessWidget {
  final String territoryName;

  const _ConquestBanner({required this.territoryName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: ReinosSpacing.md, vertical: ReinosSpacing.sm),
      decoration: BoxDecoration(
        color: ReinosColors.gold.withValues(alpha: 0.15),
        border: Border.all(color: ReinosColors.gold, width: 2),
        borderRadius: BorderRadius.circular(ReinosRadius.md),
      ),
      child: Column(
        children: [
          const Text('🏴 TERRITÓRIO CONQUISTADO', style: TextStyle(color: ReinosColors.gold, fontWeight: FontWeight.bold)),
          Text(territoryName.toUpperCase(), style: ReinosTypography.heading),
        ],
      ),
    );
  }
}
