class CoachGroupModel {
  final String id;
  final String coachAuthId;
  final String name;
  final int gradeLevel;
  final String groupCode;
  final String? schoolName;
  final String? description;
  final DateTime createdAt;

  CoachGroupModel({
    required this.id,
    required this.coachAuthId,
    required this.name,
    required this.gradeLevel,
    required this.groupCode,
    this.schoolName,
    this.description,
    required this.createdAt,
  });

  factory CoachGroupModel.fromJson(Map<String, dynamic> json) {
    return CoachGroupModel(
      id: json['id']?.toString() ?? '',
      coachAuthId: json['coach_auth_id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Koçluk Grubu',
      gradeLevel: json['grade_level'] is int ? json['grade_level'] : int.tryParse(json['grade_level']?.toString() ?? '7') ?? 7,
      groupCode: json['group_code']?.toString() ?? '',
      schoolName: json['school_name']?.toString(),
      description: json['description']?.toString(),
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
    );
  }
}

class CoachStudentSummary {
  final String studentUserId;
  final String studentName;
  final String familyId;
  final int completedAssignmentsCount;
  final int totalQuestionsSolved;
  final int totalPagesRead;
  final bool isTodayComplete;

  CoachStudentSummary({
    required this.studentUserId,
    required this.studentName,
    required this.familyId,
    required this.completedAssignmentsCount,
    required this.totalQuestionsSolved,
    required this.totalPagesRead,
    required this.isTodayComplete,
  });

  factory CoachStudentSummary.fromJson(Map<String, dynamic> json) {
    return CoachStudentSummary(
      studentUserId: json['student_user_id']?.toString() ?? '',
      studentName: json['student_name']?.toString() ?? 'Öğrenci',
      familyId: json['family_id']?.toString() ?? '',
      completedAssignmentsCount: json['completed_assignments'] ?? 0,
      totalQuestionsSolved: json['total_questions'] ?? 0,
      totalPagesRead: json['total_pages'] ?? 0,
      isTodayComplete: json['is_today_complete'] == true,
    );
  }
}
