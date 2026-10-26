import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/session_manager.dart';
import 'services/notification_service.dart';
import 'services/audio_keep_alive_service.dart';
import 'services/supabase_service.dart';
import 'screens/webview_screen.dart';

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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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
    return MaterialApp(
      title: 'FamilyToStudy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6366F1),
          secondary: Color(0xFF10B981),
          surface: Color(0xFF1E293B),
        ),
      ),
      home: const FamilyWebViewScreen(),
    );
  }
}
