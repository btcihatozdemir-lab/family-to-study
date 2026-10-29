import 'package:flutter/material.dart';
import '../../../theme/kids_theme.dart';
import '../../../models/user_model.dart';

class FutureCareersModal extends StatelessWidget {
  final UserModel student;

  const FutureCareersModal({
    super.key,
    required this.student,
  });

  static void show(BuildContext context, UserModel student) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FutureCareersModal(student: student),
    );
  }

  final List<Map<String, dynamic>> _badges = const [
    {
      'title': 'Yapay Zeka Etik Uzmanı',
      'icon': '🤖',
      'field': 'Bilişim & Felsefe',
      'progress': 0.85,
      'status': 'Kazanıldı',
      'desc': 'Algoritmaların insanlar için adil ve güvenli çalışmasını denetleyen gelecek lideri.',
    },
    {
      'title': 'Biyo-Mühendis',
      'icon': '🧬',
      'field': 'Sağlık & Genetik',
      'progress': 0.60,
      'status': 'Devam Ediyor (%60)',
      'desc': 'Canlı hücreleri ve genetik kodları insanlık yararına tasarlayan bilim insanı.',
    },
    {
      'title': 'Uzay Trafik Kontrolörü',
      'icon': '🚀',
      'field': 'Havacılık & Astronomi',
      'progress': 0.40,
      'status': 'Devam Ediyor (%40)',
      'desc': 'Yörüngedeki roketlerin ve uyduların rotalarını planlayan uzay kaptanı.',
    },
    {
      'title': 'İklim Veri Bilimcisi',
      'icon': '🌱',
      'field': 'Çevre & Ekoloji',
      'progress': 0.25,
      'status': 'Başlangıç',
      'desc': 'Dünya gezegenini korumak için veri modelleri üreten yeşil enerji lideri.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: KidsTheme.background,
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
                const Text('🚀', style: TextStyle(fontSize: 26)),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Geleceğin Meslekleri Simülasyonu',
                        style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
                      ),
                      Text(
                        'Çözdüğün dersler fütüristik meslek rozetlerine dönüşüyor!',
                        style: TextStyle(color: KidsTheme.textMuted, fontSize: 11),
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
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _badges.length,
              itemBuilder: (ctx, i) {
                final b = _badges[i];
                final isDone = b['progress'] >= 0.8;

                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: KidsTheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isDone ? const Color(0xFF38BDF8).withOpacity(0.4) : Colors.white.withOpacity(0.06)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: KidsTheme.surfaceElevated,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Center(child: Text(b['icon'], style: const TextStyle(fontSize: 24))),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(b['title'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
                                const SizedBox(height: 2),
                                Text(b['field'], style: const TextStyle(color: KidsTheme.textMuted, fontSize: 11)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDone ? KidsTheme.emerald.withOpacity(0.2) : Colors.white12,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              b['status'],
                              style: TextStyle(
                                color: isDone ? KidsTheme.emerald : Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(b['desc'], style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: b['progress'],
                          minHeight: 6,
                          backgroundColor: Colors.white10,
                          valueColor: AlwaysStoppedAnimation<Color>(isDone ? const Color(0xFF38BDF8) : KidsTheme.primary),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
