import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reinos/main.dart';

void main() {
  testWidgets('Home screen shows the REINOS title and a JOGAR button',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: ReinosApp()));

    expect(find.text('REINOS'), findsOneWidget);
    expect(find.text('JOGAR'), findsOneWidget);
  });
}
