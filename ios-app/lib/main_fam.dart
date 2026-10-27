import 'dart:ui';
import 'package:flutter/material.dart';
import 'services/session_manager.dart';
import 'services/notification_service.dart';
import 'services/supabase_service.dart';
import 'models/user_model.dart';
import 'theme/fam_theme.dart';
import 'screens/fam/fam_auth_screen.dart';
import 'screens/fam/fam_home_screen.dart';

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
  await SessionManager.init();

  // 2. Bildirim Motorunu Başlat
  await NotificationService.init();

  // 3. Supabase Realtime Servisini Başlat
  await SupabaseService.init();

  runApp(const FamApp());
}

class FamApp extends StatefulWidget {
  const FamApp({super.key});

  @override
  State<FamApp> createState() => _FamAppState();
}

class _FamAppState extends State<FamApp> {
  bool _isLoading = true;
  UserModel? _parentUser;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (SessionManager.isLoggedIn && SessionManager.userId.isNotEmpty) {
      final user = await SupabaseService.fetchStudentProfile(SessionManager.userId);
      if (mounted) {
        setState(() {
          // Sadece ebeveyn ise oturumu koru
          if (user != null && user.role == 'parent') {
            _parentUser = user;
          } else {
            _parentUser = null;
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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FamilyToStudy Fam',
      debugShowCheckedModeBanner: false,
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
          ? const Scaffold(
              backgroundColor: FamTheme.background,
              body: Center(
                child: CircularProgressIndicator(color: FamTheme.primary),
              ),
            )
          : _parentUser != null
              ? const FamHomeScreen()
              : const FamAuthScreen(),
    );
  }
}
