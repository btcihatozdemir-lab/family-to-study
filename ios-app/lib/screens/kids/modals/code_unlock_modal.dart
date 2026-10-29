import 'package:flutter/material.dart';
import '../../../theme/kids_theme.dart';
import '../../../models/user_model.dart';
import '../../../services/supabase_service.dart';

class CodeUnlockModal extends StatefulWidget {
  final UserModel student;
  final VoidCallback? onUnlocked;

  const CodeUnlockModal({
    super.key,
    required this.student,
    this.onUnlocked,
  });

  static void show(BuildContext context, UserModel student, {VoidCallback? onUnlocked}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CodeUnlockModal(student: student, onUnlocked: onUnlocked),
    );
  }

  @override
  State<CodeUnlockModal> createState() => _CodeUnlockModalState();
}

class _CodeUnlockModalState extends State<CodeUnlockModal> {
  final List<String> _steps = [
    'Kediyi çağır ve sev',
    'Sütü temiz kaba dök',
    'Kabı yere bırak',
    'Afiyet olsun de',
  ];
  final List<int> _correctOrder = [1, 2, 0, 3];
  late List<int> _currentOrder;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _currentOrder = [0, 1, 2, 3];
  }

  void _verifyOrder() {
    bool ok = true;
    for (int i = 0; i < _correctOrder.length; i++) {
      if (_currentOrder[i] != _correctOrder[i]) {
        ok = false;
        break;
      }
    }

    if (ok) {
      setState(() => _isSuccess = true);
      widget.onUnlocked?.call();
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: KidsTheme.surfaceElevated,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: KidsTheme.emerald),
              SizedBox(width: 8),
              Text('Algoritma Doğru! 🚀', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'Tebrikler! Mantıksal blok sıralaması kusursuz çalıştı. +35 Kodlama XP kazandın!',
            style: TextStyle(color: KidsTheme.textMuted, fontSize: 13),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: KidsTheme.emerald),
              child: const Text('Devam Et', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: KidsTheme.rose,
          content: Text('Algoritmada mantık hatası var! İpucu: Önce süt kaba dökülmeli, sonra yere bırakılmalıdır.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
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
                const Text('💻', style: TextStyle(fontSize: 26)),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kodla Kilidi Aç (Code-to-Unlock)',
                        style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
                      ),
                      Text(
                        'Scratch / Python algoritma bloklarını sürükleyip doğru sıraya diz!',
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
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: KidsTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: KidsTheme.primary.withOpacity(0.3)),
                    ),
                    child: const Row(
                      children: [
                        Text('🧩', style: TextStyle(fontSize: 22)),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Görev: "Kediye Süt Ver" programını doğru sıraya sokup çalıştır.',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  Expanded(
                    child: ReorderableListView(
                      onReorder: (oldIndex, newIndex) {
                        setState(() {
                          if (newIndex > oldIndex) newIndex -= 1;
                          final item = _currentOrder.removeAt(oldIndex);
                          _currentOrder.insert(newIndex, item);
                        });
                      },
                      children: [
                        for (int i = 0; i < _currentOrder.length; i++)
                          Container(
                            key: ValueKey(_currentOrder[i]),
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.4)),
                            ),
                            child: Row(
                              children: [
                                Text('${i + 1}.', style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.w900, fontSize: 16)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _steps[_currentOrder[i]],
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                                  ),
                                ),
                                const Icon(Icons.drag_indicator_rounded, color: Colors.white54),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  ElevatedButton.icon(
                    onPressed: _verifyOrder,
                    icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                    label: const Text('Programı Çalıştır & Kilidi Doğrula', style: TextStyle(fontWeight: FontWeight.w900)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: KidsTheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
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
