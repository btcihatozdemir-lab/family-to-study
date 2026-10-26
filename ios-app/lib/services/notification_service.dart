import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      defaultPresentAlert: true,
      defaultPresentBadge: true,
      defaultPresentSound: true,
    );

    const initSettings = InitializationSettings(
      iOS: darwinInit,
      macOS: darwinInit,
    );

    await _notifications.initialize(initSettings);

    // iOS 15.8+ & iOS 16/17/18 için izin isteme
    await _notifications
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? soundName,
    bool isUrgent = false,
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
  }

  // 1. İhlal Bildirimi (Veli için)
  static Future<void> showViolationAlert({
    required String studentName,
    required String reason,
  }) async {
    await showNotification(
      id: 101,
      title: '🚨 KALKAN İHLALİ: $studentName',
      body: '$studentName ders/odaklanma saatinde ihlal yaptı: $reason',
      isUrgent: true,
    );
  }

  // 2. Uygulamadan Çıkma / Minimize Uyarısı (Öğrenci için)
  static Future<void> showAppMinimizedWarning() async {
    await showNotification(
      id: 102,
      title: '🚨 DERS SAATİNDE UYGULAMADAN ÇIKTIN!',
      body: 'Kalkanının kırılmaması için hemen FamilyOS uygulamasına geri dön!',
      isUrgent: true,
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

  // 4. Görev Onay Bildirimi (Öğrenci için)
  static Future<void> showTaskApprovedAlert({
    required String taskTitle,
    required int points,
  }) async {
    await showNotification(
      id: 104,
      title: '🎉 Görevin Onaylandı!',
      body: '"$taskTitle" onaylandı! +$points Altın Puan kazandın.',
    );
  }

  // 5. Telsiz DM Sesli Mesaj Bildirimi
  static Future<void> showWalkieTalkieAlert({
    required String senderName,
    required String previewText,
  }) async {
    await showNotification(
      id: 105,
      title: '🎙️ Telsiz Mesajı: $senderName',
      body: previewText,
      isUrgent: true,
    );
  }

  // 6. Sabah Uyandırma Alarmı
  static Future<void> showWakeUpAlarm({
    required String message,
  }) async {
    await showNotification(
      id: 106,
      title: '⏰ GÜNAYDIN! UYANMA VAKTİ',
      body: message,
      isUrgent: true,
    );
  }

  // 7. Adalet Divanı İtiraz Bildirimi (Veli için)
  static Future<void> showAppealAlert({
    required String studentName,
    required String reason,
  }) async {
    await showNotification(
      id: 107,
      title: '⚖️ Adalet Divanı: $studentName İtiraz Etti',
      body: 'Gerekçe: "$reason". Karar vermeniz bekleniyor.',
      isUrgent: true,
    );
  }
}
