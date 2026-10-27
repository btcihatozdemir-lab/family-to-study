class UserModel {
  final String id;
  final String familyId;
  final String name;
  final String role;
  final String currentState;
  final String? stateEndsAt;
  final int pointsBalance;
  final int piggyBankBalance;
  final int dailyShields;
  final bool graceUsedToday;
  final bool appealUsedToday;
  final String avatarBg;
  final String avatarEmoji;
  final int wheelSpinsAvailable;
  final int streakDays;
  final String roleTitle;
  final String gender;
  final bool isPrimaryAdmin;

  UserModel({
    required this.id,
    required this.familyId,
    required this.name,
    required this.role,
    this.currentState = 'FREE_TIME',
    this.stateEndsAt,
    this.pointsBalance = 0,
    this.piggyBankBalance = 0,
    this.dailyShields = 3,
    this.graceUsedToday = false,
    this.appealUsedToday = false,
    this.avatarBg = 'from-indigo-500 to-purple-600',
    this.avatarEmoji = '🦁',
    this.wheelSpinsAvailable = 1,
    this.streakDays = 0,
    this.roleTitle = 'Veli',
    this.gender = 'male',
    this.isPrimaryAdmin = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final avatar = json['avatar_config'] as Map<String, dynamic>? ?? {};
    final rawRole = json['role']?.toString() ?? 'child';
    final rawTitle = avatar['roleTitle']?.toString() ??
        (rawRole == 'parent' ? 'Veli' : 'Çocuk');

    return UserModel(
      id: json['id']?.toString() ?? '',
      familyId: json['family_id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Öğrenci',
      role: rawRole,
      currentState: json['current_state']?.toString() ?? 'FREE_TIME',
      stateEndsAt: json['state_ends_at']?.toString(),
      pointsBalance: json['points_balance'] is int
          ? json['points_balance']
          : int.tryParse(json['points_balance']?.toString() ?? '0') ?? 0,
      piggyBankBalance: json['piggy_bank_balance'] is int
          ? json['piggy_bank_balance']
          : int.tryParse(json['piggy_bank_balance']?.toString() ?? '0') ?? 0,
      dailyShields: json['daily_shields'] is int
          ? json['daily_shields']
          : int.tryParse(json['daily_shields']?.toString() ?? '3') ?? 3,
      graceUsedToday: json['grace_used_today'] == true,
      appealUsedToday: json['appeal_used_today'] == true,
      avatarBg: avatar['bg']?.toString() ?? 'from-indigo-500 to-purple-600',
      avatarEmoji: avatar['emoji']?.toString() ?? '🦁',
      wheelSpinsAvailable: json['wheel_spins_available'] is int
          ? json['wheel_spins_available']
          : int.tryParse(json['wheel_spins_available']?.toString() ?? '1') ?? 1,
      streakDays: json['streak_days'] is int
          ? json['streak_days']
          : int.tryParse(json['streak_days']?.toString() ?? '0') ?? 0,
      roleTitle: rawTitle,
      gender: avatar['gender']?.toString() ?? 'male',
      isPrimaryAdmin: avatar['isPrimaryAdmin'] == true || avatar['is_primary_admin'] == true,
    );
  }

  int get points => pointsBalance;
  int get totalXp => pointsBalance + piggyBankBalance;
  int get level => (totalXp ~/ 100) + 1;
  double get levelProgress => (totalXp % 100) / 100.0;
  bool get isStudying => currentState == 'STUDY_TIME' || currentState == 'ROUTINE_TIME';

  /// Çocuğun perspektifinden gerçek akrabalık hitabını döndürür.
  /// (Asla velinin yazdığı "Eşim" veya "Ben" çocuğa gösterilmez!)
  String getKinshipNameForChild(UserModel child) {
    if (id == child.id) return 'Ben';
    final rt = roleTitle.toLowerCase();
    final nm = name.toLowerCase();

    if (role == 'parent') {
      if (rt.contains('anne') || nm.contains('anne') || nm.contains('merve') || nm.contains('eşim')) return 'Annem';
      if (rt.contains('baba') || nm.contains('baba') || nm.contains('cihat') || nm.contains('ben')) return 'Babam';
      if (rt.contains('hala')) return 'Halam';
      if (rt.contains('dayı')) return 'Dayım';
      if (rt.contains('teyze')) return 'Teyzem';
      if (rt.contains('amca')) return 'Amcam';
      if (rt.contains('dede')) return 'Dedem';
      if (rt.contains('anneanne')) return 'Anneannem';
      if (rt.contains('babaanne')) return 'Babaannem';
      if (rt.contains('abla')) return 'Ablam';
      if (rt.contains('abi')) return 'Abim';
      return name.split(' ').first;
    } else {
      // Çocuk kardeş
      return name.split(' ').first;
    }
  }
}
