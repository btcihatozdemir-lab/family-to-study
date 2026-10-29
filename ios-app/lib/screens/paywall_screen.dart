import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../services/subscription_service.dart';
import '../theme/fam_theme.dart';

/// ===========================================================================
/// paywall_screen.dart - REVENUECAT PRO PAYWALL & REVERSE TRIAL MODAL
/// ===========================================================================
/// App Store Review Guidelines (3.1.2) Tam Uyumlu:
/// - Ücretsiz deneme (Reverse Trial 7 Gün) vurgusu
/// - Fiyatlandırma, periyot, otomatik yenileme şartları
/// - Gizlilik Politikası ve Kullanım Koşulları (EULA)
/// - Satın Almaları Geri Yükle (Restore Purchases)
/// ===========================================================================

class PaywallScreen extends StatefulWidget {
  final String triggerFeature;

  const PaywallScreen({
    super.key,
    this.triggerFeature = 'FamilyOS Pro',
  });

  static Future<bool?> show(
    BuildContext context, {
    String triggerFeature = 'FamilyOS Pro',
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PaywallScreen(triggerFeature: triggerFeature),
    );
  }

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _isLoading = true;
  bool _isPurchasing = false;
  String? _errorMessage;

  Offerings? _offerings;
  Package? _annualPackage;
  Package? _monthlyPackage;
  String _selectedPlan = 'annual'; // 'annual' veya 'monthly'

  @override
  void initState() {
    super.initState();
    _loadOfferings();
  }

  Future<void> _loadOfferings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final offerings = await SubscriptionService.getOfferings();
    if (mounted) {
      setState(() {
        _offerings = offerings;
        final current = offerings?.current;
        if (current != null) {
          _annualPackage = current.annual;
          _monthlyPackage = current.monthly;
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _handlePurchase() async {
    setState(() {
      _isPurchasing = true;
      _errorMessage = null;
    });

    Package? targetPackage;
    if (_selectedPlan == 'annual') {
      targetPackage = _annualPackage;
    } else {
      targetPackage = _monthlyPackage;
    }

    if (targetPackage != null) {
      final success = await SubscriptionService.purchasePackage(targetPackage);
      if (mounted) {
        setState(() => _isPurchasing = false);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: FamTheme.emerald,
              content: Text('🎉 Tebrikler! FamilyOS Pro üyeliğiniz aktif edildi.'),
            ),
          );
          Navigator.of(context).pop(true);
        } else {
          setState(() {
            _errorMessage = 'Satın alma tamamlanamadı veya iptal edildi.';
          });
        }
      }
    } else {
      // Demo / Test Anahtarı ile Çalışma Durumu
      setState(() => _isPurchasing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: FamTheme.primary,
          content: Text('Test Modu: RevenueCat test paketleri bekleniyor.'),
        ),
      );
    }
  }

  Future<void> _handleRestore() async {
    setState(() {
      _isPurchasing = true;
      _errorMessage = null;
    });

    final success = await SubscriptionService.restorePurchases();
    if (mounted) {
      setState(() => _isPurchasing = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: FamTheme.emerald,
            content: Text('✅ Satın alımlarınız başarıyla geri yüklendi!'),
          ),
        );
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _errorMessage = 'Geri yüklenebilecek aktif bir Pro abonelik bulunamadı.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final annualPrice = _annualPackage?.storeProduct.priceString ?? '499,99 ₺';
    final monthlyPrice = _monthlyPackage?.storeProduct.priceString ?? '79,99 ₺';

    return Container(
      decoration: const BoxDecoration(
        color: FamTheme.surfaceDarker,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(top: BorderSide(color: Color(0xFF312E81), width: 2)),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Üst Kapatma Çubuğu
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Kapat İkonu ve Rozet
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [FamTheme.gold, Color(0xFFD97706)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('👑', style: TextStyle(fontSize: 14)),
                        SizedBox(width: 6),
                        Text(
                          'PRO AYRICALIKLARI',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: FamTheme.textMuted),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Ana Başlık
              const Text(
                'FamilyOS Pro ile Sınırları Kaldırın',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),

              Text(
                '${widget.triggerFeature} ve tüm kısıtlamaları aşmak için 7 gün boyunca risksiz deneyin.',
                style: const TextStyle(
                  color: FamTheme.textSecondary,
                  fontSize: 13,
                  height: 1.35,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Avantajlar Listesi
              _buildFeatureRow('👨‍👩‍👧‍👦', 'Sınırsız Çocuk & Cihaz', 'Tüm kardeşleri tek çatı altından bağımsız yönetin.'),
              _buildFeatureRow('💻', 'Windows PC Ajanı', 'Oyun kilidi, ekran koruması ve süre limitlerini yönetin.'),
              _buildFeatureRow('🤝', 'Anne + Baba Ortak Yönetim', 'Eşzamanlı canlı bildirimler ve ortak onay mekanizması.'),
              _buildFeatureRow('📊', 'Haftalık Karne & İstatistik', '24 saatle sınırlı kalmayan zengin gelişim analizleri.'),

              const SizedBox(height: 20),

              // Hata Bildirimi (Varsa)
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: FamTheme.rose.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: FamTheme.rose.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: FamTheme.rose, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: FamTheme.rose, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Paket Seçenekleri (Yıllık vs Aylık)
              _buildPlanCard(
                planId: 'annual',
                title: 'Yıllık Plan (7 Gün Ücretsiz Deneme)',
                price: annualPrice,
                subtitle: 'Yılda bir kez faturalandırılır (~41,60 ₺/Ay)',
                badge: '🔥 %48 İNDİRİM',
                isBestValue: true,
              ),
              const SizedBox(height: 10),

              _buildPlanCard(
                planId: 'monthly',
                title: 'Aylık Plan',
                price: monthlyPrice,
                subtitle: 'Her ay otomatik yenilenir. İstediğiniz an iptal.',
                badge: null,
                isBestValue: false,
              ),
              const SizedBox(height: 22),

              // Satın Alma Butonu (CTA)
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: EdgeInsets.zero,
                  ),
                  onPressed: _isPurchasing ? null : _handlePurchase,
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4F46E5), Color(0xFF9333EA)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withOpacity(0.4),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Center(
                      child: _isPurchasing
                          ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('✨', style: TextStyle(fontSize: 18)),
                                const SizedBox(width: 8),
                                Text(
                                  _selectedPlan == 'annual'
                                      ? '7 Gün Ücretsiz Dene ve Başlat'
                                      : 'Hemen Pro\'ya Yükselt',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Taahhütsüz İptal Vurgusu
              const Text(
                '7 gün boyunca hiçbir ücret alınmaz. Deneme süresi bitmeden App Store\'dan tek tıkla iptal edebilirsiniz.',
                style: TextStyle(
                  color: FamTheme.textMuted,
                  fontSize: 11,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Geri Yükle & Hukuki Bağlantılar
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: _isPurchasing ? null : _handleRestore,
                    child: const Text(
                      'Satın Alımları Geri Yükle',
                      style: TextStyle(color: FamTheme.primaryLight, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Text(' • ', style: TextStyle(color: Colors.white24)),
                  TextButton(
                    onPressed: () {
                      _showLegalInfoModal('Kullanım Koşulları (EULA)', _eulaText);
                    },
                    child: const Text(
                      'Kullanım Şartları',
                      style: TextStyle(color: FamTheme.textMuted, fontSize: 11),
                    ),
                  ),
                  const Text(' • ', style: TextStyle(color: Colors.white24)),
                  TextButton(
                    onPressed: () {
                      _showLegalInfoModal('Gizlilik Politikası', _privacyText);
                    },
                    child: const Text(
                      'Gizlilik',
                      style: TextStyle(color: FamTheme.textMuted, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow(String icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: FamTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(icon, style: const TextStyle(fontSize: 16)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  desc,
                  style: const TextStyle(color: FamTheme.textMuted, fontSize: 11, height: 1.3),
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle_rounded, color: FamTheme.emerald, size: 18),
        ],
      ),
    );
  }

  Widget _buildPlanCard({
    required String planId,
    required String title,
    required String price,
    required String subtitle,
    required String? badge,
    required bool isBestValue,
  }) {
    final isSelected = _selectedPlan == planId;

    return GestureDetector(
      onTap: () => setState(() => _selectedPlan = planId),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E1B4B) : FamTheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? const Color(0xFF818CF8) : Colors.white12,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? const Color(0xFF818CF8) : FamTheme.textMuted,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: FamTheme.rose,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badge,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: FamTheme.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              price,
              style: TextStyle(
                color: isSelected ? const Color(0xFF38BDF8) : Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLegalInfoModal(String title, String body) {
    showModalBottomSheet(
      context: context,
      backgroundColor: FamTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: Text(body, style: const TextStyle(color: FamTheme.textSecondary, fontSize: 13, height: 1.4)),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: FamTheme.primary),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Kapat', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  static const String _eulaText = '''
FamilyOS Pro Abonelik Koşulları:
- FamilyOS Pro üyeliği seçilen süre boyunca (Aylık veya Yıllık) otomatik olarak yenilenir.
- 7 günlük ücretsiz deneme süresi bittikten sonra ücret Apple Kimliği hesabınızdan tahsil edilir.
- Aboneliğinizi deneme süresi bitmeden en az 24 saat önce App Store Hesap Ayarlarınızdan iptal ederseniz herhangi bir ücret alınmaz.
- Kullanıcı dilediği zaman abonelik yönetimini ve iptalini App Store üzerinden gerçekleştirebilir.
''';

  static const String _privacyText = '''
Gizlilik Politikası:
- FamilyOS, ailenizin ve çocuklarınızın kişisel verilerini en üst düzey şifreleme ve RLS izolasyonu ile korur.
- Konum veya hassas ses/video verileri kesinlikle üçüncü taraflarla paylaşılmaz.
- Verileriniz yalnızca ebeveyn kontrolü, odaklanma modları ve ders çalışma disiplini amacıyla işlenir.
''';
}
