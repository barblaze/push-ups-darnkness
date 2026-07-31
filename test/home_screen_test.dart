import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pushquest/main.dart';
import 'package:pushquest/state/game_state.dart';
import 'package:pushquest/theme/app_theme.dart';

import 'helpers.dart';

void main() {
  testWidgets('home renders avatar, mission and entrenar button', (
    tester,
  ) async {
    final state = await GameState.load(storage: MemoryGameStorage());
    await tester.pumpWidget(PushQuestApp(state: state));
    await tester.pumpAndSettle();

    expect(find.text('PushQuest'), findsOneWidget);
    expect(find.text('ENTRENAR'), findsOneWidget);
    expect(find.textContaining('Nivel 1'), findsWidgets);
    expect(find.text('Desafíos'), findsOneWidget);
    expect(find.text('Estadísticas'), findsOneWidget);
  });

  testWidgets('can navigate to challenges screen', (tester) async {
    final state = await GameState.load(storage: MemoryGameStorage());
    await tester.pumpWidget(PushQuestApp(state: state));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Desafíos'));
    await tester.pumpAndSettle();

    expect(find.text('Misión del día'), findsOneWidget);
    expect(find.text('Logros'), findsOneWidget);
    expect(find.text('Primera sesión'), findsOneWidget);
  });

  testWidgets('theme colors are defined', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: buildAppTheme(), home: const Scaffold()),
    );
    expect(AppColors.primary, const Color(0xFFFF6B35));
  });
}
