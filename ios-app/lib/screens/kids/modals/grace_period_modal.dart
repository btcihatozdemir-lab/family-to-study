import 'package:flutter/material.dart';
import '../../../models/user_model.dart';
import '../../../theme/kids_theme.dart';

class GracePeriodModal extends StatelessWidget {
  final UserModel student;

  const GracePeriodModal({super.key, required this.student});

  static Future<void> show(BuildContext context, UserModel student) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => GracePeriodModal(student: student),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: KidsTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          const SizedBox(height: 16),

          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: KidsTheme.gold.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Text('🕊️', style: TextStyle(fontSize: 26)),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Merhamet Hakkı & Joker',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Oyunun en heyecanlı anında acil durum molası',
                      style: TextStyle(color: KidsTheme.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [KidsTheme.primary.withOpacity(0.2), KidsTheme.purpleAccent.withOpacity(0.2)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: KidsTheme.primary.withOpacity(0.4)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.timer_outlined, color: KidsTheme.goldLight, size: 20),
                    SizedBox(width: 8),
                    Text(
                      '+5 Dakika Acil Ek Süre',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'Günde 1 kez kullanılabilir. Ekran süren bitmek üzereyken veya oyunun kritik bölümündeyken Anne/Babana otomatik haber vererek süreni 5 dakika uzatır.',
                  style: TextStyle(color: KidsTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Row(
                    children: [
                      Text('🕊️ ', style: TextStyle(fontSize: 20)),
                      Expanded(
                        child: Text(
                          'Merhamet Jokeri devrede! +5 dakika ek süre eklendi ve aileye bildirildi.',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: KidsTheme.emerald,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: KidsTheme.gold,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.hourglass_bottom_rounded, size: 20),
                SizedBox(width: 8),
                Text(
                  'Merhamet Jokerini Kullan (+5 Dk)',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
