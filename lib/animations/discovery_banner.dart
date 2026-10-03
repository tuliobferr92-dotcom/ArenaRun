import 'package:flutter/material.dart';

import '../content/domain/bible_challenge.dart';
import '../ui/design_system/tokens.dart';
import 'bible_challenge_dialog.dart';

/// "Aprendizado invisível" (section 30): never a quiz disguised as a game
/// — a quiet discovery moment the player can act on or skip. Shown once,
/// right after a territory is conquered for the first time this match.
/// If there's no challenge for this territory yet (seed content is still
/// small), it just celebrates the discovery with no quiz offered at all.
class DiscoveryBanner extends StatelessWidget {
  final String territoryName;
  final List<String> biblicalReferences;
  final BibleChallenge? challenge;
  final void Function(String challengeId, bool correct) onAnswered;
  final VoidCallback onDismiss;

  const DiscoveryBanner({
    super.key,
    required this.territoryName,
    required this.biblicalReferences,
    required this.challenge,
    required this.onAnswered,
    required this.onDismiss,
  });

  void _openChallenge(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BibleChallengeDialog(
        challenge: challenge!,
        onAnswered: onAnswered,
      ),
    ).then((_) => onDismiss());
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.6),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(ReinosSpacing.lg),
          padding: const EdgeInsets.all(ReinosSpacing.lg),
          decoration: BoxDecoration(
            color: ReinosColors.surface,
            border: Border.all(color: ReinosColors.bronze, width: 2),
            borderRadius: BorderRadius.circular(ReinosRadius.lg),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('📖 DESCOBERTA',
                  style: TextStyle(color: ReinosColors.gold, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: ReinosSpacing.sm),
              Text(territoryName.toUpperCase(), style: ReinosTypography.title),
              if (biblicalReferences.isNotEmpty) ...[
                const SizedBox(height: ReinosSpacing.sm),
                Text(biblicalReferences.join(', '), style: ReinosTypography.body),
              ],
              const SizedBox(height: ReinosSpacing.sm),
              Text(
                'Você desbloqueou um novo lugar da história bíblica.',
                style: ReinosTypography.label,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: ReinosSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(onPressed: onDismiss, child: const Text('CONTINUAR JOGANDO')),
                  if (challenge != null) ...[
                    const SizedBox(width: ReinosSpacing.sm),
                    FilledButton(
                      onPressed: () => _openChallenge(context),
                      child: const Text('VER AGORA'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
