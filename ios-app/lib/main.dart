import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/session_manager.dart';
import 'services/notification_service.dart';
import 'services/audio_keep_alive_service.dart';
import 'services/supabase_service.dart';
import 'models/user_model.dart';
import 'theme/fam_theme.dart';
import 'theme/kids_theme.dart';
import 'main_fam.dart';
import 'main_kids.dart';

/// ===========================================================================
/// main.dart - APPLICATION SELECTOR & FLAVOR BOOTSTRAP
/// ===========================================================================
/// SOLID Architecture:
/// - Fam uygulaması için: flutter run/build -t lib/main_fam.dart
/// - Kids uygulaması için: flutter run/build -t lib/main_kids.dart
/// - Tek portaldan test/web için: APP_FLAVOR ortam değişkenine göre otomatik sevk
/// ===========================================================================

const String kAppFlavor = String.fromEnvironment('APP_FLAVOR', defaultValue: '');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Ortak Servisleri Başlat
  await SessionManager.init();
  await NotificationService.init();
  await SupabaseService.init();

  // Flavor bayrağı doğrudan verilmişse doğrudan ilgili uygulamayı başlat
  if (kAppFlavor.toLowerCase() == 'fam') {
    runApp(const FamApp());
    return;
  } else if (kAppFlavor.toLowerCase() == 'kids') {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await AudioKeepAliveService.startKeepAliveLoop();
    runApp(const KidsApp());
    return;
  }

  // Genel Başlatıcı / Portal
  runApp(const FamilyOSEcosystemApp());
}

class FamilyOSEcosystemApp extends StatefulWidget {
  const FamilyOSEcosystemApp({super.key});

  @override
  State<FamilyOSEcosystemApp> createState() => _FamilyOSEcosystemAppState();
}

class _FamilyOSEcosystemAppState extends State<FamilyOSEcosystemApp> {
  bool _isLoading = true;
  UserModel? _loggedInUser;

  @override
  void initState() {
    super.initState();
    _checkActiveSession();
  }

  Future<void> _checkActiveSession() async {
    if (SessionManager.isLoggedIn && SessionManager.userId.isNotEmpty) {
      final user = await SupabaseService.fetchStudentProfile(SessionManager.userId);
      if (mounted) {
        setState(() {
          _loggedInUser = user;
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
    if (_isLoading) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Color(0xFF0F172A),
          body: Center(child: CircularProgressIndicator(color: Color(0xFF4361EE))),
        ),
      );
    }

    // Aktif oturum varsa doğrudan ilgili bağımsız uygulamaya gönder
    if (_loggedInUser != null) {
      if (_loggedInUser!.role == 'parent') {
        return const FamApp();
      } else {
        return const KidsApp();
      }
    }

    // Giriş yapılmamışsa ve doğrudan main.dart çalıştırıldıysa:
    // Cihaz / Kullanıcı Uygulama Seçim Portalı
    return MaterialApp(
      title: 'FamilyToStudy Ekosistemi',
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
      home: const EcosystemSelectorScreen(),
    );
  }
}

/// Geliştirme ve Web Test Portalı: İki Ayrı Uygulama Vitrini
class EcosystemSelectorScreen extends StatelessWidget {
  const EcosystemSelectorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Başlık
                const Text(
                  '🦁 FamilyToStudy Ekosistemi',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Lütfen bu cihazda çalıştırmak istediğiniz uygulamayı seçin:',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 36),

                // İki Ayrı Bağımsız Uygulama Kartı
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 640;
                    return Flex(
                      direction: isNarrow ? Axis.vertical : Axis.horizontal,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // KART 1: FAMILYTOSTUDY FAM (EBEVEYN)
                        Expanded(
                          flex: isNarrow ? 0 : 1,
                          child: _buildAppCard(
                            context: context,
                            title: 'FamilyToStudy Fam',
                            subtitle: 'Ebeveyn & Veli Komuta Merkezi',
                            description: 'Görev atama, canlı kalkan denetimi, adalet divanı itirazları ve Google Girişi.',
                            badge: '🛡️ EBEVEYN CİHAZI',
                            badgeColor: const Color(0xFF4361EE),
                            logoAsset: 'assets/images/family_logo.png',
                            accentColor: const Color(0xFF4361EE),
                            buttonText: 'Fam Uygulamasını Başlat',
                            onTap: () {
                              runApp(const FamApp());
                            },
                          ),
                        ),
                        SizedBox(width: isNarrow ? 0 : 24, height: isNarrow ? 24 : 0),

                        // KART 2: FAMILYTOSTUDY KIDS (ÖĞRENCİ)
                        Expanded(
                          flex: isNarrow ? 0 : 1,
                          child: _buildAppCard(
                            context: context,
                            title: 'FamilyToStudy Kids',
                            subtitle: 'Öğrenci Odak & Oyun Portalı',
                            description: 'Kronometre, çarkıfelek, rozetler, bas-konuş telsiz ve donanımsal kilit kalkanı.',
                            badge: '🧒 ÖĞRENCİ CİHAZI',
                            badgeColor: const Color(0xFF10B981),
                            logoAsset: 'assets/images/kids_logo.png',
                            accentColor: const Color(0xFF10B981),
                            buttonText: 'Kids Uygulamasını Başlat',
                            onTap: () {
                              SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
                              AudioKeepAliveService.startKeepAliveLoop();
                              runApp(const KidsApp());
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String description,
    required String badge,
    required Color badgeColor,
    required String logoAsset,
    required Color accentColor,
    required String buttonText,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accentColor.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: accentColor.withOpacity(0.4)),
                ),
                padding: const EdgeInsets.all(8),
                child: Image.asset(
                  logoAsset,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Icon(Icons.apps_rounded, color: accentColor, size: 36),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: badgeColor.withOpacity(0.3)),
                ),
                child: Text(
                  badge,
                  style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(color: accentColor, fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
            ),
            child: Text(
              buttonText,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
