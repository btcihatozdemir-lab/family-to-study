class ScheduleLesson {
  final int period;
  final String name;

  ScheduleLesson({
    required this.period,
    required this.name,
  });

  factory ScheduleLesson.fromJson(dynamic json, int defaultPeriod) {
    if (json is String) {
      return ScheduleLesson(period: defaultPeriod, name: json);
    }
    if (json is Map) {
      return ScheduleLesson(
        period: json['period'] is int
            ? json['period']
            : int.tryParse(json['period']?.toString() ?? '$defaultPeriod') ?? defaultPeriod,
        name: json['name']?.toString() ?? '',
      );
    }
    return ScheduleLesson(period: defaultPeriod, name: json?.toString() ?? '');
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
  final bool hasPeClass;
  final bool hasArtClass;

  DayScheduleModel({
    required this.id,
    required this.familyId,
    required this.userId,
    required this.dayOfWeek,
    required this.lessons,
    required this.extraMaterials,
    this.reminderNotes = '',
    this.hasPeClass = false,
    this.hasArtClass = false,
  });

  factory DayScheduleModel.fromJson(Map<String, dynamic> json) {
    final rawLessons = json['lessons'] as List<dynamic>? ?? [];
    final List<ScheduleLesson> parsedLessons = [];
    for (int i = 0; i < rawLessons.length; i++) {
      parsedLessons.add(ScheduleLesson.fromJson(rawLessons[i], i + 1));
    }

    final rawMaterials = json['extra_materials'] as List<dynamic>? ?? [];
    final rawCustomItems = json['custom_items_to_pack'] as List<dynamic>? ?? [];
    final Set<String> mergedMaterials = {};
    for (final m in rawMaterials) {
      if (m != null && m.toString().isNotEmpty) mergedMaterials.add(m.toString());
    }
    for (final m in rawCustomItems) {
      if (m != null && m.toString().isNotEmpty) mergedMaterials.add(m.toString());
    }

    // Sanat / Beden eğitimi dersleri varsa otomatik malzeme ekle
    final bool pe = json['has_pe_class'] == true;
    final bool art = json['has_art_class'] == true;
    if (pe && !mergedMaterials.any((m) => m.toLowerCase().contains('spor') || m.toLowerCase().contains('eşofman'))) {
      mergedMaterials.add('👟 Beden Eğitimi: Spor Ayakkabısı & Eşofman');
    }
    if (art && !mergedMaterials.any((m) => m.toLowerCase().contains('resim') || m.toLowerCase().contains('boya'))) {
      mergedMaterials.add('🎨 Görsel Sanatlar: Resim Defteri & Boya Kalemleri');
    }

    return DayScheduleModel(
      id: json['id']?.toString() ?? '',
      familyId: json['family_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      dayOfWeek: json['day_of_week'] is int
          ? json['day_of_week']
          : int.tryParse(json['day_of_week']?.toString() ?? '1') ?? 1,
      lessons: parsedLessons,
      extraMaterials: mergedMaterials.toList(),
      reminderNotes: json['reminder_note']?.toString() ?? json['reminder_notes']?.toString() ?? '',
      hasPeClass: pe,
      hasArtClass: art,
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
