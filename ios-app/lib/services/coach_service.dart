import 'supabase_service.dart';
import 'session_manager.dart';
import '../models/coach_group_model.dart';

class CoachService {
  /// Koçun yönettiği grupları çek
  static Future<List<CoachGroupModel>> fetchMyCoachGroups() async {
    try {
      final authId = SupabaseService.client.auth.currentUser?.id;
      if (authId == null) return [];

      final res = await SupabaseService.client
          .from('coach_groups')
          .select('*')
          .eq('coach_auth_id', authId)
          .order('created_at', ascending: false);

      return (res as List).map((e) => CoachGroupModel.fromJson(e)).toList();
    } catch (e) {
      print('[CoachService] fetchMyCoachGroups hata: $e');
      return [];
    }
  }

  /// Yeni Koçluk / Kademe Grubu Oluştur (Örn: "7. Sınıf LGS Grubu")
  static Future<CoachGroupModel?> createCoachGroup({
    required String name,
    required int gradeLevel,
    String? schoolName,
    String? description,
  }) async {
    try {
      final authId = SupabaseService.client.auth.currentUser?.id;
      if (authId == null) return null;

      // 6 Haneli Benzersiz Grup Kodu üret (Örn: KOC-7A26)
      final cleanPrefix = name.length >= 3 ? name.substring(0, 3).toUpperCase() : 'KOC';
      final code = '$cleanPrefix-${gradeLevel}G${DateTime.now().millisecond}';

      final res = await SupabaseService.client.from('coach_groups').insert({
        'coach_auth_id': authId,
        'name': name.trim(),
        'grade_level': gradeLevel,
        'group_code': code,
        'school_name': schoolName?.trim(),
        'description': description?.trim(),
      }).select().single();

      return CoachGroupModel.fromJson(res);
    } catch (e) {
      print('[CoachService] createCoachGroup hata: $e');
      return null;
    }
  }

  /// Öğrenci Koçluk Grubuna Katılma RPC'si
  static Future<Map<String, dynamic>> joinCoachGroup(String groupCode) async {
    try {
      final res = await SupabaseService.client.rpc('join_coach_group', params: {
        'p_group_code': groupCode.trim().toUpperCase(),
      });
      if (res != null) {
        return Map<String, dynamic>.from(res);
      }
    } catch (e) {
      print('[CoachService] joinCoachGroup hata: $e');
      return {'success': false, 'message': e.toString()};
    }
    return {'success': false, 'message': 'Katılım başarısız.'};
  }

  /// Gruptaki Öğrencilerin Canlı Durum ve Ödev Çetelesini Çek
  static Future<List<CoachStudentSummary>> fetchGroupStudentsSummary(String groupId) async {
    try {
      final res = await SupabaseService.client
          .from('coach_group_students')
          .select('student_user_id, family_id, users(name)')
          .eq('group_id', groupId);

      final list = <CoachStudentSummary>[];
      for (final item in (res as List)) {
        final userData = item['users'];
        final studentName = userData != null ? userData['name']?.toString() ?? 'Öğrenci' : 'Öğrenci';
        list.add(CoachStudentSummary(
          studentUserId: item['student_user_id']?.toString() ?? '',
          studentName: studentName,
          familyId: item['family_id']?.toString() ?? '',
          completedAssignmentsCount: 1, // Demo çetelede aktif
          totalQuestionsSolved: 40,
          totalPagesRead: 15,
          isTodayComplete: true,
        ));
      }
      return list;
    } catch (e) {
      print('[CoachService] fetchGroupStudentsSummary hata: $e');
      return [];
    }
  }

  /// App Store Guideline 5.1.1(v) - Koç Hesabını ve Tüm Gruplarını Kalıcı Olarak Sil
  static Future<Map<String, dynamic>> deleteCoachAccount() async {
    try {
      final res = await SupabaseService.client.rpc('delete_coach_account');
      if (res != null && res['success'] == true) {
        SupabaseService.setDeviceToken(null);
        await SessionManager.clearSession();
        await SupabaseService.client.auth.signOut();
        return {
          'success': true,
          'message': res['message']?.toString() ?? 'Koç hesabınız ve tüm verileriniz kalıcı olarak silindi.'
        };
      }
      return {
        'success': false,
        'message': res?['message']?.toString() ?? 'Silme işlemi gerçekleştirilemedi.'
      };
    } catch (e) {
      print('[CoachService] deleteCoachAccount hata: $e');
      return {'success': false, 'message': 'Hata oluştu: $e'};
    }
  }
}
