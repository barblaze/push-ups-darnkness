import 'levels.dart';

class PlayerStats {
  const PlayerStats({
    this.totalReps = 0,
    this.totalXp = 0,
    this.bestSessionReps = 0,
    this.bestCombo = 0,
    this.streakDays = 0,
    this.floorReps = 0,
    this.sessionsCount = 0,
    this.daysActive = 0,
  });

  final int totalReps;
  final int totalXp;
  final int bestSessionReps;
  final int bestCombo;
  final int streakDays;
  final int floorReps;
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
      case 'reps_25':
        return stats.totalReps >= 25;
      case 'reps_50':
        return stats.totalReps >= 50;
      case 'reps_150':
        return stats.totalReps >= 150;
      case 'reps_300':
        return stats.totalReps >= 300;
      case 'reps_600':
        return stats.totalReps >= 600;
      case 'session_10':
        return stats.bestSessionReps >= 10;
      case 'session_20':
        return stats.bestSessionReps >= 20;
      case 'session_40':
        return stats.bestSessionReps >= 40;
      case 'combo_3':
        return stats.bestCombo >= 3;
      case 'combo_5':
        return stats.bestCombo >= 5;
      case 'combo_10':
        return stats.bestCombo >= 10;
      case 'streak_3':
        return stats.streakDays >= 3;
      case 'streak_7':
        return stats.streakDays >= 7;
      case 'streak_14':
        return stats.streakDays >= 14;
      case 'floor_100':
        return stats.floorReps >= 100;
      case 'level_3':
        return Levels.fromXp(stats.totalXp).level >= 3;
      case 'level_5':
        return Levels.fromXp(stats.totalXp).level >= 5;
      case 'active_3':
        return stats.daysActive >= 3;
      case 'active_7':
        return stats.daysActive >= 7;
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
      id: 'reps_25',
      icon: '🏃',
      name: 'Calentando',
      description: 'Acumula 25 push-ups en total',
    ),
    Achievement(
      id: 'reps_50',
      icon: '🔥',
      name: 'Primer reto',
      description: 'Acumula 50 push-ups en total',
    ),
    Achievement(
      id: 'reps_150',
      icon: '⚡',
      name: 'Ritmo constante',
      description: 'Acumula 150 push-ups en total',
    ),
    Achievement(
      id: 'reps_300',
      icon: '🚀',
      name: 'Sin freno',
      description: 'Acumula 300 push-ups en total',
    ),
    Achievement(
      id: 'reps_600',
      icon: '🏆',
      name: 'Imparable',
      description: 'Acumula 600 push-ups en total',
    ),
    Achievement(
      id: 'session_10',
      icon: '💥',
      name: 'Racha de fuerza',
      description: 'Haz 10 push-ups en una sesión',
    ),
    Achievement(
      id: 'session_20',
      icon: '🌋',
      name: 'Explosivo',
      description: 'Haz 20 push-ups en una sesión',
    ),
    Achievement(
      id: 'session_40',
      icon: '👑',
      name: 'Fortaleza',
      description: 'Haz 40 push-ups en una sesión',
    ),
    Achievement(
      id: 'combo_3',
      icon: '🔗',
      name: 'Combo x3',
      description: 'Encadena 3 push-ups perfectos',
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
      id: 'streak_14',
      icon: '🔥',
      name: 'Quincena',
      description: 'Entrena 14 días seguidos',
    ),
    Achievement(
      id: 'floor_100',
      icon: '🤸',
      name: 'Experto en piso',
      description: 'Acumula 100 push-ups en el suelo',
    ),
    Achievement(
      id: 'level_3',
      icon: '⭐',
      name: 'Nivel 3',
      description: 'Alcanza el nivel 3',
    ),
    Achievement(
      id: 'level_5',
      icon: '🌟',
      name: 'Nivel 5',
      description: 'Alcanza el nivel 5',
    ),
    Achievement(
      id: 'active_3',
      icon: '🗓️',
      name: 'Primeros pasos',
      description: 'Entrena en 3 días distintos',
    ),
    Achievement(
      id: 'active_7',
      icon: '🗓️',
      name: 'Semana activa',
      description: 'Entrena en 7 días distintos',
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
    final target = 6 + ((day.day * 3 + day.month * 5) % 10) * 2;
    return DailyMission(
      day: DateTime(day.year, day.month, day.day),
      targetReps: target,
    );
  }

  bool isComplete(int todayReps) => todayReps >= targetReps;

  double progress(int todayReps) => (todayReps / targetReps).clamp(0.0, 1.0);
}
