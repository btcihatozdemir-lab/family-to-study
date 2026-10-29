import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'tts_service.dart';
import 'supabase_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const MethodChannel _apnsChannel =
      MethodChannel('com.familytostudy.app/apns');

  static String? _cachedApnsToken;
  static String? get cachedApnsToken => _cachedApnsToken;

  static Future<void> init() async {
    try {
      const darwinInit = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
        defaultPresentAlert: true,
        defaultPresentBadge: true,
        defaultPresentSound: true,
      );

      const initSettings = InitializationSettings(
        iOS: darwinInit,
        macOS: darwinInit,
      );

      await _notifications.initialize(initSettings);

      // Native iOS APNs Kanal Dinleyicisi
      _apnsChannel.setMethodCallHandler((call) async {
        if (call.method == 'onApnsToken') {
          final token = call.arguments?.toString();
          if (token != null && token.isNotEmpty) {
            _cachedApnsToken = token;
            print('[NotificationService] APNs Token alındı: $token');
            await SupabaseService.registerDeviceApnsToken(token);
          }
        }
      });

      // TTS Servisini de hazırla
      await TTSService.init();
    } catch (e) {
      print('[NotificationService] Başlatma uyarısı: $e');
    }
  }

  /// Kullanıcı arayüzü ekrana geldikten sonra bildirim izinlerini güvenle talep eder
  static Future<void> requestPermissions() async {
    try {
      final granted = await _notifications
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );

      if (granted == true) {
        // Native APNs kaydını tetikle
        await _apnsChannel.invokeMethod('registerForRemoteNotifications');

        // Hafızada token varsa Supabase'e gönder
        final token = await _apnsChannel.invokeMethod<String>('getApnsToken');
        if (token != null && token.isNotEmpty) {
          _cachedApnsToken = token;
          await SupabaseService.registerDeviceApnsToken(token);
        }
      }
    } catch (e) {
      print('[NotificationService] İzin isteme uyarısı: $e');
    }
  }

  /// Çocuğu ürkütmeyen, nazik ve motive edici sesli anons (TTS)
  static Future<void> playGentleVoiceCue(String text) async {
    try {
      await TTSService.speak(text);
    } catch (e) {
      print('[NotificationService] Seslendirme uyarısı: $e');
    }
  }

  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? soundName,
    bool isUrgent = false,
    String? gentleVoiceText,
  }) async {
    final darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: isUrgent
          ? InterruptionLevel.timeSensitive
          : InterruptionLevel.active,
    );

    final details = NotificationDetails(
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await _notifications.show(id, title, body, details);

    // Çocuğu rahatsız etmeyen nazik seslendirme
    if (gentleVoiceText != null && gentleVoiceText.isNotEmpty) {
      playGentleVoiceCue(gentleVoiceText);
    }
  }

  // 1. İhlal Bildirimi (Veli için)
  static Future<void> showViolationAlert({
    required String studentName,
    required String reason,
  }) async {
    await showNotification(
      id: 101,
      title: '🚨 Kalkan Uyarısı: $studentName',
      body: '$studentName odaklanma saatinde işlem yaptı: $reason',
      isUrgent: true,
    );
  }

  // 2. Uygulamadan Çıkma / Minimize Uyarısı (Öğrenci için - Nazik Hatırlatma)
  static Future<void> showAppMinimizedWarning() async {
    await showNotification(
      id: 102,
      title: '🌟 Ders Saati Devam Ediyor',
      body: 'Kalkanını korumak ve puan kaybetmemek için haydi uygulamaya geri dön!',
      isUrgent: true,
      gentleVoiceText: 'Ders saatin devam ediyor, kalkanını korumak için uygulamaya dönelim.',
    );
  }

  // 3. Görev Teslim Bildirimi (Veli için)
  static Future<void> showTaskSubmissionAlert({
    required String studentName,
    required String taskTitle,
  }) async {
    await showNotification(
      id: 103,
      title: '📸 Yeni Görev Teslimi',
      body: '$studentName "$taskTitle" görevini tamamladı ve onaya sundu.',
    );
  }

  // 4. Görev Onay Bildirimi (Öğrenci için - Sevecen ve Coşkulu)
  static Future<void> showTaskApprovedAlert({
    required String taskTitle,
    required int points,
  }) async {
    await showNotification(
      id: 104,
      title: '🎉 Harikasın! Görevin Onaylandı',
      body: '"$taskTitle" onaylandı! +$points Altın Puan kazandın.',
      gentleVoiceText: 'Tebrikler! Görevin onaylandı, harika iş çıkardın!',
    );
  }

  // 5. Telsiz DM Sesli Mesaj Bildirimi
  static Future<void> showWalkieTalkieAlert({
    required String senderName,
    required String previewText,
  }) async {
    await showNotification(
      id: 105,
      title: '🎙️ Ailenden Mesaj: $senderName',
      body: previewText,
      isUrgent: true,
    );
  }

  // 6. Sabah Uyandırma Alarmı (Korkutucu Siren Yerine Neşeli & Tatlı Sesli Günaydın)
  static Future<void> showWakeUpAlarm({
    required String message,
  }) async {
    await showNotification(
      id: 106,
      title: '☀️ Günaydın! Yeni Bir Gün Başlıyor',
      body: message,
      isUrgent: true,
      gentleVoiceText: 'Günaydın! Yeni ve harika bir güne hazır mısın? Görevlerin seni bekliyor.',
    );
  }

  // 7. Mola Bitti Hatırlatması (Nazik Davet)
  static Future<void> showBreakFinishedAlert() async {
    await showNotification(
      id: 108,
      title: '🔔 Mola Tamamlandı',
      body: 'Dinlenme süresi bitti. Hazırsan odaklanma vaktine geçelim!',
      isUrgent: false,
      gentleVoiceText: 'Molan bitti, haydi tekrar derse odaklanalım.',
    );
  }

  // 8. Adalet Divanı İtiraz Bildirimi (Veli için)
  static Future<void> showAppealAlert({
    required String studentName,
    required String reason,
  }) async {
    await showNotification(
      id: 107,
      title: '⚖️ Adalet Divanı: $studentName İtiraz Etti',
      body: 'Gerekçe: "$reason". Değerlendirmeniz bekleniyor.',
      isUrgent: true,
    );
  }
}
