class BarterItemModel {
  final String id;
  final String familyId;
  final String title;
  final String? description;
  final int costPoints;
  final String icon;
  final String category; // 'chore_transfer', 'privilege', 'activity', 'food'
  final bool isActive;

  BarterItemModel({
    required this.id,
    required this.familyId,
    required this.title,
    this.description,
    required this.costPoints,
    required this.icon,
    required this.category,
    this.isActive = true,
  });

  factory BarterItemModel.fromJson(Map<String, dynamic> json) {
    return BarterItemModel(
      id: json['id']?.toString() ?? '',
      familyId: json['family_id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Takas Ödülü',
      description: json['description']?.toString(),
      costPoints: json['cost_points'] is int ? json['cost_points'] : int.tryParse(json['cost_points']?.toString() ?? '50') ?? 50,
      icon: json['icon']?.toString() ?? '🎁',
      category: json['category']?.toString() ?? 'privilege',
      isActive: json['is_active'] != false,
    );
  }
}

class BarterRedemptionModel {
  final String id;
  final String familyId;
  final String studentUserId;
  final String itemId;
  final int costPoints;
  final String status; // 'pending', 'approved', 'used', 'rejected'
  final DateTime createdAt;

  BarterRedemptionModel({
    required this.id,
    required this.familyId,
    required this.studentUserId,
    required this.itemId,
    required this.costPoints,
    required this.status,
    required this.createdAt,
  });

  factory BarterRedemptionModel.fromJson(Map<String, dynamic> json) {
    return BarterRedemptionModel(
      id: json['id']?.toString() ?? '',
      familyId: json['family_id']?.toString() ?? '',
      studentUserId: json['student_user_id']?.toString() ?? '',
      itemId: json['item_id']?.toString() ?? '',
      costPoints: json['cost_points'] is int ? json['cost_points'] : int.tryParse(json['cost_points']?.toString() ?? '50') ?? 50,
      status: json['status']?.toString() ?? 'pending',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
    );
  }
}
