import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reinos/animations/regional_dominance_banner.dart';
import 'package:reinos/services/audio_service.dart';

void main() {
  testWidgets('shows the region name and reinforcement bonus', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RegionalDominanceBanner(
          regionName: 'Canaã',
          reinforcementBonus: 3,
          audio: NoOpAudioService(),
          onDismiss: _noop,
        ),
      ),
    );

    expect(find.text('CANAÃ'), findsOneWidget);
    expect(find.text('+3 reforços por rodada'), findsOneWidget);

    // Drain the auto-dismiss timer so no Timer is left pending at teardown.
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('tapping anywhere dismisses it immediately', (tester) async {
    var dismissed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: RegionalDominanceBanner(
          regionName: 'Canaã',
          reinforcementBonus: 3,
          audio: NoOpAudioService(),
          onDismiss: () => dismissed = true,
        ),
      ),
    );

    await tester.tap(find.text('CANAÃ'));
    await tester.pump();

    expect(dismissed, isTrue);
  });
}

void _noop() {}
