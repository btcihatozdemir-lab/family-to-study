import 'package:flutter/material.dart';
import '../../../theme/kids_theme.dart';
import '../../../models/user_model.dart';

class MindFactsModal extends StatefulWidget {
  final UserModel student;

  const MindFactsModal({
    super.key,
    required this.student,
  });

  static void show(BuildContext context, UserModel student) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MindFactsModal(student: student),
    );
  }

  @override
  State<MindFactsModal> createState() => _MindFactsModalState();
}

class _MindFactsModalState extends State<MindFactsModal> {
  int _selectedOption = -1;
  bool _answered = false;
  bool _isCorrect = false;

  final Map<String, dynamic> _factData = {
    'title': 'Venüs Gezegeninin İlginç Dansı',
    'fact': 'Venüs kendi ekseni etrafında o kadar yavaş döner ki; bir tam günü (243 Dünya günü), Güneş etrafındaki bir yılından (225 Dünya günü) daha uzundur! Yani Venüs\'te gün yılından daha uzundur.',
    'category': 'Uzay & Astronomi 🚀',
    'question': 'Venüs gezegeni hakkında hangi bilgi doğrudur?',
    'options': [
      'Venüs\'te 1 gün, 1 yılından daha uzundur',
      'Venüs Güneş Sistemi\'nin en soğuk gezegenidir',
      'Venüs\'ün halkaları Dünya\'dan teleskopsuz görünür',
    ],
    'correct_index': 0,
    'explanation': 'Doğru! Venüs geriye doğru ve son derece yavaş döndüğü için gün-yıl dengesi tamamen şaşırtıcıdır.',
  };

  void _submitAnswer() {
    if (_selectedOption < 0) return;
    setState(() {
      _answered = true;
      _isCorrect = _selectedOption == _factData['correct_index'];
    });
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
                const Text('🧠', style: TextStyle(fontSize: 26)),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Günün Sırrı & İlginç Bilgi',
                        style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
                      ),
                      Text(
                        'Zihin açıcı bilimsel gerçekler ve 1 dakikalık merak testi!',
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
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF8B5CF6).withOpacity(0.25),
                          const Color(0xFF38BDF8).withOpacity(0.15),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_factData['category'], style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(height: 6),
                        Text(_factData['title'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17)),
                        const SizedBox(height: 8),
                        Text(_factData['fact'], style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text(_factData['question'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 12),

                  ...List.generate((_factData['options'] as List).length, (idx) {
                    final opt = _factData['options'][idx];
                    final isSelected = _selectedOption == idx;
                    final isCorrectOpt = idx == _factData['correct_index'];

                    Color cardColor = KidsTheme.surface;
                    Color borderColor = Colors.white10;

                    if (_answered) {
                      if (isCorrectOpt) {
                        cardColor = KidsTheme.emerald.withOpacity(0.2);
                        borderColor = KidsTheme.emerald;
                      } else if (isSelected) {
                        cardColor = KidsTheme.rose.withOpacity(0.2);
                        borderColor = KidsTheme.rose;
                      }
                    } else if (isSelected) {
                      cardColor = KidsTheme.primary.withOpacity(0.2);
                      borderColor = KidsTheme.primary;
                    }

                    return InkWell(
                      onTap: _answered ? null : () => setState(() => _selectedOption = idx),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor),
                        ),
                        child: Text(opt, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    );
                  }),

                  const SizedBox(height: 16),
                  if (!_answered)
                    ElevatedButton(
                      onPressed: _selectedOption >= 0 ? _submitAnswer : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: KidsTheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Cevabımı Gönder (+20 XP)', style: TextStyle(fontWeight: FontWeight.bold)),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _isCorrect ? KidsTheme.emerald.withOpacity(0.15) : KidsTheme.rose.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        _isCorrect ? '🎉 Tebrikler! Doğru cevap. +20 Merak Puanı kazandın!' : 'Bir dahaki sefere! ' + _factData['explanation'],
                        style: TextStyle(
                          color: _isCorrect ? KidsTheme.emerald : KidsTheme.rose,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
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
