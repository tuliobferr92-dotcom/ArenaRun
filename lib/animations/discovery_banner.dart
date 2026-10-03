import 'package:flutter/material.dart';

import '../content/domain/bible_challenge.dart';
import '../services/audio_service.dart';
import '../ui/design_system/tokens.dart';
import 'bible_challenge_dialog.dart';

/// "Aprendizado invisível" (section 30): never a quiz disguised as a game
/// — a quiet discovery moment the player can act on or skip. Shown once,
/// right after a territory is conquered for the first time this match.
/// If there's no challenge for this territory yet (seed content is still
/// small), it just celebrates the discovery with no quiz offered at all.
class DiscoveryBanner extends StatefulWidget {
  final String territoryName;
  final List<String> biblicalReferences;
  final BibleChallenge? challenge;
  final AudioService audio;
  final void Function(String challengeId, bool correct) onAnswered;
  final VoidCallback onDismiss;

  const DiscoveryBanner({
    super.key,
    required this.territoryName,
    required this.biblicalReferences,
    required this.challenge,
    required this.audio,
    required this.onAnswered,
    required this.onDismiss,
  });

  @override
  State<DiscoveryBanner> createState() => _DiscoveryBannerState();
}

class _DiscoveryBannerState extends State<DiscoveryBanner> {
  @override
  void initState() {
    super.initState();
    widget.audio.play(SoundEvent.bibleDiscovery);
  }

  void _openChallenge(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BibleChallengeDialog(
        challenge: widget.challenge!,
        onAnswered: widget.onAnswered,
      ),
    ).then((_) => widget.onDismiss());
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
              Text(widget.territoryName.toUpperCase(), style: ReinosTypography.title),
              if (widget.biblicalReferences.isNotEmpty) ...[
                const SizedBox(height: ReinosSpacing.sm),
                Text(widget.biblicalReferences.join(', '), style: ReinosTypography.body),
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
                  TextButton(onPressed: widget.onDismiss, child: const Text('CONTINUAR JOGANDO')),
                  if (widget.challenge != null) ...[
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
