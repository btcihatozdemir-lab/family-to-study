class TaskModel {
  final String id;
  final String familyId;
  final String? userId;
  final String title;
  final String description;
  final int points;
  final String category;
  final String recurrence;
  final String verificationType;
  final bool isFirstComeRace;
  final String? claimedBy;
  final bool isActive;
  final String? status; // 'pending', 'approved', 'rejected', or null if unsubmitted

  TaskModel({
    required this.id,
    required this.familyId,
    this.userId,
    required this.title,
    this.description = '',
    this.points = 10,
    this.category = 'study',
    this.recurrence = 'daily',
    this.verificationType = 'parent_manual',
    this.isFirstComeRace = false,
    this.claimedBy,
    this.isActive = true,
    this.status,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json, {String? submissionStatus}) {
    return TaskModel(
      id: json['id']?.toString() ?? '',
      familyId: json['family_id']?.toString() ?? '',
      userId: json['assigned_to']?.toString() ?? json['user_id']?.toString(),
      title: json['title']?.toString() ?? 'Görev',
      description: json['description']?.toString() ?? '',
      points: json['points'] is int
          ? json['points']
          : int.tryParse(json['points']?.toString() ?? '10') ?? 10,
      category: json['category']?.toString() ?? 'study',
      recurrence: json['recurrence']?.toString() ?? 'daily',
      verificationType: json['verification_type']?.toString() ?? 'parent_manual',
      isFirstComeRace: json['is_first_come_race'] == true,
      claimedBy: json['claimed_by']?.toString(),
      isActive: json['is_active'] != false,
      status: submissionStatus,
    );
  }

  bool get isCompleted => status == 'approved';
  bool get isPending => status == 'pending';
  bool get isRejected => status == 'rejected';
  bool get isRace => isFirstComeRace;
  bool get requiresPhoto =>
      verificationType == 'photo_proof' ||
      verificationType == 'photo_optional' ||
      verificationType == 'qr_scan';
}
