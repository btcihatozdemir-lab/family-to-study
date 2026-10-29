class TimeVaultModel {
  final String id;
  final String familyId;
  final String studentId;
  final int savedMinutes;
  final int borrowedMinutes;

  TimeVaultModel({
    required this.id,
    required this.familyId,
    required this.studentId,
    required this.savedMinutes,
    required this.borrowedMinutes,
  });

  factory TimeVaultModel.fromJson(Map<String, dynamic> json) {
    return TimeVaultModel(
      id: json['id']?.toString() ?? '',
      familyId: json['family_id']?.toString() ?? '',
      studentId: json['student_id']?.toString() ?? '',
      savedMinutes: json['saved_minutes'] is int ? json['saved_minutes'] : int.tryParse(json['saved_minutes']?.toString() ?? '0') ?? 0,
      borrowedMinutes: json['borrowed_minutes'] is int ? json['borrowed_minutes'] : int.tryParse(json['borrowed_minutes']?.toString() ?? '0') ?? 0,
    );
  }
}
