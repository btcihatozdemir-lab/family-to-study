import 'package:flutter/material.dart';
import '../../../theme/kids_theme.dart';
import '../../../models/user_model.dart';

class ReverseMentoringModal extends StatefulWidget {
  final UserModel student;

  const ReverseMentoringModal({
    super.key,
    required this.student,
  });

  static void show(BuildContext context, UserModel student) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReverseMentoringModal(student: student),
    );
  }

  @override
  State<ReverseMentoringModal> createState() => _ReverseMentoringModalState();
}

class _ReverseMentoringModalState extends State<ReverseMentoringModal> {
  bool _missionCompleted = false;

  final Map<String, dynamic> _mission = {
    'title': 'Annene Oltalama (Phishing) Tuzağını Öğret!',
    'target': 'Anne veya Babaya',
    'badge': 'Siber Güvenlik Dedektifi 🛡️',
    'steps': [
      '1. Annene "SMS veya WhatsApp\'tan gelen hediye/kargo linklerine neden hemen tıklanmaz?" sorusunu sor.',
      '2. Ona dolandırıcıların gerçek banka sitelerini taklit ettiğini ve şifre çalmaya çalıştığını anlat.',
      '3. Görevi tamamlayınca aşağıdaki butona basıp annene mini bir test çözdür!',
    ],
    'parent_question': 'Güvenmediğiniz bir numaradan gelen linke tıklandığında ne yapmalısınız?',
    'options': [
      'Hemen linki kapatıp mesajı silmeli veya yetkiliye sormalıyım',
      'Hediye gelmiştir diye kart numaramı girmeliyim',
      'Bütün arkadaşlarıma iletmeliyim',
    ],
    'correct_index': 0,
  };

  int _parentAnswer = -1;
  bool _parentAnswered = false;

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
                const Text('🛡️', style: TextStyle(fontSize: 26)),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tersine Mentorluk (Kid-to-Parent)',
                        style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
                      ),
                      Text(
                        'Bu kez öğretmen sensin! Anne/babana siber güvenlik öğret ve test et.',
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
                        colors: [const Color(0xFF38BDF8).withOpacity(0.25), const Color(0xFF0284C7).withOpacity(0.15)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_mission['badge'], style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(_mission['title'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text('Mentorluk Adımları 📋', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: KidsTheme.surface, borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: (_mission['steps'] as List<String>)
                          .map((s) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text(s, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.3)),
                              ))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (!_missionCompleted)
                    ElevatedButton(
                      onPressed: () => setState(() => _missionCompleted = true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: KidsTheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Anneme/Babama Anlattım, Şimdi Onu Test Et!', style: TextStyle(fontWeight: FontWeight.bold)),
                    )
                  else ...[
                    const Text('Anne / Baba Sınavı 🎓', style: TextStyle(color: Color(0xFFFBBF24), fontWeight: FontWeight.w900, fontSize: 15)),
                    const SizedBox(height: 6),
                    Text(_mission['parent_question'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 10),

                    ...List.generate((_mission['options'] as List).length, (idx) {
                      final opt = _mission['options'][idx];
                      final isSelected = _parentAnswer == idx;
                      final isCorrect = idx == _mission['correct_index'];

                      Color c = KidsTheme.surface;
                      if (_parentAnswered) {
                        c = isCorrect ? KidsTheme.emerald.withOpacity(0.3) : (isSelected ? KidsTheme.rose.withOpacity(0.3) : KidsTheme.surface);
                      } else if (isSelected) {
                        c = KidsTheme.primary.withOpacity(0.3);
                      }

                      return InkWell(
                        onTap: _parentAnswered ? null : () => setState(() => _parentAnswer = idx),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white10)),
                          child: Text(opt, style: const TextStyle(color: Colors.white, fontSize: 12)),
                        ),
                      );
                    }),

                    if (!_parentAnswered)
                      ElevatedButton(
                        onPressed: _parentAnswer >= 0
                            ? () {
                                setState(() => _parentAnswered = true);
                              }
                            : null,
                        style: ElevatedButton.styleFrom(backgroundColor: KidsTheme.emerald),
                        child: const Text('Cevabı Onayla (+50 Puan)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: KidsTheme.emerald.withOpacity(0.15), borderRadius: BorderRadius.circular(14)),
                        child: const Text('🎉 Muhteşem! Anne/baban testi geçti ve sen harika bir öğretmen oldun. +50 Mentorluk Puanı!', style: TextStyle(color: KidsTheme.emerald, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
