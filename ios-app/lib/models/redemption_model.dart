class RedemptionModel {
  final String id;
  final String familyId;
  final String studentId;
  final String studentName;
  final String rewardId;
  final String rewardTitle;
  final int pointsSpent;
  final String status;
  final DateTime createdAt;

  RedemptionModel({
    required this.id,
    required this.familyId,
    required this.studentId,
    required this.studentName,
    required this.rewardId,
    required this.rewardTitle,
    required this.pointsSpent,
    required this.status,
    required this.createdAt,
  });

  factory RedemptionModel.fromJson(Map<String, dynamic> json, {String studentName = 'Öğrenci', String rewardTitle = 'Ödül'}) {
    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(json['created_at']?.toString() ?? '');
    } catch (_) {
      parsedDate = DateTime.now();
    }

    return RedemptionModel(
      id: json['id']?.toString() ?? '',
      familyId: json['family_id']?.toString() ?? '',
      studentId: json['user_id']?.toString() ?? '',
      studentName: json['student_name']?.toString() ?? studentName,
      rewardId: json['reward_id']?.toString() ?? '',
      rewardTitle: json['reward_title']?.toString() ?? rewardTitle,
      pointsSpent: json['points_spent'] is int ? json['points_spent'] : 0,
      status: json['status']?.toString() ?? 'pending',
      createdAt: parsedDate,
    );
  }
}
