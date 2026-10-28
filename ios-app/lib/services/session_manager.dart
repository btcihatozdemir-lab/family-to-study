import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  static const String _keyUserId = 'family_user_id';
  static const String _keyFamilyId = 'family_family_id';
  static const String _keyRole = 'family_role';
  static const String _keyName = 'family_name';
  static const String _keyCurrentState = 'family_current_state';
  static const String _keyMagicToken = 'family_magic_token';
  static const String _keyDeviceToken = 'family_device_token';
  static const String _keyPwaUrl = 'family_pwa_url';

  static const String _keyRoleTitle = 'family_role_title';
  static const String _keyGender = 'family_gender';
  static const String _keyIsPrimaryAdmin = 'family_is_primary_admin';

  static String userId = '';
  static String familyId = '';
  static String role = 'child'; // 'parent' veya 'child'
  static String name = 'Öğrenci';
  static String roleTitle = 'Veli';
  static String gender = 'male';
  static bool isPrimaryAdmin = false;
  static String currentState = 'FREE_TIME';
  static String magicToken = '';
  static String deviceToken = '';
  static String pwaUrl = 'https://btcihatozdemir-lab.github.io/family-to-study/';

  static bool get isStudent => role == 'child';
  static bool get isParent => role == 'parent';
  static bool get isStudying => currentState == 'STUDY_TIME' || currentState == 'ROUTINE_TIME';
  static bool get isLoggedIn => userId.isNotEmpty;
  static String get userName => name;
  static String get familyName => 'FamilyOS';

  static Future<void> clearSession() async {
    userId = '';
    familyId = '';
    role = 'child';
    name = 'Öğrenci';
    roleTitle = 'Veli';
    gender = 'male';
    isPrimaryAdmin = false;
    currentState = 'FREE_TIME';
    magicToken = '';
    deviceToken = '';
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyFamilyId);
    await prefs.remove(_keyRole);
    await prefs.remove(_keyName);
    await prefs.remove(_keyRoleTitle);
    await prefs.remove(_keyGender);
    await prefs.remove(_keyIsPrimaryAdmin);
    await prefs.remove(_keyCurrentState);
    await prefs.remove(_keyMagicToken);
    await prefs.remove(_keyDeviceToken);
  }

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    userId = prefs.getString(_keyUserId) ?? '';
    familyId = prefs.getString(_keyFamilyId) ?? '';
    role = prefs.getString(_keyRole) ?? 'child';
    name = prefs.getString(_keyName) ?? 'Öğrenci';
    roleTitle = prefs.getString(_keyRoleTitle) ?? (role == 'parent' ? 'Veli' : 'Çocuk');
    gender = prefs.getString(_keyGender) ?? 'male';
    isPrimaryAdmin = prefs.getBool(_keyIsPrimaryAdmin) ?? false;
    currentState = prefs.getString(_keyCurrentState) ?? 'FREE_TIME';
    magicToken = prefs.getString(_keyMagicToken) ?? '';
    deviceToken = prefs.getString(_keyDeviceToken) ?? '';
    pwaUrl = prefs.getString(_keyPwaUrl) ?? 'https://btcihatozdemir-lab.github.io/family-to-study/';
  }

  static Future<void> saveUser({
    required String newUserId,
    required String newFamilyId,
    required String newRole,
    required String newName,
    String? newRoleTitle,
    String? newGender,
    bool? newIsPrimaryAdmin,
    String? newToken,
    String? newDeviceToken,
  }) => updateSession(
    newUserId: newUserId,
    newFamilyId: newFamilyId,
    newRole: newRole,
    newName: newName,
    newRoleTitle: newRoleTitle,
    newGender: newGender,
    newIsPrimaryAdmin: newIsPrimaryAdmin,
    newToken: newToken,
    newDeviceToken: newDeviceToken,
  );

  static Future<void> updateSession({
    required String newUserId,
    required String newFamilyId,
    required String newRole,
    required String newName,
    String? newRoleTitle,
    String? newGender,
    bool? newIsPrimaryAdmin,
    String? newToken,
    String? newDeviceToken,
  }) async {
    userId = newUserId;
    familyId = newFamilyId;
    role = newRole;
    name = newName;
    if (newRoleTitle != null) roleTitle = newRoleTitle;
    if (newGender != null) gender = newGender;
    if (newIsPrimaryAdmin != null) isPrimaryAdmin = newIsPrimaryAdmin;
    if (newToken != null && newToken.isNotEmpty) {
      magicToken = newToken;
    }
    if (newDeviceToken != null && newDeviceToken.isNotEmpty) {
      deviceToken = newDeviceToken;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserId, userId);
    await prefs.setString(_keyFamilyId, familyId);
    await prefs.setString(_keyRole, role);
    await prefs.setString(_keyName, name);
    await prefs.setString(_keyRoleTitle, roleTitle);
    await prefs.setString(_keyGender, gender);
    await prefs.setBool(_keyIsPrimaryAdmin, isPrimaryAdmin);
    if (magicToken.isNotEmpty) {
      await prefs.setString(_keyMagicToken, magicToken);
    }
    if (deviceToken.isNotEmpty) {
      await prefs.setString(_keyDeviceToken, deviceToken);
    }
  }

  static Future<void> updateCurrentState(String newState) async {
    currentState = newState;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCurrentState, currentState);
  }
}
