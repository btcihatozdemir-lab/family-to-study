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

  // Tam Ekran Oyun & Odak Modu
  try {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  } catch (e) {
    print('[Main] UI Mode warning: $e');
  }

  // 1. Yerel Hafıza Oturumunu Yükle
  try {
    await SessionManager.init();
  } catch (e) {
    print('[Main] SessionManager init error: $e');
  }

  // 2. Supabase İstemcisini Başlat
  try {
    await SupabaseService.init();
  } catch (e) {
    print('[Main] Supabase init error: $e');
  }

  // UI'ı hemen başlat (Splash/Mavi ekranda takılmayı kesin olarak önler)
  runApp(const KidsApp());
}

class KidsApp extends StatefulWidget {
  const KidsApp({super.key});

  @override
  State<KidsApp> createState() => _KidsAppState();
}

class _KidsAppState extends State<KidsApp> with WidgetsBindingObserver {
  late bool _isLoading;
  UserModel? _student;

  @override
  void initState() {
    super.initState();
    _isLoading = SessionManager.isLoggedIn && SessionManager.userId.isNotEmpty;
    WidgetsBinding.instance.addObserver(this);
    if (_isLoading) {
      _bootstrap();
    }

    // Arka plan servislerini UI ilk karesi çizildikten sonra güvenle başlat
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await NotificationService.init();
        await NotificationService.requestPermissions();
      } catch (e) {
        print('[KidsApp] Notification deferred init error: $e');
      }

      try {
        await AudioKeepAliveService.startKeepAliveLoop();
      } catch (e) {
        print('[KidsApp] AudioKeepAlive deferred start error: $e');
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      if (SessionManager.isLoggedIn && SessionManager.userId.isNotEmpty) {
        // En fazla 3 saniye bekle; ağ yavaşsa bile ekranın kilitli kalmasını önle
        final user = await SupabaseService.fetchStudentProfile(SessionManager.userId)
            .timeout(const Duration(seconds: 3), onTimeout: () => null);
        if (mounted) {
          setState(() {
            _student = (user != null && user.role != 'parent') ? user : null;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      print('[KidsApp] Bootstrap hatası: $e');
      if (mounted) {
        setState(() {
          _student = null;
          _isLoading = false;
        });
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
          ? Scaffold(
              backgroundColor: KidsTheme.bgMidnight,
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/kids_logo.png',
                      width: 90,
                      height: 90,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.stars_rounded,
                        color: KidsTheme.gold,
                        size: 72,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'FamilyToStudy Kids',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const CircularProgressIndicator(color: KidsTheme.cyanSoft),
                  ],
                ),
              ),
            )
          : _student != null
              ? KidsHomeScreen(initialStudent: _student!)
              : const KidsAuthScreen(),
    );
  }
}
