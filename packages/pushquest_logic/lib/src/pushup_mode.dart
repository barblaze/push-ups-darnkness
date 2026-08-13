enum PushUpMode { floor, parallel, free, arcade }

extension PushUpModeDetails on PushUpMode {
  String get label => switch (this) {
        PushUpMode.floor => 'Piso',
        PushUpMode.parallel => 'Paralelas',
        PushUpMode.free => 'Libre',
        PushUpMode.arcade => 'Arcade',
      };

  String get icon => switch (this) {
        PushUpMode.floor => '🤸',
        PushUpMode.parallel => '💪',
        PushUpMode.free => '🏋️',
        PushUpMode.arcade => '🎮',
      };

  String get positionHint => switch (this) {
        PushUpMode.floor => 'Colócate en el suelo y haz lagartijas con buena forma',
        PushUpMode.parallel =>
          'Sujeta las barras paralelas y baja flexionando los codos',
        PushUpMode.free => 'Haz push-ups a tu ritmo: solo contamos tus reps',
        PushUpMode.arcade =>
          'Vuela haciendo push-ups: arriba subes, abajo bajas',
      };

  /// Modos que cuentan cualquier rep sin exigir plancha ni profundidad extra.
  bool get countsAnyRep =>
      this == PushUpMode.free || this == PushUpMode.arcade;
}
