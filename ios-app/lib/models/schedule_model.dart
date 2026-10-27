class ScheduleLesson {
  final int period;
  final String name;

  ScheduleLesson({
    required this.period,
    required this.name,
  });

  factory ScheduleLesson.fromJson(Map<String, dynamic> json) {
    return ScheduleLesson(
      period: json['period'] is int
          ? json['period']
          : int.tryParse(json['period']?.toString() ?? '1') ?? 1,
      name: json['name']?.toString() ?? '',
    );
  }
}

class DayScheduleModel {
  final String id;
  final String familyId;
  final String userId;
  final int dayOfWeek; // 1 = Pazartesi ... 7 = Pazar
  final List<ScheduleLesson> lessons;
  final List<String> extraMaterials;
  final String reminderNotes;

  DayScheduleModel({
    required this.id,
    required this.familyId,
    required this.userId,
    required this.dayOfWeek,
    required this.lessons,
    required this.extraMaterials,
    this.reminderNotes = '',
  });

  factory DayScheduleModel.fromJson(Map<String, dynamic> json) {
    final rawLessons = json['lessons'] as List<dynamic>? ?? [];
    final parsedLessons = rawLessons
        .map((l) => ScheduleLesson.fromJson(Map<String, dynamic>.from(l as Map)))
        .toList();

    final rawMaterials = json['extra_materials'] as List<dynamic>? ?? [];
    final parsedMaterials = rawMaterials.map((m) => m.toString()).toList();

    return DayScheduleModel(
      id: json['id']?.toString() ?? '',
      familyId: json['family_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      dayOfWeek: json['day_of_week'] is int
          ? json['day_of_week']
          : int.tryParse(json['day_of_week']?.toString() ?? '1') ?? 1,
      lessons: parsedLessons,
      extraMaterials: parsedMaterials,
      reminderNotes: json['reminder_notes']?.toString() ?? '',
    );
  }

  static String getDayName(int day) {
    switch (day) {
      case 1:
        return 'Pazartesi';
      case 2:
        return 'Salı';
      case 3:
        return 'Çarşamba';
      case 4:
        return 'Perşembe';
      case 5:
        return 'Cuma';
      case 6:
        return 'Cumartesi';
      case 7:
        return 'Pazar';
      default:
        return 'Bilinmeyen Gün';
    }
  }
}
