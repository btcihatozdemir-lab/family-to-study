import 'package:flutter/material.dart';
import '../../../theme/fam_theme.dart';
import '../../../models/user_model.dart';

class PositiveParentingModal extends StatelessWidget {
  final UserModel child;
  final String familyId;

  const PositiveParentingModal({
    super.key,
    required this.child,
    required this.familyId,
  });

  static void show(BuildContext context, UserModel child, String familyId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PositiveParentingModal(child: child, familyId: familyId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: FamTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 14),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Text('🌱', style: TextStyle(fontSize: 26)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${child.name} - Pozitif Ebeveynlik Karnesi',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const Text(
                        'AI Ebeveyn Koçu: Ceza değil, gelişim ve huzur odaklı analiz',
                        style: TextStyle(color: FamTheme.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Ana Pozitif Vurgu Kartı
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [FamTheme.emerald.withOpacity(0.25), FamTheme.primary.withOpacity(0.15)],
                      ),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: FamTheme.emerald.withOpacity(0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.sentiment_very_satisfied_rounded, color: FamTheme.emerald, size: 24),
                            SizedBox(width: 8),
                            Text('Ev İçi Huzur Skoru: %88', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Bu hafta ${child.name} ile yaşanan ekran süresi tartışmaları %42 azaldı. Zaman Bankası ve Joker Gün kullanımı çocuğun kendi zamanını planlama özgüvenini belirgin şekilde artırdı.',
                          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  const Text('AI Ebeveyn Koçu Tavsiyeleri 💡', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 10),

                  _buildAdviceCard(
                    icon: Icons.trending_up_rounded,
                    title: 'Matematik Odak Saati Başarısı',
                    desc: '${child.name} akşam 19:30-20:30 saatleri arasında ders moduna geçtiğinde odaklanma performansı %25 daha yüksek oluyor.',
                    color: const Color(0xFF38BDF8),
                  ),
                  const SizedBox(height: 10),
                  _buildAdviceCard(
                    icon: Icons.auto_stories_rounded,
                    title: 'Kitap Okuma Teşviki',
                    desc: 'Türkçe kitap okuma hedefini tamamladıktan sonra 10 dakikalık bilişsel mola vermesi zihinsel yorgunluğunu önledi.',
                    color: FamTheme.emerald,
                  ),
                  const SizedBox(height: 10),
                  _buildAdviceCard(
                    icon: Icons.handshake_rounded,
                    title: 'Takas Pazarı Etkisi',
                    desc: 'Bulaşık devretme ve film seçme haklarını kullandığı günlerde aile içi iletişimi daha neşeli gözlemlendi.',
                    color: const Color(0xFFF59E0B),
                  ),
                  const SizedBox(height: 20),

                  // Anonim Sınıf Kıyaslaması
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: FamTheme.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Anonim Sınıf & Bölge Ortalaması (7. Sınıf)',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 12),
                        _buildComparisonRow('Günlük Soru Sayısı', '${child.name}: 38 Soru', 'Bölge Ortalaması: 30 Soru', true),
                        const SizedBox(height: 8),
                        _buildComparisonRow('Kitap Okuma', '${child.name}: 22 Sayfa', 'Bölge Ortalaması: 18 Sayfa', true),
                        const SizedBox(height: 8),
                        _buildComparisonRow('Kural İhlali Sayısı', '${child.name}: 0 İhlal', 'Bölge Ortalaması: 1.8 İhlal', true),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdviceCard({required IconData icon, required String title, required String desc, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FamTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                Text(desc, style: const TextStyle(color: FamTheme.textMuted, fontSize: 12, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonRow(String label, String childVal, String avgVal, bool isPositive) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        Row(
          children: [
            Text(childVal, style: const TextStyle(color: FamTheme.emerald, fontWeight: FontWeight.bold, fontSize: 12)),
            const Text(' vs ', style: TextStyle(color: Colors.white30, fontSize: 10)),
            Text(avgVal, style: const TextStyle(color: FamTheme.textMuted, fontSize: 11)),
          ],
        ),
      ],
    );
  }
}
