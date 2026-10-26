import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  static const String _keyUserId = 'family_user_id';
  static const String _keyFamilyId = 'family_family_id';
  static const String _keyRole = 'family_role';
  static const String _keyName = 'family_name';
  static const String _keyCurrentState = 'family_current_state';
  static const String _keyMagicToken = 'family_magic_token';
  static const String _keyPwaUrl = 'family_pwa_url';

  static String userId = '';
  static String familyId = 'fam-ozdemir';
  static String role = 'child'; // 'parent' veya 'child'
  static String name = 'Öğrenci';
  static String currentState = 'FREE_TIME';
  static String magicToken = '';
  static String pwaUrl = 'https://btcihatozdemir-lab.github.io/family-to-study/';

  static bool get isStudent => role == 'child';
  static bool get isParent => role == 'parent';
  static bool get isStudying => currentState == 'STUDY_TIME' || currentState == 'ROUTINE_TIME';

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    userId = prefs.getString(_keyUserId) ?? '';
    familyId = prefs.getString(_keyFamilyId) ?? 'fam-ozdemir';
    role = prefs.getString(_keyRole) ?? 'child';
    name = prefs.getString(_keyName) ?? 'Öğrenci';
    currentState = prefs.getString(_keyCurrentState) ?? 'FREE_TIME';
    magicToken = prefs.getString(_keyMagicToken) ?? '';
    pwaUrl = prefs.getString(_keyPwaUrl) ?? 'https://btcihatozdemir-lab.github.io/family-to-study/';
  }

  static Future<void> updateSession({
    required String newUserId,
    required String newFamilyId,
    required String newRole,
    required String newName,
    String? newToken,
  }) async {
    userId = newUserId;
    familyId = newFamilyId;
    role = newRole;
    name = newName;
    if (newToken != null && newToken.isNotEmpty) {
      magicToken = newToken;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserId, userId);
    await prefs.setString(_keyFamilyId, familyId);
    await prefs.setString(_keyRole, role);
    await prefs.setString(_keyName, name);
    if (magicToken.isNotEmpty) {
      await prefs.setString(_keyMagicToken, magicToken);
    }
  }

  static Future<void> updateCurrentState(String newState) async {
    currentState = newState;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCurrentState, currentState);
  }
}
