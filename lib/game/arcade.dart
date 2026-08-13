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
    this.speedRamp = 0.005,
    this.maxSpeed = 0.35,
    this.gapHalf = 0.13,
    this.gapBottom = 0.16,
    this.gapTop = 0.84,
    this.spacing = 0.5,
    this.birdRadius = 0.032,
    this.controlSmoothing = 4.0,
    this.invulnerabilitySeconds = 1.0,
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
    _spawnedCount = 0;
    birdVelocity = 0;
    lastPassAt = -100;
    hitAt = -100;
    gameOverAt = 0;
    obstacles.clear();
  }

  final ArcadeConfig _config;
  final math.Random _random;

  /// Sensibilidad del control [0..100] (default 50). La define el jugador.
  double _sensitivity = 50;

  int _spawnedCount = 0;

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

  /// Variación de altitud por segundo (signado, para inclinación/squash).
  double birdVelocity = 0;

  /// Momento del último pilar superado (para el pop del marcador).
  double lastPassAt = -100;

  /// Momento del último golpe (para shake, flash y cara de daño).
  double hitAt = -100;

  /// Momento en que empezó el game over (para la animación de muerte).
  double gameOverAt = 0;

  final List<ArcadeObstacle> obstacles = [];

  bool get invulnerable => !gameOver && elapsed < _invulnUntil;

  double get birdX => 0.3;

  double get speed => _speed;

  double get birdRadius => _config.birdRadius;

  int get sensitivity => _sensitivity.round();

  /// Ganancia del control: cuánto recorre el pájaro por el mismo recorrido
  /// de brazos. Sensibilidad baja (50 → 1.0, 0 → 0.5) mueve menos.
  double get gain => 0.5 + (_sensitivity / 100.0);

  /// Constante de suavizado: baja sens = más suave, alta = más directa.
  double get controlSmoothing => 4.0 + (_sensitivity / 100.0) * 4.0;

  void setSensitivity(int sensitivity) {
    _sensitivity = sensitivity.clamp(0, 100).toDouble();
  }

  /// Profundidad ya filtrada y calibrada [0..1] (para el gauge).
  double _filteredDepth = 0.5;

  /// Profundidad suavizada visible (para el gauge de calibración).
  double get filteredDepth => _filteredDepth;

  // Filtro de entrada: elimina el jitter de la pose.
  static const double _inputFilterK = 0.5;
  static const double _depthDeadband = 0.02;

  // Calibración al rango real de profundidad del jugador.
  bool _calibrating = false;
  double _calMin = 1;
  double _calMax = 0;
  double _calLo = 0;
  double _calHi = 1;
  bool _calibrated = false;

  /// Arranca la calibración (llamar al inicio del countdown).
  void startCalibration() {
    _calibrating = true;
    _calibrated = false;
    _calMin = 1;
    _calMax = 0;
    _filteredDepth = 0.5;
  }

  /// Alimenta la profundidad cruda durante la calibración.
  void feedCalibration(double depthRatio) {
    if (!_calibrating) return;
    final c = depthRatio.clamp(0.0, 1.0);
    _calMin = math.min(_calMin, c);
    _calMax = math.max(_calMax, c);
  }

  /// Termina la calibración: fija el rango capturado al espacio de control.
  void endCalibration() {
    _calibrating = false;
    var lo = _calMin;
    var hi = _calMax;
    // Rango insuficiente (apenas se movió): caer al rango completo.
    if (hi - lo < 0.15) {
      lo = 0;
      hi = 1;
    }
    _calLo = lo;
    _calHi = hi;
    _calibrated = true;
  }

  double _normalizedDepth(double raw) {
    final r = raw.clamp(0.0, 1.0);
    if (!_calibrated) return r;
    return ((r - _calLo) / (_calHi - _calLo)).clamp(0.0, 1.0);
  }

  /// Alimenta la profundidad cruda de la pose: normaliza con la calibración,
  /// ignora cambios mínimos (deadband) y suaviza el resto.
  void feedDepth(double depthRatio) {
    if (_calibrating || gameOver) return;
    final n = _normalizedDepth(depthRatio);
    if ((n - _filteredDepth).abs() < _depthDeadband) return;
    _filteredDepth += (n - _filteredDepth) * _inputFilterK;
  }

  /// Objetivo actual del pájaro a partir de la profundidad filtrada.
  double get targetAltitude => targetForDepth(_filteredDepth);

  /// Altitud objetivo a partir de la profundidad del push-up:
  /// brazos extendidos (0) = arriba, flexionados (1) = abajo.
  ///
  /// Aplica zonas muertas amplias en los extremos (el ruido de pose no
  /// tiembla el pájaro) y la ganancia de sensibilidad.
  double targetForDepth(double depthRatio) {
    final clamped = depthRatio.clamp(0.0, 1.0);
    const deadTop = 0.14;
    const deadBottom = 0.86;
    const minAlt = 0.10;
    const maxAlt = 0.90;
    final d = ((clamped - 0.5) * gain + 0.5).clamp(0.0, 1.0);
    if (d <= deadTop) return minAlt;
    if (d >= deadBottom) return maxAlt;
    final t = (d - deadTop) / (deadBottom - deadTop);
    return minAlt + t * (maxAlt - minAlt);
  }

  void reset() {
    _applyStart();
  }

  /// Avanza solo el reloj visual (animación de muerte, cielo, nubes)
  /// después del game over, cuando `update()` ya no simula.
  void tick(double dt) {
    elapsed += dt;
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
    final previous = altitude;
    final t = 1 - math.exp(-controlSmoothing * dt);
    altitude += (_target - altitude) * t;
    birdVelocity = dt > 0 ? (altitude - previous) / dt : 0;

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
        lastPassAt = elapsed;
        event = ArcadeEvent.passed;
      }
    }

    if (!invulnerable && _hitsObstacle()) {
      lives -= 1;
      hitAt = elapsed;
      _invulnUntil = elapsed + _config.invulnerabilitySeconds;
      if (lives <= 0) {
        gameOver = true;
        gameOverAt = elapsed;
        return ArcadeEvent.hit;
      }
      event = ArcadeEvent.hit;
    }

    return event;
  }

  void _spawnObstacle() {
    final gapHalf = _effectiveGap();
    final center = _gapCenter(gapHalf);
    _spawnedCount += 1;
    obstacles.add(
      ArcadeObstacle(
        x: 1.05,
        gapCenter: center,
        gapHalf: gapHalf,
      ),
    );
  }

  /// El hueco se encoge suavemente con el puntaje (dificultad progresiva)
  /// y los primeros pilares son un poco más anchos (calentamiento).
  double _effectiveGap() {
    var gap = _config.gapHalf;
    final progress = (score / 15.0).clamp(0.0, 1.0);
    gap *= 1.0 - 0.3 * progress;
    if (_spawnedCount < 3) gap *= 1.15;
    return gap;
  }

  double _gapCenter(double gapHalf) {
    final margin = _config.gapBottom + gapHalf;
    final max = _config.gapTop - gapHalf;
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
