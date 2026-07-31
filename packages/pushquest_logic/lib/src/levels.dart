class LevelInfo {
  const LevelInfo({
    required this.level,
    required this.totalXp,
    required this.xpIntoLevel,
    required this.xpForNext,
  });

  final int level;
  final int totalXp;
  final int xpIntoLevel;
  final int xpForNext;

  double get progress => xpForNext == 0 ? 1 : (xpIntoLevel / xpForNext).clamp(0.0, 1.0);
}

class Levels {
  static const List<String> titles = [
    'Novato',
    'Aprendiz',
    'Constante',
    'Fuerte',
    'Guerrero',
    'Atleta',
    'Bestia',
    'PushMaster',
    'Leyenda',
    'Fénix',
  ];

  static int xpForLevel(int level) => 100 + (level - 1) * 75;

  static int totalXpForLevel(int level) {
    var xp = 0;
    for (var i = 1; i < level; i++) {
      xp += xpForLevel(i);
    }
    return xp;
  }

  static LevelInfo fromXp(int totalXp) {
    var level = 1;
    var remaining = totalXp;
    while (remaining >= xpForLevel(level)) {
      remaining -= xpForLevel(level);
      level += 1;
    }
    return LevelInfo(
      level: level,
      totalXp: totalXp,
      xpIntoLevel: remaining,
      xpForNext: xpForLevel(level),
    );
  }

  static String titleFor(int level) => titles[level.clamp(1, titles.length) - 1];
}
