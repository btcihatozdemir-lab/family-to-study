import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../theme/fam_theme.dart';

class BilateralTrialModal extends StatelessWidget {
  final String familyId;
  final String referralCode;

  const BilateralTrialModal({
    super.key,
    required this.familyId,
    this.referralCode = 'AILE-PRO-72',
  });

  static void show(BuildContext context, String familyId, {String referralCode = 'AILE-PRO-72'}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BilateralTrialModal(familyId: familyId, referralCode: referralCode),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inviteLink = 'https://familytostudy.com/davet/$referralCode';

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
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
          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Text('🎁', style: TextStyle(fontSize: 26)),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Çift Taraflı Hediye (+14 Gün Pro)',
                        style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Bir aileyi veya eşini davet et, ikiniz de 14 gün ücretsiz Pro kazanın!',
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
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [FamTheme.gold.withOpacity(0.25), FamTheme.primary.withOpacity(0.15)],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: FamTheme.gold.withOpacity(0.4)),
                    ),
                    child: Column(
                      children: [
                        const Text('👑', style: TextStyle(fontSize: 42)),
                        const SizedBox(height: 10),
                        const Text(
                          'Kazan - Kazan Büyüme Hediyesi',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Davet ettiğiniz aile üye olduğunda; hem onların deneme süresi 14 gün uzar hem de sizin hesabınıza 14 günlük ücretsiz Pro hediye edilir.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: FamTheme.textMuted, fontSize: 12, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: FamTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(referralCode, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.5)),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, color: Color(0xFF38BDF8)),
                          tooltip: 'Kodu Kopyala',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: inviteLink));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(backgroundColor: FamTheme.emerald, content: Text('🔗 Davet bağlantısı panoya kopyalandı!')),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  ElevatedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: inviteLink));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(backgroundColor: FamTheme.emerald, content: Text('WhatsApp ve veli gruplarında paylaşmak için link kopyalandı!')),
                      );
                    },
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: const Text('Davet Linkini Paylaş', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FamTheme.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
}
