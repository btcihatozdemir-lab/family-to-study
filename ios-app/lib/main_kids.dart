import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/session_manager.dart';
import 'services/notification_service.dart';
import 'services/audio_keep_alive_service.dart';
import 'services/supabase_service.dart';
import 'models/user_model.dart';
import 'theme/kids_theme.dart';
import 'screens/kids/kids_auth_screen.dart';
import 'screens/kids/kids_home_screen.dart';

/// ===========================================================================
/// main_kids.dart - FAMILYTOSTUDY KIDS (ÖĞRENCİ & ÇOCUK ODAK VE GÖREV UYGULAMASI)
/// ===========================================================================
/// SOLID: Single Responsibility Principle (SRP)
/// Bu dosya ve uygulama YALNIZCA öğrenci / çocuk cihazları için derlenir.
/// Paket: com.familytostudy.kids
/// Logo: assets/images/kids_logo.png
/// ===========================================================================

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Tam Ekran Oyun & Odak Modu: Durum Çubuğunu Gizle
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // 1. Yerel Hafızayı Yükle
  await SessionManager.init();

  // 2. Kilit Ekranı Bildirim Motorunu Başlat
  await NotificationService.init();

  // 3. 7/24 Arka Plan Canlı Tutucu Sessiz Ses Motorunu Başlat
  await AudioKeepAliveService.startKeepAliveLoop();

  // 4. Supabase Realtime WebSocket Ağını Başlat
  await SupabaseService.init();

  runApp(const KidsApp());
}

class KidsApp extends StatefulWidget {
  const KidsApp({super.key});

  @override
  State<KidsApp> createState() => _KidsAppState();
}

class _KidsAppState extends State<KidsApp> with WidgetsBindingObserver {
  bool _isLoading = true;
  UserModel? _student;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _bootstrap() async {
    if (SessionManager.isLoggedIn && SessionManager.userId.isNotEmpty) {
      final user = await SupabaseService.fetchStudentProfile(SessionManager.userId);
      if (mounted) {
        setState(() {
          // Sadece öğrenci ise oturumu koru
          if (user != null && user.role != 'parent') {
            _student = user;
          } else {
            _student = null;
          }
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Öğrenci Uygulamadan Çıkma & Minimize Sensörü
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      print('[Lifecycle] Öğrenci uygulamayı arka plana attı veya küçülttü!');
      SupabaseService.reportAppMinimizedViolation();
    } else if (state == AppLifecycleState.resumed) {
      print('[Lifecycle] Öğrenci uygulamaya geri döndü.');
      SupabaseService.subscribeToRealtimeEvents();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FamilyToStudy Kids',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
          PointerDeviceKind.stylus,
        },
      ),
      theme: KidsTheme.themeData,
      home: _isLoading
          ? const Scaffold(
              backgroundColor: KidsTheme.bgMidnight,
              body: Center(
                child: CircularProgressIndicator(color: KidsTheme.cyanSoft),
              ),
            )
          : _student != null
              ? KidsHomeScreen(initialStudent: _student!)
              : const KidsAuthScreen(),
    );
  }
}
