import 'dart:ui';
import 'package:flutter/material.dart';
import 'services/session_manager.dart';
import 'services/notification_service.dart';
import 'services/supabase_service.dart';
import 'theme/fam_theme.dart';
import 'screens/coach/coach_home_screen.dart';
import 'l10n/app_localizations.dart';

/// ===========================================================================
/// main_coach.dart - FAMILYTOSTUDY COACH (ÖĞRETMEN & KADEME KOÇU UYGULAMASI)
/// ===========================================================================
/// SOLID: Single Responsibility Principle (SRP)
/// Bu uygulama YALNIZCA öğretmen ve eğitim koçları için bağımsız derlenir.
/// Paket: com.familytostudy.coach
/// Görev: Kademe bazlı (Örn: 7. Sınıf LGS) soru/kitap/ödev takibi ve toplu onay.
/// ===========================================================================

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await SessionManager.init();
  } catch (e) {
    print('[CoachApp] SessionManager init error: $e');
  }

  try {
    await SupabaseService.init();
  } catch (e) {
    print('[CoachApp] Supabase init error: $e');
  }

  runApp(const CoachApp());
}

class CoachApp extends StatelessWidget {
  const CoachApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FamilyToStudy Koç',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
          PointerDeviceKind.stylus,
        },
      ),
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        primaryColor: const Color(0xFF4361EE),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF4361EE),
          secondary: Color(0xFF10B981),
          surface: Color(0xFF1E293B),
        ),
      ),
      home: const CoachHomeScreen(),
    );
  }
}
