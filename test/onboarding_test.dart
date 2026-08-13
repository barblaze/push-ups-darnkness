import 'package:flutter_test/flutter_test.dart';
import 'package:pushquest/main.dart';
import 'package:pushquest/state/game_state.dart';

import 'helpers.dart';

void main() {
  testWidgets('first run shows onboarding instead of home', (tester) async {
    final state = await GameState.load(storage: MemoryGameStorage());
    await tester.pumpWidget(PushQuestApp(state: state));
    await tester.pumpAndSettle();

    expect(find.text('Bienvenido a PushQuest'), findsOneWidget);
    expect(find.text('ENTRENAR'), findsNothing);
  });

  testWidgets('finishing onboarding opens home and persists flag', (
    tester,
  ) async {
    final storage = MemoryGameStorage();
    final state = await GameState.load(storage: storage);
    await tester.pumpWidget(PushQuestApp(state: state));
    await tester.pumpAndSettle();

    await tester.tap(find.text('SIGUIENTE'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SIGUIENTE'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('EMPEZAR'));
    await tester.pumpAndSettle();

    expect(find.text('ENTRENAR'), findsOneWidget);
    expect(storage.data.hasSeenOnboarding, isTrue);
  });

  testWidgets('skip also opens home', (tester) async {
    final state = await GameState.load(storage: MemoryGameStorage());
    await tester.pumpWidget(PushQuestApp(state: state));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Omitir'));
    await tester.pumpAndSettle();

    expect(find.text('ENTRENAR'), findsOneWidget);
  });
}
