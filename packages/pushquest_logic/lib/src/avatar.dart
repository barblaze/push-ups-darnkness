class AvatarStage {
  const AvatarStage({
    required this.emoji,
    required this.name,
    required this.color,
  });

  final String emoji;
  final String name;
  final int color;
}

class Avatar {
  static const List<AvatarStage> stages = [
    AvatarStage(emoji: '🥚', name: 'Huevo', color: 0xFFF2C94C),
    AvatarStage(emoji: '🐣', name: 'Pollito', color: 0xFFF2994A),
    AvatarStage(emoji: '🐥', name: 'Polluelo', color: 0xFFF9A825),
    AvatarStage(emoji: '🐔', name: 'Gallina', color: 0xFFE07B39),
    AvatarStage(emoji: '🦅', name: 'Águila', color: 0xFFEB5757),
    AvatarStage(emoji: '🦍', name: 'Gorila', color: 0xFF9E9E9E),
    AvatarStage(emoji: '🐉', name: 'Dragón', color: 0xFF27AE60),
  ];

  static AvatarStage forLevel(int level) {
    final index = ((level - 1) ~/ 2).clamp(0, stages.length - 1);
    return stages[index];
  }
}
