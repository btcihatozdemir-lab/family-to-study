import 'package:flutter/material.dart';
import '../../../theme/kids_theme.dart';
import '../../../models/user_model.dart';

class MicroDebateModal extends StatefulWidget {
  final UserModel student;

  const MicroDebateModal({
    super.key,
    required this.student,
  });

  static void show(BuildContext context, UserModel student) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MicroDebateModal(student: student),
    );
  }

  @override
  State<MicroDebateModal> createState() => _MicroDebateModalState();
}

class _MicroDebateModalState extends State<MicroDebateModal> {
  final TextEditingController _argCtrl = TextEditingController();
  String _selectedStance = 'con'; // 'pro' veya 'con'
  bool _submitted = false;

  final String _topic = 'Yapay zeka gelecekte tüm mesleklerde insanların yerini alabilir mi?';

  @override
  void dispose() {
    _argCtrl.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    if (_argCtrl.text.trim().isEmpty) return;
    setState(() => _submitted = true);
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
                const Text('⚖️', style: TextStyle(fontSize: 26)),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '1 Dakikalık Münazara',
                        style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
                      ),
                      Text(
                        'Eleştirel düşünce: Kendi fikrini savun, yapay zeka hakeminden dönüt al!',
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
                      color: KidsTheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: KidsTheme.primary.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Günün Tartışma Sorusu 🎙️', style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(height: 6),
                        Text(_topic, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _selectedStance = 'pro'),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _selectedStance == 'pro' ? KidsTheme.emerald.withOpacity(0.2) : KidsTheme.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: _selectedStance == 'pro' ? KidsTheme.emerald : Colors.white10),
                            ),
                            child: const Center(
                              child: Text('👍 Evet, Alabilir', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _selectedStance = 'con'),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _selectedStance == 'con' ? KidsTheme.rose.withOpacity(0.2) : KidsTheme.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: _selectedStance == 'con' ? KidsTheme.rose : Colors.white10),
                            ),
                            child: const Center(
                              child: Text('👎 Hayır, Alamaz', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Container(
                    decoration: BoxDecoration(
                      color: KidsTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    padding: const EdgeInsets.all(14),
                    child: TextField(
                      controller: _argCtrl,
                      maxLines: 4,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: 'Neden böyle düşünüyorsun? En güçlü 1-2 cümleni yaz...',
                        hintStyle: TextStyle(color: Colors.white24, fontSize: 13),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (!_submitted)
                    ElevatedButton(
                      onPressed: _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: KidsTheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Savunmamı Sun & Hakem Puanı Al (+30 XP)', style: TextStyle(fontWeight: FontWeight.bold)),
                    )
                  else ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: KidsTheme.emerald.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: KidsTheme.emerald.withOpacity(0.4)),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('🤖', style: TextStyle(fontSize: 20)),
                              SizedBox(width: 8),
                              Text('AI Münazara Hakemi Yorumu', style: TextStyle(color: KidsTheme.emerald, fontWeight: FontWeight.w900, fontSize: 14)),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Harika bir argüman! İnsanların empati, yaratıcılık ve duygusal zekasını vurgulaman çok güçlüydü. +30 Münazara Rozeti kazandın!',
                            style: TextStyle(color: Colors.white, fontSize: 12, height: 1.3),
                          ),
                        ],
                      ),
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
