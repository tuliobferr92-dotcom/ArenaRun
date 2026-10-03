import 'package:flutter/material.dart';

import '../design_system/tokens.dart';

/// Hides the board between human players sharing one device (section 56).
/// Shown whenever the turn passes to a different human player who hasn't
/// yet confirmed they're looking — bots never trigger this, since there's
/// no one at the device to hide information from during their turn.
class PassDeviceScreen extends StatelessWidget {
  final String playerName;
  final VoidCallback onReady;

  const PassDeviceScreen({super.key, required this.playerName, required this.onReady});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ReinosColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(ReinosSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.phonelink_lock, size: 56, color: ReinosColors.gold),
              const SizedBox(height: ReinosSpacing.lg),
              Text('PASSE O DISPOSITIVO PARA', style: ReinosTypography.subtitle, textAlign: TextAlign.center),
              const SizedBox(height: ReinosSpacing.sm),
              Text(playerName.toUpperCase(), style: ReinosTypography.title, textAlign: TextAlign.center),
              const SizedBox(height: ReinosSpacing.xl),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: ReinosColors.gold,
                  foregroundColor: ReinosColors.background,
                  padding: const EdgeInsets.symmetric(
                    horizontal: ReinosSpacing.xl,
                    vertical: ReinosSpacing.md,
                  ),
                ),
                onPressed: onReady,
                child: const Text('ESTOU PRONTO'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
