import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ui/design_system/tokens.dart';

/// One-shot celebration shown when a player completes control of an entire
/// region (section 17). Auto-dismisses after a few seconds, or on tap —
/// never blocks the game if the player doesn't interact with it.
class RegionalDominanceBanner extends StatefulWidget {
  final String regionName;
  final int reinforcementBonus;
  final VoidCallback onDismiss;

  const RegionalDominanceBanner({
    super.key,
    required this.regionName,
    required this.reinforcementBonus,
    required this.onDismiss,
  });

  @override
  State<RegionalDominanceBanner> createState() => _RegionalDominanceBannerState();
}

class _RegionalDominanceBannerState extends State<RegionalDominanceBanner> {
  Timer? _autoDismissTimer;

  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();
    _autoDismissTimer = Timer(const Duration(seconds: 3), widget.onDismiss);
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.6),
      child: GestureDetector(
        onTap: () {
          _autoDismissTimer?.cancel();
          widget.onDismiss();
        },
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: ReinosSpacing.xl,
              vertical: ReinosSpacing.lg,
            ),
            decoration: BoxDecoration(
              color: ReinosColors.surface,
              border: Border.all(color: ReinosColors.gold, width: 2),
              borderRadius: BorderRadius.circular(ReinosRadius.lg),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('👑 DOMÍNIO REGIONAL',
                    style: TextStyle(color: ReinosColors.gold, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: ReinosSpacing.sm),
                Text(widget.regionName.toUpperCase(), style: ReinosTypography.title),
                const SizedBox(height: ReinosSpacing.sm),
                Text('+${widget.reinforcementBonus} reforços por rodada',
                    style: ReinosTypography.body),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
