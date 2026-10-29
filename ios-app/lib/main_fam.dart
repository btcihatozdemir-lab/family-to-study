import 'dart:ui';
import 'package:flutter/material.dart';
import 'services/session_manager.dart';
import 'services/notification_service.dart';
import 'services/supabase_service.dart';
import 'services/subscription_service.dart';
import 'models/user_model.dart';
import 'theme/fam_theme.dart';
import 'screens/fam/fam_auth_screen.dart';
import 'screens/fam/fam_home_screen.dart';
import 'l10n/app_localizations.dart';

/// ===========================================================================
/// main_fam.dart - FAMILYTOSTUDY FAM (EBEVEYN & VELİ YÖNETİM UYGULAMASI)
/// ===========================================================================
/// SOLID: Single Responsibility Principle (SRP)
/// Bu dosya ve uygulama YALNIZCA ebeveyn yönetimi için derlenir.
/// Paket: com.familytostudy.fam
/// Logo: assets/images/family_logo.png
/// ===========================================================================

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Yerel Hafızayı Yükle
  try {
    await SessionManager.init();
  } catch (e) {
    print('[MainFam] SessionManager init error: $e');
  }

  // 2. Supabase İstemcisini Başlat
  try {
    await SupabaseService.init();
  } catch (e) {
    print('[MainFam] Supabase init error: $e');
  }

  // 3. RevenueCat Abonelik ve Paywall Servisini Başlat
  try {
    await SubscriptionService.init();
  } catch (e) {
    print('[MainFam] SubscriptionService init error: $e');
  }

  // UI'ı hemen başlat
  runApp(const FamApp());
}

class FamApp extends StatefulWidget {
  const FamApp({super.key});

  @override
  State<FamApp> createState() => _FamAppState();
}

class _FamAppState extends State<FamApp> {
  late bool _isLoading;
  UserModel? _parentUser;

  @override
  void initState() {
    super.initState();
    _isLoading = SessionManager.isLoggedIn && SessionManager.userId.isNotEmpty;
    if (_isLoading) {
      _bootstrap();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await NotificationService.init();
        await NotificationService.requestPermissions();
      } catch (e) {
        print('[FamApp] Notification deferred init error: $e');
      }
    });
  }

  Future<void> _bootstrap() async {
    try {
      if (SessionManager.isLoggedIn && SessionManager.userId.isNotEmpty) {
        final user = await SupabaseService.fetchStudentProfile(SessionManager.userId)
            .timeout(const Duration(seconds: 3), onTimeout: () => null);
        if (mounted) {
          setState(() {
            _parentUser = (user != null && user.role == 'parent') ? user : null;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      print('[FamApp] Bootstrap error: $e');
      if (mounted) {
        setState(() {
          _parentUser = null;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FamilyToStudy Fam',
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
      theme: FamTheme.themeData,
      home: _isLoading
          ? Scaffold(
              backgroundColor: FamTheme.background,
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/family_logo.png',
                      width: 90,
                      height: 90,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.family_restroom_rounded,
                        color: FamTheme.primary,
                        size: 72,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'FamilyToStudy Fam',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const CircularProgressIndicator(color: FamTheme.primary),
                  ],
                ),
              ),
            )
          : _parentUser != null
              ? const FamHomeScreen()
              : const FamAuthScreen(),
    );
  }
}
