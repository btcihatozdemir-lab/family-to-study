import 'package:flutter/material.dart';
import '../../../models/user_model.dart';
import '../../../theme/kids_theme.dart';

class SuccessAlbumModal extends StatelessWidget {
  final UserModel student;

  const SuccessAlbumModal({super.key, required this.student});

  static Future<void> show(BuildContext context, UserModel student) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SuccessAlbumModal(student: student),
    );
  }

  @override
  Widget build(BuildContext context) {
    final badges = [
      {'icon': '🌅', 'title': 'Erken Kalkan', 'desc': 'Sabah alarmını ilk çalışta kapattın', 'achieved': true},
      {'icon': '🛡️', 'title': 'Çelik Kalkan', 'desc': '3 gün boyunca hiç kalkan kaybetmedin', 'achieved': true},
      {'icon': '📚', 'title': 'Ders Kurdu', 'desc': 'Günün tüm çalışma görevlerini bitirdin', 'achieved': true},
      {'icon': '💛', 'title': 'Altın Kalp', 'desc': 'Kardeşine destek puanı gönderdin', 'achieved': true},
      {'icon': '🎡', 'title': 'Şans Ustası', 'desc': 'Şans çarkında büyük ödülü kazandın', 'achieved': false},
      {'icon': '👑', 'title': 'Haftanın Lideri', 'desc': 'Haftalık liderlik tablosunda zirvedesin', 'achieved': false},
    ];

    return Container(
      decoration: const BoxDecoration(
        color: KidsTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.all(22),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Text('🏆', style: TextStyle(fontSize: 26)),
                  SizedBox(width: 10),
                  Text(
                    'Başarı & Kupa Albümü',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: KidsTheme.gold.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '4 / 6 Rozet Açıldı',
                  style: TextStyle(color: KidsTheme.goldLight, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.45,
            ),
            itemCount: badges.length,
            itemBuilder: (ctx, i) {
              final b = badges[i];
              final achieved = b['achieved'] as bool;
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: achieved ? KidsTheme.surfaceElevated : Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: achieved ? KidsTheme.gold.withOpacity(0.4) : Colors.white12,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(b['icon'] as String, style: const TextStyle(fontSize: 24)),
                        if (achieved)
                          const Icon(Icons.check_circle_rounded, color: KidsTheme.emerald, size: 16)
                        else
                          const Icon(Icons.lock_outline_rounded, color: Colors.white30, size: 16),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      b['title'] as String,
                      style: TextStyle(
                        color: achieved ? Colors.white : Colors.white38,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      b['desc'] as String,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: KidsTheme.textMuted, fontSize: 10),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
