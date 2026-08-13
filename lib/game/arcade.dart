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
    this.controlRate = 25.0,
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

  /// Velocidad con la que el pájaro alcanza su objetivo (mayor = más directo).
  final double controlRate;

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
    _resetCalibration();
  }

  final ArcadeConfig _config;
  final math.Random _random;

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

  /// Profundidad ya filtrada y mapeada al rango real [0..1] (para el gauge).
  double _filteredDepth = 0.5;
  bool _filteredInit = false;

  /// Profundidad suavizada visible (para el gauge de calibración).
  double get filteredDepth => _filteredDepth;

  /// Peso del frame actual en la señal filtrada (0..1; 1 = sin suavizado).
  /// Bajo para quitar el jitter de la pose, pero lo bastante alto para que el
  /// pájaro siga al cuerpo casi en tiempo real.
  static const double _inputFilterK = 0.35;

  // Rango de referencia del dropRatio en vista frontal (brazos estirados ≈
  // arriba, pecho al suelo ≈ abajo). Solo se expande hacia los extremos que el
  // jugador alcanza y nunca se encoge: el control es estable, 1:1, y no deriva
  // al mantener la postura (la calibración adaptativa anterior se re-centraba
  // sola y hacía el juego injugable).
  static const double _rangeMin = 0.35;
  static const double _rangeMax = 0.85;
  static const double _expandRate = 0.5;

  /// Altura normalizada del pájaro en sus extremos (0 = arriba).
  static const double _minAlt = 0.10;
  static const double _maxAlt = 0.90;

  double _calMin = _rangeMin;
  double _calMax = _rangeMax;

  void _resetCalibration() {
    _calMin = _rangeMin;
    _calMax = _rangeMax;
    _filteredDepth = 0.5;
    _filteredInit = false;
  }

  /// Alimenta el dropRatio de la pose y lo mapea 1:1 a la altura del pájaro.
  ///
  /// El rango se adapta en una sola dirección (solo crece) hacia el recorrido
  /// real del jugador y el filtro exponencial quita el jitter de la pose.
  void feedDepth(double dropRatio) {
    if (gameOver) return;
    final r = dropRatio.clamp(0.0, 1.0);
    if (r < _calMin) _calMin += _expandRate * (r - _calMin);
    if (r > _calMax) _calMax += _expandRate * (r - _calMax);
    final n = ((r - _calMin) / (_calMax - _calMin)).clamp(0.0, 1.0);
    if (!_filteredInit) {
      _filteredDepth = n;
      _filteredInit = true;
      return;
    }
    _filteredDepth += (n - _filteredDepth) * _inputFilterK;
  }

  /// Objetivo actual del pájaro a partir de la profundidad filtrada.
  double get targetAltitude => targetForDepth(_filteredDepth);

  /// Mapeo directo y lineal: brazos extendidos (0) = arriba, flexionados (1) =
  /// abajo. Sin zonas muertas ni ganancia: el pájaro sigue al cuerpo a la misma
  /// altura y velocidad.
  double targetForDepth(double depthRatio) {
    final d = depthRatio.clamp(0.0, 1.0);
    return _minAlt + d * (_maxAlt - _minAlt);
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
    final t = 1 - math.exp(-_config.controlRate * dt);
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
