import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'session_manager.dart';
import 'notification_service.dart';
import 'audio_keep_alive_service.dart';
import '../models/user_model.dart';
import '../models/task_model.dart';
import '../models/schedule_model.dart';
import '../models/reward_model.dart';
import '../models/message_model.dart';
import '../models/submission_model.dart';
import '../models/appeal_model.dart';
import '../models/redemption_model.dart';

class SupabaseService {
  static const String supabaseUrl = 'https://pljxviezoilirlsoavto.supabase.co';
  static const String supabaseAnonKey =
      'sb_publishable_J9zEygp-UY48F0QYIM0gKg_BFg3KlTD';

  static SupabaseClient get client => Supabase.instance.client;
  static RealtimeChannel? _familyChannel;

  // StreamControllers for live UI updates
  static final StreamController<UserModel> studentUpdateController =
      StreamController<UserModel>.broadcast();
  static final StreamController<void> tasksUpdateController =
      StreamController<void>.broadcast();
  static final StreamController<MessageModel> messageReceivedController =
      StreamController<MessageModel>.broadcast();
  static StreamController<MessageModel> get messageStreamController => messageReceivedController;

  static Future<void> init() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      realtimeClientOptions: const RealtimeClientOptions(
        eventsPerSecond: 10,
      ),
    );

    if (SessionManager.familyId.isNotEmpty) {
      subscribeToRealtimeEvents();
    }
  }

  /// 7/24 Supabase Realtime WebSocket Dinleyicisi
  static void subscribeToRealtimeEvents() {
    _familyChannel?.unsubscribe();

    final famId = SessionManager.familyId;
    if (famId.isEmpty) return;

    _familyChannel = client.channel('ios_family_realtime_$famId');

    // 1. Öğrenci Durum & Puan & Kalkan Değişimi Dinleyicisi
    _familyChannel!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'users',
      callback: (payload) {
        final record = payload.newRecord;
        if (record['id'] == SessionManager.userId) {
          final updatedUser = UserModel.fromJson(record);
          SessionManager.updateCurrentState(updatedUser.currentState);
          studentUpdateController.add(updatedUser);

          if (updatedUser.currentState == 'WAKE_UP_ALARM') {
            NotificationService.showWakeUpAlarm(
              message: 'Sabah Görevleri ve Canlı Çanta Seni Bekliyor!',
            );
            AudioKeepAliveService.playLoudAlarm();
          }
        }
      },
    );

    // 2. Görev ve Teslimat Dinleyicisi
    _familyChannel!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'tasks',
      callback: (_) {
        tasksUpdateController.add(null);
      },
    );

    _familyChannel!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'task_submissions',
      callback: (payload) {
        tasksUpdateController.add(null);
        final record = payload.newRecord;
        final status = record['status'];
        final studentId = record['student_id'];

        if (SessionManager.isStudent && studentId == SessionManager.userId) {
          if (status == 'approved') {
            final points = record['awarded_points'] ?? 50;
            NotificationService.showTaskApprovedAlert(
              taskTitle: 'Tebrikler! Görevin onaylandı',
              points: points is int ? points : int.tryParse(points.toString()) ?? 50,
            );
          }
        }
      },
    );

    // 3. Bas-Konuş Telsiz Mesajları
    _familyChannel!.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      callback: (payload) {
        final record = payload.newRecord;
        final receiverId = record['receiver_id'];

        if (receiverId == SessionManager.userId || receiverId == 'all') {
          final msg = MessageModel.fromJson(record);
          messageReceivedController.add(msg);
          NotificationService.showWalkieTalkieAlert(
            senderName: msg.senderName,
            previewText: msg.content,
          );
        }
      },
    );

    _familyChannel!.subscribe();
    print('[SupabaseService] Realtime kanallarına abone olundu: famId=$famId');
  }

  // ---------------------------------------------------------------------------
  // AUTH VE KULLANICI İŞLEMLERİ
  // ---------------------------------------------------------------------------

  /// 6 Haneli Eşleştirme Kodu (Örn: 849-201) ile Giriş
  static Future<UserModel?> loginWithPairingCode(String rawCode) async {
    final cleanCode = rawCode.replaceAll('-', '').replaceAll(' ', '').trim();
    try {
      final res = await client.rpc('verify_desktop_pairing_code', params: {
        'p_code': cleanCode,
      });

      if (res != null && res['success'] == true) {
        final userId = res['user_id']?.toString() ?? '';
        final famId = res['family_id']?.toString() ?? '';
        final token = res['magic_login_token']?.toString() ?? '';

        final user = await fetchStudentProfile(userId);
        if (user != null) {
          await SessionManager.updateSession(
            newUserId: user.id,
            newFamilyId: famId,
            newRole: user.role,
            newName: user.name,
            newToken: token,
          );
          subscribeToRealtimeEvents();
          return user;
        }
      }
    } catch (e) {
      print('[loginWithPairingCode] Hata: $e');
    }
    return null;
  }

  /// PIN / Şifre veya Kullanıcı Adı ile Giriş
  static Future<UserModel?> loginWithPin(String pinOrPass) async {
    final clean = pinOrPass.trim();
    try {
      final res = await client
          .from('users')
          .select('*')
          .or('access_password.eq.$clean,desktop_pairing_code.eq.$clean')
          .limit(1);

      if (res.isNotEmpty) {
        final user = UserModel.fromJson(res.first);
        await SessionManager.updateSession(
          newUserId: user.id,
          newFamilyId: user.familyId,
          newRole: user.role,
          newName: user.name,
        );
        subscribeToRealtimeEvents();
        return user;
      }
    } catch (e) {
      print('[loginWithPin] Hata: $e');
    }
    return null;
  }

  /// Sihirli Link Jetonu (?u=...) ile Giriş
  static Future<UserModel?> loginWithMagicToken(String token) async {
    try {
      final res = await client
          .from('users')
          .select('*')
          .eq('magic_login_token', token.trim())
          .limit(1);

      if (res.isNotEmpty) {
        final user = UserModel.fromJson(res.first);
        await SessionManager.updateSession(
          newUserId: user.id,
          newFamilyId: user.familyId,
          newRole: user.role,
          newName: user.name,
          newToken: token,
        );
        subscribeToRealtimeEvents();
        return user;
      }
    } catch (e) {
      print('[loginWithMagicToken] Hata: $e');
    }
    return null;
  }

  /// Öğrenci Profilini Çek
  static Future<UserModel?> fetchStudentProfile(String userId) async {
    try {
      final res = await client.from('users').select('*').eq('id', userId).limit(1);
      if (res.isNotEmpty) {
        return UserModel.fromJson(res.first);
      }
    } catch (e) {
      print('[fetchStudentProfile] Hata: $e');
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // GÖREVLER (MISSIONS) VE İLK KAPAR YARIŞLARI
  // ---------------------------------------------------------------------------

  /// Öğrencinin aktif görevlerini ve teslimat durumlarını çek
  static Future<List<TaskModel>> fetchTasks(String familyId, String studentId) async {
    try {
      // 1. Ailenin veya bu öğrencinin aktif görevleri
      final tasksRes = await client
          .from('tasks')
          .select('*')
          .eq('family_id', familyId)
          .eq('is_active', true)
          .or('user_id.is.null,user_id.eq.$studentId');

      // 2. Bugün bu öğrencinin yaptığı teslimatlar
      final subsRes = await client
          .from('task_submissions')
          .select('task_id, status')
          .eq('student_id', studentId);

      final Map<String, String> statusMap = {};
      for (final sub in subsRes) {
        statusMap[sub['task_id'].toString()] = sub['status'].toString();
      }

      final List<TaskModel> result = [];
      for (final t in tasksRes) {
        final tId = t['id'].toString();
        result.add(TaskModel.fromJson(t, submissionStatus: statusMap[tId]));
      }

      return result;
    } catch (e) {
      print('[fetchTasks] Hata: $e');
      return [];
    }
  }

  /// Görevi Tamamla / Veli Onayına Gönder
  static Future<bool> submitTask({
    required String taskId,
    required String studentId,
    required String familyId,
    String? photoUrl,
  }) async {
    try {
      await client.from('task_submissions').insert({
        'family_id': familyId,
        'task_id': taskId,
        'student_id': studentId,
        'status': 'pending',
        'submission_method': photoUrl != null ? 'photo_uploaded' : 'called_parent_for_check',
        'photo_urls': photoUrl != null ? [photoUrl] : [],
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      return true;
    } catch (e) {
      print('[submitTask] Hata: $e');
      return false;
    }
  }

  /// İlk Kapar Görev Yarışını Kap
  static Future<bool> claimRaceTask(String taskId, String studentId) async {
    try {
      final res = await client
          .from('tasks')
          .update({'claimed_by': studentId})
          .eq('id', taskId)
          .isFilter('claimed_by', null);
      return true;
    } catch (e) {
      print('[claimRaceTask] Hata: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // HAFTALIK DERS PROGRAMI & ÇANTA KONTROLÜ
  // ---------------------------------------------------------------------------

  /// Belirli bir günün ders programını çek (1 = Pazartesi ... 7 = Pazar)
  static Future<DayScheduleModel?> fetchDaySchedule({
    required String userId,
    required int dayOfWeek,
  }) async {
    try {
      final res = await client
          .from('school_schedules')
          .select('*')
          .eq('user_id', userId)
          .eq('day_of_week', dayOfWeek)
          .limit(1);

      if (res.isNotEmpty) {
        return DayScheduleModel.fromJson(res.first);
      }
    } catch (e) {
      print('[fetchDaySchedule] Hata: $e');
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // HAZİNE KASASI (KUMBARA) VE ÖDÜL MARKETİ
  // ---------------------------------------------------------------------------

  /// Puanları Altın Kasaya (Kumbara) Aktar veya Kasadan Çek
  static Future<bool> transferToPiggyBank(String userId, int amount) async {
    try {
      final user = await fetchStudentProfile(userId);
      if (user == null) return false;

      if (amount > 0) {
        // Kasaya yatır
        if (user.pointsBalance < amount) return false;
        await client.from('users').update({
          'points_balance': user.pointsBalance - amount,
          'piggy_bank_balance': user.piggyBankBalance + amount,
        }).eq('id', userId);
      } else {
        // Kasadan çek
        final withdraw = amount.abs();
        if (user.piggyBankBalance < withdraw) return false;
        await client.from('users').update({
          'points_balance': user.pointsBalance + withdraw,
          'piggy_bank_balance': user.piggyBankBalance - withdraw,
        }).eq('id', userId);
      }

      return true;
    } catch (e) {
      print('[transferToPiggyBank] Hata: $e');
      return false;
    }
  }

  static Future<bool> transferPointsToPiggyBank({
    required String userId,
    required int amount,
  }) async {
    return transferToPiggyBank(userId, amount);
  }

  /// Ödül Marketindeki Ürünleri Çek
  static Future<List<RewardModel>> fetchRewards(String familyId) async {
    try {
      final res = await client
          .from('rewards')
          .select('*')
          .eq('family_id', familyId)
          .eq('is_available', true)
          .order('points_cost', ascending: true);

      return res.map((r) => RewardModel.fromJson(r)).toList();
    } catch (e) {
      print('[fetchRewards] Hata: $e');
      return [];
    }
  }

  static Future<List<RewardModel>> getRewards(String familyId) => fetchRewards(familyId);

  /// Ödül Satın Al (Talebi Ebeveyne İlet)
  static Future<bool> redeemReward({
    String? familyId,
    required String studentId,
    required String rewardId,
    int? cost,
    int? pointsCost,
  }) async {
    final finalCost = cost ?? pointsCost ?? 0;
    try {
      final user = await fetchStudentProfile(studentId);
      if (user == null || user.pointsBalance < finalCost) return false;

      final targetFamilyId = familyId ?? user.familyId;

      // Puanı düş
      await client.from('users').update({
        'points_balance': user.pointsBalance - finalCost,
      }).eq('id', studentId);

      // Talep oluştur
      await client.from('reward_redemptions').insert({
        'family_id': targetFamilyId,
        'user_id': studentId,
        'reward_id': rewardId,
        'points_spent': finalCost,
        'status': 'pending',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });

      return true;
    } catch (e) {
      print('[redeemReward] Hata: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // BAS-KONUŞ AİLE TELSİZİ VE ADALET DİVANI İTİRAZI
  // ---------------------------------------------------------------------------

  /// Telsiz Mesajlarını Çek
  static Future<List<MessageModel>> fetchMessages(String familyId, [String? userId]) async {
    try {
      var query = client
          .from('messages')
          .select('*')
          .eq('family_id', familyId);

      if (userId != null && userId.isNotEmpty) {
        query = query.or('receiver_id.eq.$userId,receiver_id.eq.all,sender_id.eq.$userId');
      }

      final res = await query.order('created_at', ascending: true).limit(50);
      return res.map((m) => MessageModel.fromJson(m)).toList();
    } catch (e) {
      print('[fetchMessages] Hata: $e');
      return [];
    }
  }

  static Future<List<MessageModel>> getMessages(String familyId) =>
      fetchMessages(familyId, SessionManager.userId);

  /// Telsiz Mesajı Gönder
  static Future<bool> sendMessage({
    required String familyId,
    required String senderId,
    required String senderName,
    String receiverId = 'all',
    required String content,
  }) async {
    try {
      await client.from('messages').insert({
        'family_id': familyId,
        'sender_id': senderId,
        'sender_name': senderName,
        'receiver_id': receiverId,
        'content': content,
        'is_read': false,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      return true;
    } catch (e) {
      print('[sendMessage] Hata: $e');
      return false;
    }
  }

  /// Adalet Divanına (Hakem Heyetine) İtiraz Gönder
  static Future<bool> submitAppeal({
    required String familyId,
    required String studentId,
    String studentName = '',
    String title = '',
    String? reason,
    String? reasonText,
  }) async {
    try {
      final text = reason ?? reasonText ?? title;
      final fullReason = title.isNotEmpty && text != title ? '[$title] $text' : text;

      await client.from('appeals').insert({
        'family_id': familyId,
        'user_id': studentId,
        'student_name': studentName.isNotEmpty ? studentName : SessionManager.userName,
        'reason_text': fullReason,
        'status': 'pending',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      return true;
    } catch (e) {
      print('[submitAppeal] Hata: $e');
      return false;
    }
  }

  /// Sabah Uyanma Alarmını Kapat ve Durumu Güncelle
  static Future<bool> dismissWakeUpAlarm(String studentId) async {
    try {
      await client.from('users').update({
        'current_state': 'FREE_TIME',
      }).eq('id', studentId);
      return true;
    } catch (e) {
      print('[dismissWakeUpAlarm] Hata: $e');
      return false;
    }
  }

  /// Ders Saatinde Uygulamayı Alta Atma / Kaçış İhlali
  static Future<void> reportAppMinimizedViolation() async {
    if (!SessionManager.isStudent || !SessionManager.isStudying) return;

    try {
      await client.from('violation_logs').insert({
        'family_id': SessionManager.familyId,
        'user_id': SessionManager.userId,
        'violation_type': 'ios_app_minimized',
        'details': 'Öğrenci iOS uygulamasından çıktı veya başka uygulamaya geçti',
        'occurred_at': DateTime.now().toUtc().toIso8601String(),
      });

      NotificationService.showAppMinimizedWarning();
    } catch (e) {
      print('[SupabaseService] İhlal gönderme hatası: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // EBEVEYN (FAMILY-TO-STUDY FAM) YÖNETİM METOTLARI
  // ---------------------------------------------------------------------------

  /// Ailedeki Çocukları / Öğrencileri Çek
  static Future<List<UserModel>> fetchFamilyChildren(String familyId) async {
    try {
      final res = await client
          .from('users')
          .select('*')
          .eq('family_id', familyId)
          .eq('role', 'child');

      return res.map((u) => UserModel.fromJson(u)).toList();
    } catch (e) {
      print('[fetchFamilyChildren] Hata: $e');
      return [];
    }
  }

  /// Çocuğun Durumunu Değiştir (Ders, Rutin, Serbest, Sabah Alarmı)
  static Future<bool> setChildState({
    required String studentId,
    required String newState,
    int? durationMinutes,
  }) async {
    try {
      final Map<String, dynamic> updateData = {
        'current_state': newState,
      };

      if (durationMinutes != null && durationMinutes > 0) {
        updateData['state_ends_at'] = DateTime.now()
            .add(Duration(minutes: durationMinutes))
            .toUtc()
            .toIso8601String();
      } else {
        updateData['state_ends_at'] = null;
      }

      await client.from('users').update(updateData).eq('id', studentId);
      return true;
    } catch (e) {
      print('[setChildState] Hata: $e');
      return false;
    }
  }

  /// Çocuğun Günlük Kalkanını Güncelle (+1 Kalkan Ekle veya Düşür)
  static Future<bool> updateChildShields(String studentId, int delta) async {
    try {
      final user = await fetchStudentProfile(studentId);
      if (user == null) return false;

      final newShields = (user.dailyShields + delta).clamp(0, 3);
      await client.from('users').update({
        'daily_shields': newShields,
      }).eq('id', studentId);

      return true;
    } catch (e) {
      print('[updateChildShields] Hata: $e');
      return false;
    }
  }

  /// Onay Bekleyen Görev Teslimatlarını Çek
  static Future<List<SubmissionModel>> fetchPendingSubmissions(String familyId) async {
    try {
      final subs = await client
          .from('task_submissions')
          .select('*, tasks(title, points), users(name)')
          .eq('family_id', familyId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      return subs.map((s) {
        final task = s['tasks'] as Map<String, dynamic>? ?? {};
        final user = s['users'] as Map<String, dynamic>? ?? {};
        return SubmissionModel.fromJson(
          s,
          taskTitle: task['title']?.toString() ?? 'Görev',
          studentName: user['name']?.toString() ?? 'Öğrenci',
          points: task['points'] is int ? task['points'] : 10,
        );
      }).toList();
    } catch (e) {
      print('[fetchPendingSubmissions] Hata: $e');
      return [];
    }
  }

  /// Görev Teslimatını İncele (Onayla & Puan Ver veya Reddet)
  static Future<bool> reviewSubmission({
    required String submissionId,
    required String studentId,
    required int points,
    required bool approve,
    String? reviewerId,
  }) async {
    try {
      if (approve) {
        // Öğrenciye puanı ver
        final user = await fetchStudentProfile(studentId);
        if (user != null) {
          await client.from('users').update({
            'points_balance': user.pointsBalance + points,
          }).eq('id', studentId);
        }

        // Teslimatı onaylandı yap
        await client.from('task_submissions').update({
          'status': 'approved',
          'approved_by': reviewerId ?? SessionManager.userId,
        }).eq('id', submissionId);
      } else {
        // Reddet
        await client.from('task_submissions').update({
          'status': 'rejected',
          'approved_by': reviewerId ?? SessionManager.userId,
        }).eq('id', submissionId);
      }

      return true;
    } catch (e) {
      print('[reviewSubmission] Hata: $e');
      return false;
    }
  }

  /// Adalet Divanındaki Bekleyen İtirazları Çek
  static Future<List<AppealModel>> fetchPendingAppeals(String familyId) async {
    try {
      final res = await client
          .from('appeals')
          .select('*, users(name)')
          .eq('family_id', familyId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      return res.map((a) {
        final user = a['users'] as Map<String, dynamic>? ?? {};
        return AppealModel.fromJson(
          a,
          studentName: user['name']?.toString() ?? a['student_name']?.toString() ?? 'Öğrenci',
        );
      }).toList();
    } catch (e) {
      print('[fetchPendingAppeals] Hata: $e');
      return [];
    }
  }

  /// İtirazı Değerlendir (Kabul Et & Kalkanı İade Et veya Reddet)
  static Future<bool> reviewAppeal({
    required String appealId,
    required String studentId,
    required bool approve,
    String? reviewerId,
  }) async {
    try {
      if (approve) {
        // Kalkanı iade et (+1)
        await updateChildShields(studentId, 1);
        await client.from('appeals').update({
          'status': 'accepted',
          'reviewed_by': reviewerId ?? SessionManager.userId,
        }).eq('id', appealId);
      } else {
        await client.from('appeals').update({
          'status': 'rejected',
          'reviewed_by': reviewerId ?? SessionManager.userId,
        }).eq('id', appealId);
      }

      return true;
    } catch (e) {
      print('[reviewAppeal] Hata: $e');
      return false;
    }
  }

  /// Onay Bekleyen Ödül Taleplerini Çek
  static Future<List<RedemptionModel>> fetchPendingRedemptions(String familyId) async {
    try {
      final res = await client
          .from('reward_redemptions')
          .select('*, rewards(title), users(name)')
          .eq('family_id', familyId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      return res.map((r) {
        final rew = r['rewards'] as Map<String, dynamic>? ?? {};
        final user = r['users'] as Map<String, dynamic>? ?? {};
        return RedemptionModel.fromJson(
          r,
          rewardTitle: rew['title']?.toString() ?? 'Ödül',
          studentName: user['name']?.toString() ?? 'Öğrenci',
        );
      }).toList();
    } catch (e) {
      print('[fetchPendingRedemptions] Hata: $e');
      return [];
    }
  }

  /// Ödül Talebini Onayla (Fiziksel Olarak Verildi)
  static Future<bool> reviewRedemption({
    required String redemptionId,
    required bool approve,
    String? reviewerId,
  }) async {
    try {
      await client.from('reward_redemptions').update({
        'status': approve ? 'approved' : 'rejected',
        'approved_by': reviewerId ?? SessionManager.userId,
      }).eq('id', redemptionId);

      return true;
    } catch (e) {
      print('[reviewRedemption] Hata: $e');
      return false;
    }
  }

  /// Yeni Görev / İlk-Kapar Yarışı Oluştur
  static Future<bool> createNewTask({
    required String familyId,
    required String title,
    String description = '',
    required int points,
    required String category,
    String assignedTo = 'both',
    bool isRace = false,
    bool requiresPhoto = false,
  }) async {
    try {
      await client.from('tasks').insert({
        'family_id': familyId,
        'title': title,
        'description': description,
        'points': points,
        'category': category,
        'assigned_to': assignedTo,
        'is_active': true,
        'requires_photo': requiresPhoto,
        'is_first_come_race': isRace,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });

      return true;
    } catch (e) {
      print('[createNewTask] Hata: $e');
      return false;
    }
  }
}
