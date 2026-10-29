class FamilyWeeklyContractModel {
  final String id;
  final String familyId;
  final String studentUserId;
  final DateTime weekStartDate;
  final int targetQuestions;
  final int targetReadingPages;
  final double targetNetAverage;
  final bool rewardJokerDay;
  final int rewardExtraGameHours;
  final bool isCompleted;
  final bool jokerDayClaimed;

  FamilyWeeklyContractModel({
    required this.id,
    required this.familyId,
    required this.studentUserId,
    required this.weekStartDate,
    required this.targetQuestions,
    required this.targetReadingPages,
    this.targetNetAverage = 25.0,
    this.rewardJokerDay = true,
    this.rewardExtraGameHours = 2,
    this.isCompleted = false,
    this.jokerDayClaimed = false,
  });

  factory FamilyWeeklyContractModel.fromJson(Map<String, dynamic> json) {
    return FamilyWeeklyContractModel(
      id: json['id']?.toString() ?? '',
      familyId: json['family_id']?.toString() ?? '',
      studentUserId: json['student_user_id']?.toString() ?? '',
      weekStartDate: json['week_start_date'] != null ? DateTime.parse(json['week_start_date']) : DateTime.now(),
      targetQuestions: (json['target_questions'] as num?)?.toInt() ?? 150,
      targetReadingPages: (json['target_reading_pages'] as num?)?.toInt() ?? 100,
      targetNetAverage: (json['target_net_average'] as num?)?.toDouble() ?? 25.0,
      rewardJokerDay: json['reward_joker_day'] != false,
      rewardExtraGameHours: (json['reward_extra_game_hours'] as num?)?.toInt() ?? 2,
      isCompleted: json['is_completed'] == true,
      jokerDayClaimed: json['joker_day_claimed'] == true,
    );
  }
}

class WeeklyNewspaperModel {
  final String headline;
  final String subheadline;
  final String editionDate;
  final String starStudentName;
  final int totalQuestions;
  final int totalPagesRead;
  final List<Map<String, String>> stories;

  WeeklyNewspaperModel({
    required this.headline,
    required this.subheadline,
    required this.editionDate,
    required this.starStudentName,
    required this.totalQuestions,
    required this.totalPagesRead,
    required this.stories,
  });

  factory WeeklyNewspaperModel.fromJson(Map<String, dynamic> json) {
    final rawStories = json['stories'] as List? ?? [];
    final parsedStories = <Map<String, String>>[];
    for (final s in rawStories) {
      if (s is Map) {
        parsedStories.add({
          'title': s['title']?.toString() ?? '',
          'body': s['body']?.toString() ?? '',
        });
      }
    }
    return WeeklyNewspaperModel(
      headline: json['headline']?.toString() ?? 'Haftanın Başarı Bülteni',
      subheadline: json['subheadline']?.toString() ?? '',
      editionDate: json['edition_date']?.toString() ?? '',
      starStudentName: json['star_student_name']?.toString() ?? 'Öğrenci',
      totalQuestions: (json['total_questions'] as num?)?.toInt() ?? 0,
      totalPagesRead: (json['total_pages_read'] as num?)?.toInt() ?? 0,
      stories: parsedStories,
    );
  }
}
