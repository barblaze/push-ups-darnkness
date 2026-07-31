import 'levels.dart';

class PlayerStats {
  const PlayerStats({
    this.totalReps = 0,
    this.totalXp = 0,
    this.bestSessionReps = 0,
    this.bestCombo = 0,
    this.streakDays = 0,
    this.floorReps = 0,
    this.parallettesReps = 0,
    this.sessionsCount = 0,
    this.daysActive = 0,
  });

  final int totalReps;
  final int totalXp;
  final int bestSessionReps;
  final int bestCombo;
  final int streakDays;
  final int floorReps;
  final int parallettesReps;
  final int sessionsCount;
  final int daysActive;
}

class Achievement {
  const Achievement({
    required this.id,
    required this.icon,
    required this.name,
    required this.description,
  });

  final String id;
  final String icon;
  final String name;
  final String description;

  bool isUnlocked(PlayerStats stats) {
    switch (id) {
      case 'first_workout':
        return stats.sessionsCount >= 1;
      case 'reps_50':
        return stats.totalReps >= 50;
      case 'reps_100':
        return stats.totalReps >= 100;
      case 'reps_500':
        return stats.totalReps >= 500;
      case 'reps_1000':
        return stats.totalReps >= 1000;
      case 'reps_2500':
        return stats.totalReps >= 2500;
      case 'session_25':
        return stats.bestSessionReps >= 25;
      case 'session_50':
        return stats.bestSessionReps >= 50;
      case 'session_100':
        return stats.bestSessionReps >= 100;
      case 'combo_5':
        return stats.bestCombo >= 5;
      case 'combo_10':
        return stats.bestCombo >= 10;
      case 'combo_20':
        return stats.bestCombo >= 20;
      case 'streak_3':
        return stats.streakDays >= 3;
      case 'streak_7':
        return stats.streakDays >= 7;
      case 'streak_30':
        return stats.streakDays >= 30;
      case 'floor_200':
        return stats.floorReps >= 200;
      case 'paralelas_200':
        return stats.parallettesReps >= 200;
      case 'level_5':
        return Levels.fromXp(stats.totalXp).level >= 5;
      case 'level_10':
        return Levels.fromXp(stats.totalXp).level >= 10;
      case 'active_7':
        return stats.daysActive >= 7;
      case 'active_30':
        return stats.daysActive >= 30;
      default:
        return false;
    }
  }
}

class AchievementCatalog {
  static const List<Achievement> all = [
    Achievement(
      id: 'first_workout',
      icon: '💪',
      name: 'Primera sesión',
      description: 'Completa tu primer entrenamiento',
    ),
    Achievement(
      id: 'reps_50',
      icon: '🏃',
      name: 'Calentando',
      description: 'Acumula 50 push-ups en total',
    ),
    Achievement(
      id: 'reps_100',
      icon: '🔥',
      name: 'Cien arriba',
      description: 'Acumula 100 push-ups en total',
    ),
    Achievement(
      id: 'reps_500',
      icon: '⚡',
      name: 'Media mil',
      description: 'Acumula 500 push-ups en total',
    ),
    Achievement(
      id: 'reps_1000',
      icon: '🚀',
      name: 'Rocket',
      description: 'Acumula 1.000 push-ups en total',
    ),
    Achievement(
      id: 'reps_2500',
      icon: '🏆',
      name: 'Máquina',
      description: 'Acumula 2.500 push-ups en total',
    ),
    Achievement(
      id: 'session_25',
      icon: '💥',
      name: 'Racha de fuerza',
      description: 'Haz 25 push-ups en una sesión',
    ),
    Achievement(
      id: 'session_50',
      icon: '🌋',
      name: 'Explosivo',
      description: 'Haz 50 push-ups en una sesión',
    ),
    Achievement(
      id: 'session_100',
      icon: '👑',
      name: 'Centurión',
      description: 'Haz 100 push-ups en una sesión',
    ),
    Achievement(
      id: 'combo_5',
      icon: '🔗',
      name: 'Combo x5',
      description: 'Encadena 5 push-ups perfectos',
    ),
    Achievement(
      id: 'combo_10',
      icon: '🔗',
      name: 'Combo x10',
      description: 'Encadena 10 push-ups perfectos',
    ),
    Achievement(
      id: 'combo_20',
      icon: '🔗',
      name: 'Combo x20',
      description: 'Encadena 20 push-ups perfectos',
    ),
    Achievement(
      id: 'streak_3',
      icon: '📅',
      name: 'Constancia',
      description: 'Entrena 3 días seguidos',
    ),
    Achievement(
      id: 'streak_7',
      icon: '📅',
      name: 'Una semana',
      description: 'Entrena 7 días seguidos',
    ),
    Achievement(
      id: 'streak_30',
      icon: '🔥',
      name: 'Mes ardiente',
      description: 'Entrena 30 días seguidos',
    ),
    Achievement(
      id: 'floor_200',
      icon: '🤸',
      name: 'Experto en piso',
      description: 'Acumula 200 push-ups en el suelo',
    ),
    Achievement(
      id: 'paralelas_200',
      icon: '🦾',
      name: 'Maestro de paralelas',
      description: 'Acumula 200 push-ups en paralelas',
    ),
    Achievement(
      id: 'level_5',
      icon: '⭐',
      name: 'Nivel 5',
      description: 'Alcanza el nivel 5',
    ),
    Achievement(
      id: 'level_10',
      icon: '🌟',
      name: 'Nivel 10',
      description: 'Alcanza el nivel 10',
    ),
    Achievement(
      id: 'active_7',
      icon: '🗓️',
      name: 'Semana activa',
      description: 'Entrena en 7 días distintos',
    ),
    Achievement(
      id: 'active_30',
      icon: '🗓️',
      name: 'Mes activo',
      description: 'Entrena en 30 días distintos',
    ),
  ];

  static Achievement byId(String id) =>
      all.firstWhere((a) => a.id == id, orElse: () => all.first);
}

class DailyMission {
  const DailyMission({required this.day, required this.targetReps});

  final DateTime day;
  final int targetReps;

  factory DailyMission.forDay(DateTime day) {
    final target = 10 + ((day.day * 3 + day.month * 5) % 20) * 2;
    return DailyMission(day: DateTime(day.year, day.month, day.day), targetReps: target);
  }

  bool isComplete(int todayReps) => todayReps >= targetReps;

  double progress(int todayReps) => (todayReps / targetReps).clamp(0.0, 1.0);
}
