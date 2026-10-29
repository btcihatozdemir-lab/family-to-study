class CoachGroupModel {
  final String id;
  final String coachAuthId;
  final String name;
  final int gradeLevel;
  final String groupCode;
  final String subject; // 'matematik', 'turkce', 'ingilizce', 'fen', 'sosyal', 'lgs_genel'
  final String? schoolName;
  final String city;
  final String district;
  final String bio;
  final String? description;
  final bool isPublic;
  final int activeStudentsCount;
  final DateTime createdAt;

  CoachGroupModel({
    required this.id,
    required this.coachAuthId,
    required this.name,
    required this.gradeLevel,
    required this.groupCode,
    this.subject = 'matematik',
    this.schoolName,
    this.city = '',
    this.district = '',
    this.bio = '',
    this.description,
    this.isPublic = true,
    this.activeStudentsCount = 0,
    required this.createdAt,
  });

  factory CoachGroupModel.fromJson(Map<String, dynamic> json) {
    return CoachGroupModel(
      id: json['id']?.toString() ?? '',
      coachAuthId: json['coach_auth_id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Koçluk Grubu',
      gradeLevel: json['grade_level'] is int ? json['grade_level'] : int.tryParse(json['grade_level']?.toString() ?? '7') ?? 7,
      groupCode: json['group_code']?.toString() ?? '',
      subject: (json['subject']?.toString() ?? 'matematik').toLowerCase(),
      schoolName: json['school_name']?.toString(),
      city: json['city']?.toString() ?? '',
      district: json['district']?.toString() ?? '',
      bio: json['bio']?.toString() ?? '',
      description: json['description']?.toString(),
      isPublic: json['is_public'] != false,
      activeStudentsCount: json['active_students_count'] is int ? json['active_students_count'] : int.tryParse(json['active_students_count']?.toString() ?? '0') ?? 0,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
    );
  }
}

class CoachStudentSummary {
  final String studentUserId;
  final String studentName;
  final String familyId;
  final String status; // 'pending_parent', 'pending_coach', 'approved', 'rejected'
  final int completedAssignmentsCount;
  final int totalQuestionsSolved;
  final double totalNet;
  final int totalPagesRead;
  final int totalWordsLearned;
  final int totalIdiomsLearned;
  final bool isTodayComplete;

  CoachStudentSummary({
    required this.studentUserId,
    required this.studentName,
    required this.familyId,
    this.status = 'approved',
    required this.completedAssignmentsCount,
    required this.totalQuestionsSolved,
    this.totalNet = 0.0,
    required this.totalPagesRead,
    this.totalWordsLearned = 0,
    this.totalIdiomsLearned = 0,
    required this.isTodayComplete,
  });

  factory CoachStudentSummary.fromJson(Map<String, dynamic> json) {
    return CoachStudentSummary(
      studentUserId: json['student_user_id']?.toString() ?? '',
      studentName: json['student_name']?.toString() ?? 'Öğrenci',
      familyId: json['family_id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'approved',
      completedAssignmentsCount: json['completed_assignments'] ?? 0,
      totalQuestionsSolved: json['total_questions'] ?? 0,
      totalNet: (json['total_net'] != null) ? (double.tryParse(json['total_net'].toString()) ?? 0.0) : 0.0,
      totalPagesRead: json['total_pages'] ?? 0,
      totalWordsLearned: json['total_words_learned'] ?? 0,
      totalIdiomsLearned: json['total_idioms_learned'] ?? 0,
      isTodayComplete: json['is_today_complete'] == true,
    );
  }
}

class CoachLeaderboardEntry {
  final int rank;
  final String studentUserId;
  final String studentName;
  final String status;
  final int totalQuestions;
  final int totalCorrect;
  final int totalWrong;
  final double totalNet;
  final int totalPagesRead;
  final int totalWordsLearned;
  final int totalIdiomsLearned;
  final int totalStudyMinutes;

  CoachLeaderboardEntry({
    required this.rank,
    required this.studentUserId,
    required this.studentName,
    required this.status,
    required this.totalQuestions,
    required this.totalCorrect,
    required this.totalWrong,
    required this.totalNet,
    required this.totalPagesRead,
    required this.totalWordsLearned,
    required this.totalIdiomsLearned,
    required this.totalStudyMinutes,
  });

  factory CoachLeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return CoachLeaderboardEntry(
      rank: json['rank'] is int ? json['rank'] : int.tryParse(json['rank']?.toString() ?? '1') ?? 1,
      studentUserId: json['student_user_id']?.toString() ?? '',
      studentName: json['student_name']?.toString() ?? 'Öğrenci',
      status: json['status']?.toString() ?? 'approved',
      totalQuestions: (json['total_questions'] as num?)?.toInt() ?? 0,
      totalCorrect: (json['total_correct'] as num?)?.toInt() ?? 0,
      totalWrong: (json['total_wrong'] as num?)?.toInt() ?? 0,
      totalNet: (json['total_net'] as num?)?.toDouble() ?? 0.0,
      totalPagesRead: (json['total_pages_read'] as num?)?.toInt() ?? 0,
      totalWordsLearned: (json['total_words_learned'] as num?)?.toInt() ?? 0,
      totalIdiomsLearned: (json['total_idioms_learned'] as num?)?.toInt() ?? 0,
      totalStudyMinutes: (json['total_study_minutes'] as num?)?.toInt() ?? 0,
    );
  }
}

class StudentSubjectSummary {
  final String subject;
  final int totalQuestions;
  final int totalCorrect;
  final int totalWrong;
  final double totalNet;
  final int totalPagesRead;
  final int totalWordsLearned;
  final int totalIdiomsLearned;
  final int totalStudyMinutes;
  final String? lastActivityDate;

  StudentSubjectSummary({
    required this.subject,
    required this.totalQuestions,
    required this.totalCorrect,
    required this.totalWrong,
    required this.totalNet,
    required this.totalPagesRead,
    required this.totalWordsLearned,
    required this.totalIdiomsLearned,
    required this.totalStudyMinutes,
    this.lastActivityDate,
  });

  factory StudentSubjectSummary.fromJson(Map<String, dynamic> json) {
    return StudentSubjectSummary(
      subject: json['subject']?.toString() ?? 'genel',
      totalQuestions: (json['total_questions'] as num?)?.toInt() ?? 0,
      totalCorrect: (json['total_correct'] as num?)?.toInt() ?? 0,
      totalWrong: (json['total_wrong'] as num?)?.toInt() ?? 0,
      totalNet: (json['total_net'] as num?)?.toDouble() ?? 0.0,
      totalPagesRead: (json['total_pages_read'] as num?)?.toInt() ?? 0,
      totalWordsLearned: (json['total_words_learned'] as num?)?.toInt() ?? 0,
      totalIdiomsLearned: (json['total_idioms_learned'] as num?)?.toInt() ?? 0,
      totalStudyMinutes: (json['total_study_minutes'] as num?)?.toInt() ?? 0,
      lastActivityDate: json['last_activity_date']?.toString(),
    );
  }
}
