import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'state/game_state.dart';
import 'theme/app_theme.dart';
import 'widgets/haptics.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = await GameState.load();
  Haptics.enabled = state.hapticsEnabled;
  runApp(PushQuestApp(state: state));
}

class PushQuestApp extends StatelessWidget {
  const PushQuestApp({super.key, required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PushQuest',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: state.hasSeenOnboarding
          ? HomeScreen(state: state)
          : OnboardingScreen(state: state),
    );
  }
}
