import 'package:flutter/material.dart';
import '../../../theme/kids_theme.dart';
import '../../../models/user_model.dart';

class MicroExperimentModal extends StatelessWidget {
  final UserModel student;

  const MicroExperimentModal({
    super.key,
    required this.student,
  });

  static void show(BuildContext context, UserModel student) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MicroExperimentModal(student: student),
    );
  }

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
                const Text('🧪', style: TextStyle(fontSize: 26)),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bilim İnsanı Günlüğü',
                        style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
                      ),
                      Text(
                        'Evdeki malzemelerle 5 dakikalık pratik deneyler ve bilim!',
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [const Color(0xFF10B981).withOpacity(0.25), const Color(0xFF0F766E).withOpacity(0.15)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Haftanın Deneyi 🔬 (Süre: 5 Dakika)', style: TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.bold, fontSize: 12)),
                        SizedBox(height: 6),
                        Text('Dans Eden Mısırlar & Gaz Kaldırma Gücü', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  const Text('Gereken Malzemeler 🧰', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: KidsTheme.surface, borderRadius: BorderRadius.circular(16)),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• 1 şeffaf su bardağı', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        SizedBox(height: 4),
                        Text('• 1 tatlı kaşığı karbonat', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        SizedBox(height: 4),
                        Text('• 1 çorba kaşığı sirke', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        SizedBox(height: 4),
                        Text('• 5-6 adet kuru mısır tanesi', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text('Deneyin Adımları 📋', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: KidsTheme.surface, borderRadius: BorderRadius.circular(16)),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('1. Bardağın yarısını suyla doldur ve karbonatı karıştır.', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        SizedBox(height: 6),
                        Text('2. Mısır tanelerini bardağa at (dibe çökeceklerdir).', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        SizedBox(height: 6),
                        Text('3. Sirkeyi ekle ve mısırların kabarcıklarla yukarı aşağı dans edişini izle!', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.3)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bilimsel Açıklama 💡', style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 12)),
                        SizedBox(height: 4),
                        Text(
                          'Sirke ve karbonat tepkimeye girerek karbondioksit gazı üretir. Mısırların yüzeyine tutunan minik gaz kabarcıkları onları can yeleği gibi yukarı kaldırır.',
                          style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(backgroundColor: KidsTheme.emerald, content: Text('🎉 Deneyi tamamladın! +40 Bilim Puanı kazandın.')),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: KidsTheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Deneyi Yaptım & Tamamla (+40 XP)', style: TextStyle(fontWeight: FontWeight.bold)),
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
