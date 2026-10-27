import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/session_manager.dart';
import 'services/notification_service.dart';
import 'services/audio_keep_alive_service.dart';
import 'services/supabase_service.dart';
import 'models/user_model.dart';
import 'theme/kids_theme.dart';
import 'theme/fam_theme.dart';
import 'screens/kids/kids_auth_screen.dart';
import 'screens/kids/kids_home_screen.dart';
import 'screens/fam/fam_home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Tam Ekran Oyun & Odak Modu: Durum Çubuğunu Gizle
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // 1. Yerel Hafızayı Yükle
  await SessionManager.init();

  // 2. Kilit Ekranı Yerel Bildirim Motorunu Başlat
  await NotificationService.init();

  // 3. 7/24 Arka Plan Canlı Tutucu Sessiz Ses Motorunu Başlat
  await AudioKeepAliveService.startKeepAliveLoop();

  // 4. Supabase Realtime WebSocket Ağını Başlat
  await SupabaseService.init();

  runApp(const FamilyOSApp());
}

class FamilyOSApp extends StatefulWidget {
  const FamilyOSApp({super.key});

  @override
  State<FamilyOSApp> createState() => _FamilyOSAppState();
}

class _FamilyOSAppState extends State<FamilyOSApp> with WidgetsBindingObserver {
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
          _student = user;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Öğrenci Uygulamadan Çıkma & Minimize Sensörü
  /// Öğrenci Home tuşuna bastığı, uygulamayı alta attığı veya başka uygulamaya geçtiği anda
  /// anında tetiklenir ve Supabase veritabanına ihlal yazar.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      print('[Lifecycle] Uygulama arka plana geçti veya küçültüldü.');
      SupabaseService.reportAppMinimizedViolation();
    } else if (state == AppLifecycleState.resumed) {
      print('[Lifecycle] Uygulama ön plana geri döndü.');
      SupabaseService.subscribeToRealtimeEvents();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isParent = _student?.role == 'parent' || SessionManager.isParent;

    return MaterialApp(
      title: isParent ? 'FamilyToStudy Fam' : 'FamilyToStudy Kids',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const AppScrollBehavior(),
      theme: isParent ? FamTheme.themeData : KidsTheme.themeData,
      home: _isLoading
          ? const Scaffold(
              backgroundColor: KidsTheme.bgMidnight,
              body: Center(
                child: CircularProgressIndicator(color: KidsTheme.cyanSoft),
              ),
            )
          : _student != null
              ? (isParent ? const FamHomeScreen() : KidsHomeScreen(initialStudent: _student!))
              : const KidsAuthScreen(),
    );
  }
}

/// Web & Masaüstü İçin Mouse / Trackpad Sürükleyerek Kaydırma Desteği
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}
