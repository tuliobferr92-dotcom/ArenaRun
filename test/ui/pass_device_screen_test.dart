import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reinos/ui/widgets/pass_device_screen.dart';

void main() {
  testWidgets('shows the player name and calls onReady when tapped', (tester) async {
    var ready = false;
    await tester.pumpWidget(
      MaterialApp(
        home: PassDeviceScreen(
          playerName: 'Jogador 2',
          onReady: () => ready = true,
        ),
      ),
    );

    expect(find.text('JOGADOR 2'), findsOneWidget);

    await tester.tap(find.text('ESTOU PRONTO'));
    await tester.pump();

    expect(ready, isTrue);
  });
}
