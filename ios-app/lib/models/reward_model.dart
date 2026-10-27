class RewardModel {
  final String id;
  final String familyId;
  final String title;
  final String description;
  final int pointsCost;
  final String iconName;
  final String tier;
  final bool isAvailable;

  RewardModel({
    required this.id,
    required this.familyId,
    required this.title,
    this.description = '',
    required this.pointsCost,
    this.iconName = 'Gift',
    this.tier = 'bronze',
    this.isAvailable = true,
  });

  factory RewardModel.fromJson(Map<String, dynamic> json) {
    return RewardModel(
      id: json['id']?.toString() ?? '',
      familyId: json['family_id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Ödül',
      description: json['description']?.toString() ?? '',
      pointsCost: json['cost_points'] is int
          ? json['cost_points']
          : (json['points_cost'] is int
              ? json['points_cost']
              : int.tryParse(json['cost_points']?.toString() ?? json['points_cost']?.toString() ?? '50') ?? 50),
      iconName: json['icon']?.toString() ?? json['icon_name']?.toString() ?? 'Gift',
      tier: json['tier']?.toString() ?? 'bronze',
      isAvailable: json['is_available'] != false,
    );
  }
}
