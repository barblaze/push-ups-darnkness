import 'dart:math' as math;

enum ArcadeEvent { none, passed, hit }

class ArcadeObstacle {
  ArcadeObstacle({
    required this.x,
    required this.gapCenter,
    required this.gapHalf,
  });

  /// Posición horizontal en el ancho normalizado [0..1] (0 = borde izquierdo).
  double x;

  /// Centro del hueco, altura normalizada [0..1] (0 = arriba).
  final double gapCenter;

  /// Mitad del hueco en fracción de altura.
  final double gapHalf;

  bool counted = false;
}

class ArcadeConfig {
  const ArcadeConfig({
    this.scrollSpeed = 0.22,
    this.speedRamp = 0.006,
    this.maxSpeed = 0.34,
    this.gapHalf = 0.13,
    this.gapBottom = 0.16,
    this.gapTop = 0.84,
    this.spacing = 0.5,
    this.birdRadius = 0.032,
    this.controlSmoothing = 4.0,
    this.invulnerabilitySeconds = 1.2,
    this.startLives = 3,
    this.firstSpawnDelay = 1.2,
  });

  final double scrollSpeed;
  final double speedRamp;
  final double maxSpeed;
  final double gapHalf;
  final double gapBottom;
  final double gapTop;
  final double spacing;
  final double birdRadius;
  final double controlSmoothing;
  final double invulnerabilitySeconds;
  final int startLives;
  final double firstSpawnDelay;
}

class ArcadeGame {
  ArcadeGame({ArcadeConfig? config, math.Random? random})
      : _config = config ?? const ArcadeConfig(),
        _random = random ?? math.Random() {
    _applyStart();
  }

  void _applyStart() {
    altitude = 0.5;
    _target = 0.5;
    _lastTarget = 0.5;
    score = 0;
    lives = _config.startLives;
    elapsed = 0;
    gameOver = false;
    _invulnUntil = 0;
    _speed = _config.scrollSpeed;
    _distance = -_config.firstSpawnDelay;
    obstacles.clear();
  }

  final ArcadeConfig _config;
  final math.Random _random;

  /// Altitud del pájaro [0..1] (0 = arriba).
  double altitude = 0.5;

  double _target = 0.5;

  int score = 0;
  int lives = 3;
  double elapsed = 0;
  bool gameOver = false;

  double _speed = 0.22;
  double _distance = 0;
  double _lastTarget = 0.5;
  double _invulnUntil = 0;

  final List<ArcadeObstacle> obstacles = [];

  bool get invulnerable => !gameOver && elapsed < _invulnUntil;

  double get birdX => 0.3;

  double get speed => _speed;

  double get birdRadius => _config.birdRadius;

  /// Altitud objetivo a partir de la profundidad del push-up:
  /// brazos extendidos (0) = arriba, flexionados (1) = abajo.
  double targetForDepth(double depthRatio) {
    final clamped = depthRatio.clamp(0.0, 1.0);
    return 0.06 + clamped * 0.88;
  }

  void reset() {
    _applyStart();
  }

  /// Avanza la simulación.
  ///
  /// [targetAltitude] es la altura a la que debe ir el pájaro (control
  /// continuo). Si [bodyVisible] es falso, el pájaro mantiene su objetivo
  /// anterior (fuera de cámara no se controla).
  ArcadeEvent update(
    double dt, {
    required double targetAltitude,
    required bool bodyVisible,
  }) {
    if (gameOver) return ArcadeEvent.none;

    elapsed += dt;

    if (bodyVisible) {
      _lastTarget = targetAltitude.clamp(0.06, 0.94);
    }
    _target = _lastTarget;
    final t = 1 - math.exp(-_config.controlSmoothing * dt);
    altitude += (_target - altitude) * t;

    _speed = math.min(
      _config.scrollSpeed + score * _config.speedRamp,
      math.max(_config.maxSpeed, _config.scrollSpeed),
    );

    _distance += _speed * dt;
    for (final obstacle in obstacles) {
      obstacle.x -= _speed * dt;
    }
    obstacles.removeWhere((o) => o.x < -0.2);
    if (_distance >= _config.spacing) {
      _distance = 0;
      _spawnObstacle();
    }

    var event = ArcadeEvent.none;
    for (final obstacle in obstacles) {
      if (!obstacle.counted && obstacle.x + 0.02 < birdX) {
        obstacle.counted = true;
        score += 1;
        event = ArcadeEvent.passed;
      }
    }

    if (!invulnerable && _hitsObstacle()) {
      lives -= 1;
      _invulnUntil = elapsed + _config.invulnerabilitySeconds;
      if (lives <= 0) {
        gameOver = true;
        return ArcadeEvent.hit;
      }
      event = ArcadeEvent.hit;
    }

    return event;
  }

  void _spawnObstacle() {
    final center = _gapCenter();
    obstacles.add(
      ArcadeObstacle(
        x: 1.05,
        gapCenter: center,
        gapHalf: _config.gapHalf,
      ),
    );
  }

  double _gapCenter() {
    final margin = _config.gapBottom + _config.gapHalf;
    final max = _config.gapTop - _config.gapHalf;
    final range = math.max(0.01, max - margin);
    final previous = obstacles.isEmpty ? 0.5 : obstacles.last.gapCenter;
    final next = margin + _random.nextDouble() * range;
    // Evita saltos imposibles entre pilares consecutivos.
    final maxStep = 0.3;
    if ((next - previous).abs() > maxStep) {
      return previous > next ? previous - maxStep : previous + maxStep;
    }
    return next;
  }

  bool _hitsObstacle() {
    final half = _config.birdRadius;
    for (final obstacle in obstacles) {
      if ((obstacle.x - birdX).abs() < 0.05 + half) {
        if ((altitude - obstacle.gapCenter).abs() > obstacle.gapHalf - half) {
          return true;
        }
      }
    }
    return false;
  }
}
