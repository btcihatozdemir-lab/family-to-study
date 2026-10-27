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
    String? submissionStatus,
  }) {
    // If submissionStatus is passed, it overrides status
    if (submissionStatus != null && status == null) {
      // handled via redirecting or assigning
    }
  }

  TaskModel copyWith({
    String? id,
    String? familyId,
    String? userId,
    String? title,
    String? description,
    int? points,
    String? category,
    String? recurrence,
    String? verificationType,
    bool? isFirstComeRace,
    String? claimedBy,
    bool? isActive,
    String? status,
  }) {
    return TaskModel(
      id: id ?? this.id,
      familyId: familyId ?? this.familyId,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      points: points ?? this.points,
      category: category ?? this.category,
      recurrence: recurrence ?? this.recurrence,
      verificationType: verificationType ?? this.verificationType,
      isFirstComeRace: isFirstComeRace ?? this.isFirstComeRace,
      claimedBy: claimedBy ?? this.claimedBy,
      isActive: isActive ?? this.isActive,
      status: status ?? this.status,
    );
  }

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
