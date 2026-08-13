enum PushUpMode { floor, parallel, free }

extension PushUpModeDetails on PushUpMode {
  String get label => switch (this) {
        PushUpMode.floor => 'Piso',
        PushUpMode.parallel => 'Paralelas',
        PushUpMode.free => 'Libre',
      };

  String get icon => switch (this) {
        PushUpMode.floor => '🤸',
        PushUpMode.parallel => '💪',
        PushUpMode.free => '🏋️',
      };

  String get positionHint => switch (this) {
        PushUpMode.floor => 'Colócate en el suelo y haz lagartijas con buena forma',
        PushUpMode.parallel =>
          'Sujeta las barras paralelas y baja flexionando los codos',
        PushUpMode.free => 'Haz push-ups a tu ritmo: solo contamos tus reps',
      };
}
