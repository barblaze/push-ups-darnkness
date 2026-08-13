import 'package:flutter/material.dart';

import '../state/game_state.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.state});

  final GameState state;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  static const _pages = [
    _OnboardingPageData(
      emoji: '🥚',
      title: 'Bienvenido a PushQuest',
      subtitle:
          'Tu cámara detecta tu cuerpo en tiempo real para contar push-ups '
          'automáticamente. Sin tocadores ni botones durante la serie.',
      accent: AppColors.primary,
    ),
    _OnboardingPageData(
      emoji: '🤳',
      title: 'Cámara de frente',
      subtitle:
          'Coloca el celular vertical y de frente a ti, apoyado y con todo tu '
          'cuerpo en cuadro. Usa "Calibrar" para ajustar el conteo a tu rango.',
      accent: AppColors.accent,
    ),
    _OnboardingPageData(
      emoji: '🎯',
      title: 'Misiones, XP y logros',
      subtitle:
          'Completa la misión diaria, encadena combos, sube de nivel y '
          'desbloquea logros mientras tu avatar evoluciona.',
      accent: AppColors.warning,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await widget.state.markOnboardingSeen();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => HomeScreen(state: widget.state)),
    );
  }

  void _next() {
    if (_page >= _pages.length - 1) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _finish,
                child: const Text('Omitir'),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (index) => setState(() => _page = index),
                itemBuilder: (context, index) => _OnboardingPage(
                  data: _pages[index],
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _pages.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _page ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _page
                          ? AppColors.primary
                          : AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: FilledButton(
                onPressed: _next,
                child: Text(_page >= _pages.length - 1
                    ? 'EMPEZAR'
                    : 'SIGUIENTE'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPageData {
  const _OnboardingPageData({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.accent,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final Color accent;
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.data});

  final _OnboardingPageData data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 160,
            width: 160,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: data.accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: data.accent.withValues(alpha: 0.4)),
            ),
            child: Text(data.emoji, style: const TextStyle(fontSize: 72)),
          ),
          const SizedBox(height: 32),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            data.subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
