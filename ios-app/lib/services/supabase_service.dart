import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'session_manager.dart';
import 'notification_service.dart';
import 'audio_keep_alive_service.dart';

class SupabaseService {
  static const String supabaseUrl = 'https://pljxviezoilirlsoavto.supabase.co';
  static const String supabaseAnonKey =
      'sb_publishable_J9zEygp-UY48F0QYIM0gKg_BFg3KlTD';

  static SupabaseClient get client => Supabase.instance.client;
  static RealtimeChannel? _familyChannel;

  static Future<void> init() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      realtimeClientOptions: const RealtimeClientOptions(
        eventsPerSecond: 10,
      ),
    );

    subscribeToRealtimeEvents();
  }

  /// 7/24 Supabase Realtime WebSocket Dinleyicisi
  static void subscribeToRealtimeEvents() {
    _familyChannel?.unsubscribe();

    final famId = SessionManager.familyId;
    _familyChannel = client.channel('ios_family_realtime_$famId');

    // 1. İhlal Dinleyici (Veli için)
    _familyChannel!.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'violation_logs',
      callback: (payload) {
        final record = payload.newRecord;
        if (record['family_id'] == famId) {
          if (SessionManager.isParent) {
            final reason = record['violation_type'] ?? 'Bilinmeyen İhlal';
            NotificationService.showViolationAlert(
              studentName: 'Öğrenci',
              reason: reason.toString(),
            );
          }
        }
      },
    );

    // 2. Görev Teslim ve Onay Dinleyici (Hem Veli Hem Öğrenci İçin)
    _familyChannel!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'task_submissions',
      callback: (payload) {
        final record = payload.newRecord;
        final status = record['status'];
        final studentId = record['student_id'];

        if (SessionManager.isParent && status == 'pending') {
          NotificationService.showTaskSubmissionAlert(
            studentName: 'Öğrenciniz',
            taskTitle: 'Yeni Görev',
          );
        } else if (SessionManager.isStudent && studentId == SessionManager.userId) {
          if (status == 'approved') {
            final points = record['awarded_points'] ?? 50;
            NotificationService.showTaskApprovedAlert(
              taskTitle: 'Göreviniz',
              points: points is int ? points : int.tryParse(points.toString()) ?? 50,
            );
          }
        }
      },
    );

    // 3. Bas-Konuş & Telsiz DM Mesaj Dinleyici
    _familyChannel!.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      callback: (payload) {
        final record = payload.newRecord;
        final receiverId = record['receiver_id'];

        if (receiverId == SessionManager.userId || receiverId == 'all') {
          final content = record['content'] ?? 'Yeni sesli telsiz mesajı';
          NotificationService.showWalkieTalkieAlert(
            senderName: record['sender_name'] ?? 'Aile Bireyi',
            previewText: content.toString(),
          );
        }
      },
    );

    // 4. Adalet Divanı İtiraz Dinleyici (Veli için)
    _familyChannel!.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'appeals',
      callback: (payload) {
        final record = payload.newRecord;
        if (SessionManager.isParent) {
          final reason = record['reason_text'] ?? 'Karara itiraz edildi.';
          NotificationService.showAppealAlert(
            studentName: 'Öğrenciniz',
            reason: reason.toString(),
          );
        }
      },
    );

    // 5. Kullanıcı Durum Dinleyici (Öğrenci için Sabah Uyanma & Mod Değişimi)
    _familyChannel!.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'users',
      callback: (payload) {
        final record = payload.newRecord;
        if (record['id'] == SessionManager.userId) {
          final newState = record['current_state']?.toString() ?? 'FREE_TIME';
          SessionManager.updateCurrentState(newState);

          if (newState == 'WAKE_UP_ALARM') {
            NotificationService.showWakeUpAlarm(
              message: 'Sabah Görevleri ve Canlı Çanta Seni Bekliyor!',
            );
            AudioKeepAliveService.playLoudAlarm();
          }
        }
      },
    );

    _familyChannel!.subscribe();
    print('[SupabaseService] Realtime kanallarına abone olundu: famId=$famId');
  }

  /// Öğrenci Ders Saatinde Uygulamadan Çıktığında (Home tuşu / Minimize) İhlal Kaydı
  static Future<void> reportAppMinimizedViolation() async {
    if (!SessionManager.isStudent || !SessionManager.isStudying) return;

    try {
      print('[SupabaseService] 🚨 Öğrenci ders saatinde uygulamayı alta attı! İhlal işleniyor...');
      
      // 1. Supabase violation_logs tablosuna kaydet
      await client.from('violation_logs').insert({
        'family_id': SessionManager.familyId,
        'user_id': SessionManager.userId,
        'violation_type': 'ios_app_minimized',
        'details': 'Öğrenci iOS uygulamasından çıktı veya başka uygulamaya geçti',
        'occurred_at': DateTime.now().toUtc().toIso8601String(),
      });

      // 2. Kalkan kırma RPC fonksiyonunu tetikle (varsa)
      try {
        await client.rpc('record_violation_and_break_shield', params: {
          'p_family_id': SessionManager.familyId,
          'p_student_id': SessionManager.userId,
          'p_violation_type': 'ios_app_minimized',
        });
      } catch (_) {}

      // 3. Öğrenciye anında yerel kilit ekranı uyarısı at
      NotificationService.showAppMinimizedWarning();
    } catch (e) {
      print('[SupabaseService] İhlal gönderme hatası: $e');
    }
  }
}
