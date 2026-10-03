import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reinos/animations/battle_sequence_overlay.dart';
import 'package:reinos/game_engine/state/battle_state.dart';
import 'package:reinos/services/audio_service.dart';

class _RecordingAudioService implements AudioService {
  final List<SoundEvent> played = [];
  @override
  void play(SoundEvent event) => played.add(event);
}

Future<void> _pumpOverlay(
  WidgetTester tester, {
  required DiceRollResult roll,
  required bool conquered,
  required VoidCallback onDismiss,
  AudioService? audio,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: BattleSequenceOverlay(
        attackerName: 'Você',
        defenderName: 'Bot 1',
        attackerColor: Colors.blue,
        defenderColor: Colors.red,
        roll: roll,
        conquered: conquered,
        territoryName: 'Jericó',
        audio: audio ?? _RecordingAudioService(),
        onDismiss: onDismiss,
      ),
    ),
  );
}

void main() {
  const winningRoll = DiceRollResult(
    attackerDice: [6, 5, 4],
    defenderDice: [3, 2],
    attackerLosses: 0,
    defenderLosses: 2,
    territoryConquered: true,
  );

  testWidgets('shows a spinning dice icon first, then reveals dice values', (tester) async {
    await _pumpOverlay(tester, roll: winningRoll, conquered: true, onDismiss: () {});

    expect(find.byIcon(Icons.casino), findsOneWidget);
    expect(find.text('6'), findsNothing); // not revealed yet

    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('6'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);

    // Drain the remaining scheduled timer so no Timer is left pending
    // when the test tears down.
    await tester.pump(const Duration(milliseconds: 900));
  });

  testWidgets('shows the conquest banner and a CONTINUAR button once the sequence finishes',
      (tester) async {
    await _pumpOverlay(tester, roll: winningRoll, conquered: true, onDismiss: () {});

    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.textContaining('TERRITÓRIO CONQUISTADO'), findsOneWidget);
    expect(find.text('CONTINUAR'), findsOneWidget);
  });

  testWidgets('does not show a conquest banner when the territory was not conquered',
      (tester) async {
    const nonConquest = DiceRollResult(
      attackerDice: [4, 3],
      defenderDice: [5, 2],
      attackerLosses: 1,
      defenderLosses: 1,
      territoryConquered: false,
    );
    await _pumpOverlay(tester, roll: nonConquest, conquered: false, onDismiss: () {});

    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.textContaining('TERRITÓRIO CONQUISTADO'), findsNothing);
    expect(find.text('CONTINUAR'), findsOneWidget);
  });

  testWidgets('tapping "Pular" skips straight to the result', (tester) async {
    await _pumpOverlay(tester, roll: winningRoll, conquered: true, onDismiss: () {});

    await tester.tap(find.text('Pular'));
    await tester.pump();

    expect(find.text('CONTINUAR'), findsOneWidget);
  });

  testWidgets('tapping CONTINUAR invokes onDismiss', (tester) async {
    var dismissed = false;
    await _pumpOverlay(
      tester,
      roll: winningRoll,
      conquered: true,
      onDismiss: () => dismissed = true,
    );

    await tester.tap(find.text('Pular'));
    await tester.pump();
    await tester.tap(find.text('CONTINUAR'));
    await tester.pump();

    expect(dismissed, isTrue);
  });

  testWidgets('plays dice-roll, impact, and conquest sound events in order', (tester) async {
    final audio = _RecordingAudioService();
    await _pumpOverlay(tester, roll: winningRoll, conquered: true, onDismiss: () {}, audio: audio);

    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 900));

    expect(audio.played, [
      SoundEvent.diceRoll,
      SoundEvent.battleImpact,
      SoundEvent.territoryConquered,
    ]);
  });
}
