import 'supabase_service.dart';
import 'session_manager.dart';
import '../models/time_vault_model.dart';
import '../models/lingua_model.dart';

class TimeVaultService {
  /// Öğrencinin Zaman Bankası Bakiyesini Çek
  static Future<TimeVaultModel?> fetchTimeVault(String studentId) async {
    try {
      final res = await SupabaseService.client.rpc('get_or_create_time_vault', params: {
        'p_student_id': studentId,
      });

      if (res != null && res['success'] == true) {
        return TimeVaultModel(
          id: 'vault-$studentId',
          familyId: SessionManager.familyId,
          studentId: studentId,
          savedMinutes: res['saved_minutes'] ?? 30,
          borrowedMinutes: res['borrowed_minutes'] ?? 0,
        );
      }
    } catch (e) {
      print('[TimeVaultService] fetchTimeVault hata: $e');
    }
    return null;
  }

  /// 5 Dakika Mola İste (Grace Break)
  static Future<Map<String, dynamic>> requestGraceBreak() async {
    try {
      final res = await SupabaseService.client.rpc('request_grace_break', params: {
        'p_device_id': SessionManager.deviceId.isNotEmpty ? SessionManager.deviceId : null,
      });
      if (res != null) {
        return Map<String, dynamic>.from(res);
      }
    } catch (e) {
      print('[TimeVaultService] requestGraceBreak hata: $e');
      return {'success': false, 'message': e.toString()};
    }
    return {'success': false, 'message': 'İstek gönderilemedi.'};
  }

  /// Günün Kelimesini Çek (TR / EN / DE)
  static Future<LinguaModel?> fetchWordOfTheDay({String langCode = 'tr'}) async {
    try {
      final res = await SupabaseService.client
          .from('lingua_words')
          .select('*')
          .eq('lang_code', langCode)
          .limit(1);

      if ((res as List).isNotEmpty) {
        return LinguaModel.fromJson(res.first);
      }
    } catch (e) {
      print('[TimeVaultService] fetchWordOfTheDay hata: $e');
    }
    return null;
  }
}
