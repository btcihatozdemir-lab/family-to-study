import 'package:flutter/material.dart';
import '../../../theme/kids_theme.dart';
import '../../../models/user_model.dart';

class TimeCapsuleModal extends StatefulWidget {
  final UserModel student;

  const TimeCapsuleModal({
    super.key,
    required this.student,
  });

  static void show(BuildContext context, UserModel student) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TimeCapsuleModal(student: student),
    );
  }

  @override
  State<TimeCapsuleModal> createState() => _TimeCapsuleModalState();
}

class _TimeCapsuleModalState extends State<TimeCapsuleModal> {
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _memoryCtrl = TextEditingController();
  bool _saved = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _memoryCtrl.dispose();
    super.dispose();
  }

  void _saveCapsule() {
    if (_titleCtrl.text.trim().isEmpty || _memoryCtrl.text.trim().isEmpty) return;
    setState(() => _saved = true);
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
                const Text('⏳', style: TextStyle(fontSize: 26)),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Aile Hafıza Çemberi (Zaman Kapsülü)',
                        style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
                      ),
                      Text(
                        'Haftanın en komik anısını, kitabın en güzel cümlesini geleceğe mühürle!',
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
                        colors: [const Color(0xFFF59E0B).withOpacity(0.25), const Color(0xFFB45309).withOpacity(0.15)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
                    ),
                    child: const Row(
                      children: [
                        Text('📦', style: TextStyle(fontSize: 32)),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('1 Yıl Sonra Açılacak Kapsül', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                              SizedBox(height: 2),
                              Text('Bu kapsüle yazacağınız notlar 1 sene sonraki karne gününde kilit açarak ailenize gösterilecektir.', style: TextStyle(color: KidsTheme.textMuted, fontSize: 11)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: KidsTheme.surface, borderRadius: BorderRadius.circular(16)),
                    child: TextField(
                      controller: _titleCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        labelText: 'Kapsül Başlığı / Anı Adı',
                        labelStyle: TextStyle(color: KidsTheme.textMuted),
                        hintText: 'Örn: Pazar Kahvaltısındaki Kedi Vakası',
                        hintStyle: TextStyle(color: Colors.white24, fontSize: 12),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: KidsTheme.surface, borderRadius: BorderRadius.circular(16)),
                    child: TextField(
                      controller: _memoryCtrl,
                      maxLines: 5,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Anının Detayı / Geleceğe Not',
                        labelStyle: TextStyle(color: KidsTheme.textMuted),
                        hintText: 'O an ne oldu, ne hissettiniz, neye çok güldünüz?',
                        hintStyle: TextStyle(color: Colors.white24, fontSize: 12),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  if (!_saved)
                    ElevatedButton.icon(
                      onPressed: _saveCapsule,
                      icon: const Icon(Icons.lock_clock_rounded, color: Colors.white),
                      label: const Text('Kapsülü Mühürle & Geleceğe Gönder', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: KidsTheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: KidsTheme.emerald.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: KidsTheme.emerald.withOpacity(0.4)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle_rounded, color: KidsTheme.emerald, size: 28),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Anınız şifrelendi ve zaman kapsülüne kilitlendi! Seneye karne gününde sürpriz olarak açılacak. +25 Aile Puanı!',
                              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
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
}
