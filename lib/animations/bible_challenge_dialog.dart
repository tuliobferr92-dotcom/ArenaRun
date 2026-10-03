import 'package:flutter/material.dart';

import '../content/domain/bible_challenge.dart';
import '../content/engine/bible_challenge_engine.dart';
import '../ui/design_system/tokens.dart';

/// A single optional multiple-choice question (section 22). Never forced —
/// only reachable from [DiscoveryBanner]'s "VER AGORA" button. Shows the
/// explanation either way once answered, then lets the player close it.
class BibleChallengeDialog extends StatefulWidget {
  final BibleChallenge challenge;
  final void Function(String challengeId, bool correct) onAnswered;

  const BibleChallengeDialog({
    super.key,
    required this.challenge,
    required this.onAnswered,
  });

  @override
  State<BibleChallengeDialog> createState() => _BibleChallengeDialogState();
}

class _BibleChallengeDialogState extends State<BibleChallengeDialog> {
  int? _chosenIndex;

  void _choose(int index) {
    if (_chosenIndex != null) return;
    setState(() => _chosenIndex = index);
    widget.onAnswered(widget.challenge.id, BibleChallengeEngine.isCorrect(widget.challenge, index));
  }

  @override
  Widget build(BuildContext context) {
    final challenge = widget.challenge;
    final answered = _chosenIndex != null;

    return AlertDialog(
      backgroundColor: ReinosColors.surface,
      title: Text(challenge.question, style: ReinosTypography.heading),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < challenge.options.length; i++)
            _OptionTile(
              label: challenge.options[i],
              state: !answered
                  ? _OptionState.neutral
                  : i == challenge.correctOptionIndex
                      ? _OptionState.correct
                      : i == _chosenIndex
                          ? _OptionState.wrong
                          : _OptionState.neutral,
              onTap: () => _choose(i),
            ),
          if (answered) ...[
            const SizedBox(height: ReinosSpacing.md),
            Text(challenge.explanation, style: ReinosTypography.body),
            const SizedBox(height: ReinosSpacing.sm),
            Text('📖 ${challenge.biblicalReferences.join(', ')}', style: ReinosTypography.label),
          ],
        ],
      ),
      actions: [
        if (answered)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fechar'),
          ),
      ],
    );
  }
}

enum _OptionState { neutral, correct, wrong }

class _OptionTile extends StatelessWidget {
  final String label;
  final _OptionState state;
  final VoidCallback onTap;

  const _OptionTile({required this.label, required this.state, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      _OptionState.correct => ReinosColors.success,
      _OptionState.wrong => ReinosColors.danger,
      _OptionState.neutral => ReinosColors.bronze,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: ReinosColors.parchment,
          side: BorderSide(color: color, width: state == _OptionState.neutral ? 1 : 2),
          alignment: Alignment.centerLeft,
        ),
        child: SizedBox(width: double.infinity, child: Text(label)),
      ),
    );
  }
}
