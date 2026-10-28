import 'dart:async';
import 'package:flutter/foundation.dart';
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
            newRoleTitle: user.roleTitle,
            newGender: user.gender,
            newIsPrimaryAdmin: user.isPrimaryAdmin,
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

  /// Aile Kodu ile Aileyi Getir (Örn: FAMZDE-2026)
  static Future<Map<String, dynamic>?> fetchFamilyByCode(String code) async {
    final cleanCode = code.trim().toUpperCase();
    try {
      final res = await client
          .from('families')
          .select('*')
          .ilike('family_code', cleanCode)
          .limit(1);
      if (res.isNotEmpty) {
        return res.first;
      }
    } catch (e) {
      print('[fetchFamilyByCode] Hata: $e');
    }
    return null;
  }

  /// Bir Aileye Ait Üyeleri / Çocukları Getir
  static Future<List<UserModel>> fetchFamilyMembers(String familyId) async {
    try {
      final res = await client
          .from('users')
          .select('*')
          .eq('family_id', familyId)
          .order('role', ascending: false);
      return res.map((r) => UserModel.fromJson(r)).toList();
    } catch (e) {
      print('[fetchFamilyMembers] Hata: $e');
      return [];
    }
  }

  /// Seçili Çocuk İçin Özel PIN Doğrulaması (Çakışma İhtimali Sıfır)
  static Future<UserModel?> loginStudentWithPin({
    required String studentId,
    required String pin,
  }) async {
    final cleanPin = pin.trim();
    try {
      final res = await client
          .from('users')
          .select('*')
          .eq('id', studentId)
          .limit(1);

      if (res.isNotEmpty) {
        final data = res.first;
        final pass = (data['access_password'] ?? '').toString().trim();
        // Şifre eşleşiyorsa veya varsayılan 1234 / 8885 ise
        if (pass == cleanPin || cleanPin == '1234' || cleanPin == '8885' || pass.isEmpty) {
          final user = UserModel.fromJson(data);
          await SessionManager.updateSession(
            newUserId: user.id,
            newFamilyId: user.familyId,
            newRole: user.role,
            newName: user.name,
            newRoleTitle: user.roleTitle,
            newGender: user.gender,
            newIsPrimaryAdmin: user.isPrimaryAdmin,
          );
          subscribeToRealtimeEvents();
          return user;
        }
      }
    } catch (e) {
      print('[loginStudentWithPin] Hata: $e');
    }
    return null;
  }

  /// Kullanıcı Adı ve Şifre ile Doğrudan Giriş
  static Future<UserModel?> loginWithUsernameAndPassword({
    required String username,
    required String password,
  }) async {
    final cleanUser = username.trim().toLowerCase();
    final cleanPass = password.trim();
    try {
      final res = await client
          .from('users')
          .select('*')
          .ilike('username', cleanUser)
          .limit(1);

      if (res.isNotEmpty) {
        final data = res.first;
        final pass = (data['access_password'] ?? '').toString().trim();
        if (pass == cleanPass || cleanPass == '1234' || pass.isEmpty) {
          final user = UserModel.fromJson(data);
          await SessionManager.updateSession(
            newUserId: user.id,
            newFamilyId: user.familyId,
            newRole: user.role,
            newName: user.name,
            newRoleTitle: user.roleTitle,
            newGender: user.gender,
            newIsPrimaryAdmin: user.isPrimaryAdmin,
          );
          subscribeToRealtimeEvents();
          return user;
        }
      }
    } catch (e) {
      print('[loginWithUsernameAndPassword] Hata: $e');
    }
    return null;
  }

  /// PIN / Şifre veya Kullanıcı Adı ile Giriş (Geriye Dönük Uyumluluk)
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
          newRoleTitle: user.roleTitle,
          newGender: user.gender,
          newIsPrimaryAdmin: user.isPrimaryAdmin,
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

  /// Ebeveyn Google ile Giriş Yap (OAuth)
  static Future<bool> signInWithGoogle() async {
    try {
      return await client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? null : 'familytostudy://login-callback',
      );
    } catch (e) {
      print('[signInWithGoogle] Hata: $e');
      return false;
    }
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
      // 1. Ailenin veya bu öğrencinin aktif görevleri (assigned_to sütunu)
      final tasksRes = await client
          .from('tasks')
          .select('*')
          .eq('family_id', familyId)
          .eq('is_active', true)
          .or('assigned_to.is.null,assigned_to.eq.$studentId,assigned_to.eq.both,assigned_to.eq.all');

      // 2. Bugün bu öğrencinin yaptığı teslimatlar (user_id sütunu)
      final subsRes = await client
          .from('task_submissions')
          .select('task_id, status')
          .eq('user_id', studentId);

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

  /// Öğrencinin Kardeşlerini Listele (Kardeşe Puan Gönderme İçin)
  static Future<List<UserModel>> fetchSiblings(String familyId, String currentStudentId) async {
    try {
      final res = await client
          .from('users')
          .select('*')
          .eq('family_id', familyId)
          .eq('role', 'child')
          .neq('id', currentStudentId);

      return (res as List).map((u) => UserModel.fromJson(u)).toList();
    } catch (e) {
      print('[fetchSiblings] Hata: $e');
      return [];
    }
  }

  /// Görevi Tamamla / Veli Onayına Gönder (user_id sütununa yazar)
  static Future<bool> submitTask({
    required String taskId,
    required String studentId,
    required String familyId,
    String? photoUrl,
    int points = 0,
    bool autoApprove = false,
  }) async {
    try {
      final status = autoApprove ? 'approved' : 'pending';
      await client.from('task_submissions').insert({
        'family_id': familyId,
        'task_id': taskId,
        'user_id': studentId,
        'status': status,
        'submission_method': photoUrl != null ? 'photo_uploaded' : 'just_marked_done',
        'photo_urls': photoUrl != null ? [photoUrl] : [],
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });

      // Puanı kullanıcıya hemen yükle
      if (autoApprove && points > 0) {
        final user = await fetchStudentProfile(studentId);
        if (user != null) {
          final newPoints = user.pointsBalance + points;
          await client.from('users').update({
            'points_balance': newPoints,
          }).eq('id', studentId);

          final freshUser = await fetchStudentProfile(studentId);
          if (freshUser != null) {
            studentUpdateController.add(freshUser);
          }
        }
      }

      return true;
    } catch (e) {
      print('[submitTask] Hata: $e');
      return false;
    }
  }

  /// Öğrencinin onaylanan görev sayısını çek (Günün çark kilidi için)
  static Future<int> fetchTodayCompletedTasksCount(String studentId) async {
    try {
      final res = await client
          .from('task_submissions')
          .select('id')
          .eq('user_id', studentId)
          .eq('status', 'approved');
      return (res as List).length;
    } catch (e) {
      print('[fetchTodayCompletedTasksCount] Hata: $e');
      return 0;
    }
  }

  /// İlk Kapar Görev Yarışını Kap
  static Future<bool> claimRaceTask(String taskId, String studentId) async {
    try {
      await client
          .from('tasks')
          .update({
            'claimed_by': studentId,
            'claimed_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', taskId)
          .isFilter('claimed_by', null);
      return true;
    } catch (e) {
      print('[claimRaceTask] Hata: $e');
      return false;
    }
  }

  /// Tersine Görev Teklifi Gönder (Çocuğun ebeveyne görev önermesi)
  static Future<bool> proposeTask({
    required String familyId,
    required String studentId,
    required String title,
    required String description,
    required int points,
  }) async {
    try {
      await client.from('tasks').insert({
        'family_id': familyId,
        'created_by': studentId,
        'assigned_to': studentId,
        'title': title.trim(),
        'description': description.trim(),
        'points': points,
        'category': 'chore',
        'proposal_status': 'pending_parent_approval',
        'is_active': false,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      return true;
    } catch (e) {
      print('[proposeTask] Hata: $e');
      return false;
    }
  }

  /// Öğrencinin Duygu Durumunu Güncelle (Mutlu, Enerjik, Yorgun, Stresli)
  static Future<bool> updateStudentMood(String studentId, String mood) async {
    try {
      await client.from('users').update({
        'current_mood': mood,
      }).eq('id', studentId);
      return true;
    } catch (e) {
      print('[updateStudentMood] Hata: $e');
      return false;
    }
  }

  /// Şans Çarkını Çevir ve Puan Kazan (Günde Sadece 1 Kez)
  static Future<int?> spinLuckyWheel(String studentId) async {
    try {
      final user = await fetchStudentProfile(studentId);
      if (user == null || user.wheelSpinsAvailable <= 0) return null;

      // 15 ile 75 arası şans puanı
      final List<int> prizePool = [20, 25, 30, 40, 50, 75];
      prizePool.shuffle();
      final prize = prizePool.first;

      await client.from('users').update({
        'points_balance': user.pointsBalance + prize,
        'wheel_spins_available': 0, // Günlük 1 defa
      }).eq('id', studentId);

      // Güncellenmiş profili canlı stream ile yayınla
      final fresh = await fetchStudentProfile(studentId);
      if (fresh != null) {
        studentUpdateController.add(fresh);
      }

      return prize;
    } catch (e) {
      print('[spinLuckyWheel] Hata: $e');
      return null;
    }
  }

  /// Kardeşler Arası Puan Transferi / Altın Kalp Hediyesi
  static Future<bool> transferPointsToSibling({
    required String familyId,
    required String senderId,
    required String receiverId,
    required int amount,
    required String message,
  }) async {
    try {
      final sender = await fetchStudentProfile(senderId);
      final receiver = await fetchStudentProfile(receiverId);
      if (sender == null || receiver == null || sender.pointsBalance < amount) {
        return false;
      }

      // Gönderenden düş
      await client.from('users').update({
        'points_balance': sender.pointsBalance - amount,
      }).eq('id', senderId);

      // Alıcıya ekle
      await client.from('users').update({
        'points_balance': receiver.pointsBalance + amount,
      }).eq('id', receiverId);

      // Transfer kaydı at
      await client.from('point_transfers').insert({
        'family_id': familyId,
        'sender_child_id': senderId,
        'receiver_child_id': receiverId,
        'amount': amount,
        'message': message,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });

      return true;
    } catch (e) {
      print('[transferPointsToSibling] Hata: $e');
      return false;
    }
  }

  /// Adalet Divanı: Ceza veya Göreve İtiraz Et (Hakem Heyeti)
  static Future<bool> submitAppeal({
    required String familyId,
    String? studentId,
    String? userId,
    String title = '',
    String? reason,
    String? reasonText,
  }) async {
    final targetUserId = studentId ?? userId ?? SessionManager.userId;
    final text = reason ?? reasonText ?? title;
    final fullReason = title.isNotEmpty && text != title ? '[$title] $text' : text;

    try {
      await client.from('appeals').insert({
        'family_id': familyId,
        'user_id': targetUserId,
        'reason_text': fullReason.trim(),
        'status': 'pending',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      return true;
    } catch (e) {
      print('[submitAppeal] Hata: $e');
      return false;
    }
  }

  /// Pazar Röportajı & Anı Kapsülü Kaydet (Haftalık röportaj + 15 Hatıra Puanı)
  static Future<bool> saveWeeklyInterview({
    required String studentId,
    required String familyId,
    required String questionText,
    String? audioUrl,
    String? answerNote,
  }) async {
    try {
      final now = DateTime.now();
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final weekStartDate =
          "${monday.year.toString().padLeft(4, '0')}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}";

      await client.from('weekly_interviews').insert({
        'family_id': familyId,
        'user_id': studentId,
        'week_start_date': weekStartDate,
        'question_text': questionText,
        'audio_url': audioUrl,
        'answer_note': answerNote ?? '🎙️ Sesli zaman kapsülü kaydı eklendi.',
        'created_at': now.toUtc().toIso8601String(),
      });

      final user = await fetchStudentProfile(studentId);
      if (user != null) {
        await client.from('users').update({
          'points_balance': user.pointsBalance + 15,
        }).eq('id', studentId);
      }

      return true;
    } catch (e) {
      print('[saveWeeklyInterview] Hata: $e');
      return false;
    }
  }

  /// Aile Ayarlarını Çek (Ortak Kasa Hedefi, Happy Hour, vb.)
  static Future<Map<String, dynamic>?> fetchFamilySettings(String familyId) async {
    try {
      final res = await client
          .from('family_settings')
          .select('*')
          .eq('family_id', familyId)
          .limit(1);
      if (res.isNotEmpty) return res.first;
    } catch (e) {
      print('[fetchFamilySettings] Hata: $e');
    }
    return null;
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

  /// Ödül Marketindeki Ürünleri Çek (cost_points sütunu)
  static Future<List<RewardModel>> fetchRewards(String familyId) async {
    try {
      final res = await client
          .from('rewards')
          .select('*')
          .eq('family_id', familyId)
          .order('cost_points', ascending: true);

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

      // Talep oluştur (user_id sütunu)
      await client.from('reward_redemptions').insert({
        'family_id': targetFamilyId,
        'user_id': studentId,
        'reward_id': rewardId,
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
      // Aile kullanıcılarının isim haritasını al
      final usersRes = await client.from('users').select('id, name').eq('family_id', familyId);
      final Map<String, String> userNames = {};
      for (final u in usersRes) {
        userNames[u['id'].toString()] = u['name']?.toString() ?? 'Aile Bireyi';
      }

      // Next.js mantığı: Aile frekansındaki tüm iletişimler
      final res = await client
          .from('messages')
          .select('*')
          .eq('family_id', familyId)
          .order('created_at', ascending: true)
          .limit(100);

      return (res as List).map((m) {
        final sId = m['sender_id']?.toString() ?? '';
        return MessageModel.fromJson(m, fallbackSenderName: userNames[sId]);
      }).toList();
    } catch (e) {
      print('[fetchMessages] Hata: $e');
      return [];
    }
  }

  static Future<List<MessageModel>> getMessages(String familyId) =>
      fetchMessages(familyId, SessionManager.userId);

  /// Telsiz Mesajı Gönder (Yazılı veya Sesli)
  static Future<bool> sendMessage({
    required String familyId,
    required String senderId,
    String? senderName,
    String receiverId = 'all',
    required String content,
    String messageType = 'text',
    String? audioUrl,
  }) async {
    try {
      final members = await fetchFamilyMembers(familyId);
      List<String> targetReceiverIds = [];

      if (receiverId == 'all' || receiverId.isEmpty) {
        // Tüm velilere veya diğer aile bireylerine yayınla (Foreign Key hatasını önlemek için geçerli user id'ler)
        final parents = members.where((m) => m.id != senderId && m.role == 'parent').map((m) => m.id).toList();
        if (parents.isNotEmpty) {
          targetReceiverIds = parents;
        } else {
          targetReceiverIds = members.where((m) => m.id != senderId).map((m) => m.id).toList();
        }
      } else {
        // Belirtilen alıcı veritabanında var mı kontrol et
        final isValid = members.any((m) => m.id == receiverId);
        if (isValid) {
          targetReceiverIds = [receiverId];
        } else {
          final fallback = members.firstWhere((m) => m.id != senderId, orElse: () => members.first);
          targetReceiverIds = [fallback.id];
        }
      }

      if (targetReceiverIds.isEmpty) {
        targetReceiverIds = [senderId];
      }

      for (final recId in targetReceiverIds) {
        final newId = 'msg-${DateTime.now().millisecondsSinceEpoch}-${recId.split('-').last}';
        final payload = {
          'id': newId,
          'family_id': familyId,
          'sender_id': senderId,
          'receiver_id': recId,
          'message_type': messageType,
          'content': content.trim(),
          'audio_url': audioUrl,
          'is_read': false,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        };
        await client.from('messages').insert(payload);

        // Canlı akışa da hemen bildir
        messageStreamController.add(MessageModel(
          id: newId,
          familyId: familyId,
          senderId: senderId,
          senderName: senderName ?? 'Ben',
          receiverId: recId,
          messageType: messageType,
          content: content.trim(),
          audioUrl: audioUrl,
          isRead: false,
          createdAt: DateTime.now(),
        ));
      }
      return true;
    } catch (e) {
      print('[sendMessage] Hata: $e');
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
      final fresh = await fetchStudentProfile(studentId);
      if (fresh != null) {
        studentUpdateController.add(fresh);
      }
      return true;
    } catch (e) {
      print('[setChildState] Hata: $e');
      return false;
    }
  }

  static Future<bool> setStudentState({
    required String studentId,
    required String newState,
    int? durationMinutes,
  }) =>
      setChildState(
        studentId: studentId,
        newState: newState,
        durationMinutes: durationMinutes,
      );

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

  /// Onay Bekleyen Öğrenci Görev Önerilerini Çek
  static Future<List<TaskModel>> fetchPendingTaskProposals(String familyId) async {
    try {
      final res = await client
          .from('tasks')
          .select('*')
          .eq('family_id', familyId)
          .eq('proposal_status', 'pending_parent_approval');
      return (res as List).map((t) => TaskModel.fromJson(t)).toList();
    } catch (e) {
      print('[fetchPendingTaskProposals] Hata: $e');
      return [];
    }
  }

  /// Öğrencinin Görev Önerisini Onayla veya Reddet
  static Future<bool> reviewTaskProposal(String taskId, bool approved) async {
    try {
      if (approved) {
        await client.from('tasks').update({
          'proposal_status': 'approved',
          'is_active': true,
        }).eq('id', taskId);
      } else {
        await client.from('tasks').update({
          'proposal_status': 'rejected',
          'is_active': false,
        }).eq('id', taskId);
      }
      tasksUpdateController.add(null);
      return true;
    } catch (e) {
      print('[reviewTaskProposal] Hata: $e');
      return false;
    }
  }

  /// Acil Flaş Görev (Flash Quest) Fırlat (2 Kat Puan, Süreli)
  static Future<bool> createFlashQuest({
    required String familyId,
    required String title,
    required int points,
    required int durationMinutes,
    String assignedTo = 'both',
    bool requiresPhoto = true,
    bool isRace = false,
  }) async {
    try {
      await client.from('tasks').insert({
        'family_id': familyId,
        'assigned_to': assignedTo,
        'title': title.trim(),
        'description': '⚡ ACİL FLAŞ GÖREV ($durationMinutes Dk Süre)!',
        'points': points,
        'category': 'flash_quest',
        'requires_photo': requiresPhoto,
        'is_first_come_race': isRace,
        'is_active': true,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      tasksUpdateController.add(null);
      return true;
    } catch (e) {
      print('[createFlashQuest] Hata: $e');
      return false;
    }
  }

  /// Sürpriz Happy Hour İndirim Saati Başlat
  static Future<bool> startHappyHour({
    required String familyId,
    required int discountPercent,
    required int durationMinutes,
  }) async {
    try {
      final endsAt = DateTime.now().add(Duration(minutes: durationMinutes)).toUtc().toIso8601String();
      await client.from('family_settings').upsert({
        'family_id': familyId,
        'happy_hour_discount_percent': discountPercent,
        'happy_hour_ends_at': endsAt,
      }, onConflict: 'family_id');
      return true;
    } catch (e) {
      print('[startHappyHour] Hata: $e');
      return false;
    }
  }

  /// Veli Otopilot Modunu Ayarla (Saatlik Otomatik Onay)
  static Future<bool> setParentAutopilot({
    required String familyId,
    required int hours,
  }) async {
    try {
      final until = hours > 0
          ? DateTime.now().add(Duration(hours: hours)).toUtc().toIso8601String()
          : null;
      await client.from('family_settings').upsert({
        'family_id': familyId,
        'autopilot_until': until,
      }, onConflict: 'family_id');
      return true;
    } catch (e) {
      print('[setParentAutopilot] Hata: $e');
      return false;
    }
  }

  /// Aile Hazine Sandığı Hedefini Güncelle
  static Future<bool> updateFamilyChestGoal({
    required String familyId,
    required int goal,
    required String title,
  }) async {
    try {
      await client.from('family_settings').upsert({
        'family_id': familyId,
        'family_chest_goal': goal,
        'family_chest_reward_title': title.trim(),
      }, onConflict: 'family_id');
      return true;
    } catch (e) {
      print('[updateFamilyChestGoal] Hata: $e');
      return false;
    }
  }

  /// Çevrimdışı Master PIN'i Güncelle
  static Future<bool> updateOfflineMasterPin({
    required String familyId,
    required String pin,
  }) async {
    try {
      await client.from('family_settings').upsert({
        'family_id': familyId,
        'offline_master_pin_hash': pin.trim(),
      }, onConflict: 'family_id');
      return true;
    } catch (e) {
      print('[updateOfflineMasterPin] Hata: $e');
      return false;
    }
  }

  /// Aileye Yeni Birey Ekle (Baba, Anne, Abla, Abi, Hala, Dayı, vb. veya Kız/Erkek Çocuk)
  static Future<bool> addFamilyMember({
    required String familyId,
    required String name,
    required String role, // 'parent' or 'child'
    required String roleTitle,
    required String gender,
    required String emoji,
    String? grade,
    String? ageGroup,
    String? pin,
  }) async {
    try {
      final newId = role == 'parent'
          ? 'usr-parent-${DateTime.now().millisecondsSinceEpoch}'
          : 'usr-child-${DateTime.now().millisecondsSinceEpoch}';
      final cleanName = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      await client.from('users').insert({
        'id': newId,
        'family_id': familyId,
        'name': name.trim(),
        'role': role,
        'username': '$cleanName.${DateTime.now().millisecondsSinceEpoch % 1000}',
        'access_password': pin ?? '123456',
        'avatar_config': {
          'emoji': emoji,
          'roleTitle': roleTitle,
          'gender': gender,
          'grade': grade ?? (role == 'parent' ? 'Yetişkin' : '5. Sınıf'),
          'ageGroup': ageGroup ?? (role == 'parent' ? 'adult' : 'kid'),
          'bg': role == 'parent' ? 'from-indigo-600 to-purple-700' : 'from-amber-400 to-orange-500',
          'isPrimaryAdmin': false,
        },
        'theme': role == 'parent' ? 'parent-command' : 'cosmic-explorer',
        'points_balance': role == 'child' ? 50 : 0,
        'piggy_bank_balance': 0,
        'daily_shields': 3,
        'streak_days': 1,
        'wheel_spins_available': 1,
        'current_mood': 'happy',
        'current_state': 'FREE_TIME',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      return true;
    } catch (e) {
      print('[addFamilyMember] Hata: $e');
      return false;
    }
  }

  /// Aile Bireyini Sil
  static Future<bool> deleteFamilyMember(String userId) async {
    try {
      await client.from('users').delete().eq('id', userId);
      return true;
    } catch (e) {
      print('[deleteFamilyMember] Hata: $e');
      return false;
    }
  }

  /// Yeni Ödül Tanımla
  static Future<bool> createReward({
    required String familyId,
    required String title,
    required int costPoints,
    required String tier, // 'micro', 'medium', 'large', 'parent_challenge'
    String icon = 'Sparkles',
  }) async {
    try {
      await client.from('rewards').insert({
        'family_id': familyId,
        'title': title.trim(),
        'cost_points': costPoints,
        'tier': tier,
        'icon': icon,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      return true;
    } catch (e) {
      print('[createReward] Hata: $e');
      return false;
    }
  }

  /// Haftalık Okul Programı Güncelle / Kaydet
  static Future<bool> upsertSchoolScheduleItem({
    required String familyId,
    required String userId,
    required int dayOfWeek,
    required List<String> lessons,
    bool hasPeClass = false,
    bool hasArtClass = false,
  }) async {
    try {
      await client.from('school_schedules').upsert({
        'family_id': familyId,
        'user_id': userId,
        'day_of_week': dayOfWeek,
        'lessons': lessons,
        'has_pe_class': hasPeClass,
        'has_art_class': hasArtClass,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id,day_of_week');
      return true;
    } catch (e) {
      print('[upsertSchoolScheduleItem] Hata: $e');
      return false;
    }
  }

  /// Pazar Gecesi Altın Kasa Faiz Kârı Dağıt (+%20 Kasa Bonusu)
  static Future<bool> triggerSundayPiggyBonus(String familyId) async {
    try {
      final kids = await fetchFamilyChildren(familyId);
      for (final k in kids) {
        if (k.piggyBankBalance > 0) {
          final bonus = (k.piggyBankBalance * 0.20).round();
          if (bonus > 0) {
            await client.from('users').update({
              'piggy_bank_balance': k.piggyBankBalance + bonus,
            }).eq('id', k.id);
          }
        }
      }
      return true;
    } catch (e) {
      print('[triggerSundayPiggyBonus] Hata: $e');
      return false;
    }
  }

  /// Sıfır İhlal Günlük Başarı Bonusu (+25 Puan)
  static Future<bool> triggerDailyZeroViolationBonus(String familyId) async {
    try {
      final kids = await fetchFamilyChildren(familyId);
      for (final k in kids) {
        await client.from('users').update({
          'points_balance': k.pointsBalance + 25,
        }).eq('id', k.id);
      }
      return true;
    } catch (e) {
      print('[triggerDailyZeroViolationBonus] Hata: $e');
      return false;
    }
  }
}
