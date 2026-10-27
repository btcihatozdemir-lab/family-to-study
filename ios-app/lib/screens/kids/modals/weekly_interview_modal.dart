import 'package:flutter/material.dart';
import '../../../models/user_model.dart';
import '../../../services/supabase_service.dart';
import '../../../theme/kids_theme.dart';

class WeeklyInterviewModal extends StatefulWidget {
  final UserModel student;
  final VoidCallback? onSuccess;

  const WeeklyInterviewModal({super.key, required this.student, this.onSuccess});

  static Future<void> show(BuildContext context, UserModel student, {VoidCallback? onSuccess}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WeeklyInterviewModal(student: student, onSuccess: onSuccess),
    );
  }

  @override
  State<WeeklyInterviewModal> createState() => _WeeklyInterviewModalState();
}

class _WeeklyInterviewModalState extends State<WeeklyInterviewModal> {
  final TextEditingController _answerCtrl = TextEditingController();
  bool _isSaving = false;
  final String _weeklyQuestion = 'Bu hafta seni en çok güldüren veya gururlandıran an neydi?';

  @override
  void dispose() {
    _answerCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final note = _answerCtrl.text.trim();
    if (note.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen hatıranı birkaç cümleyle yaz veya not et.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final ok = await SupabaseService.saveWeeklyInterview(
      studentId: widget.student.id,
      familyId: widget.student.familyId,
      questionText: _weeklyQuestion,
      answerNote: note,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (ok) {
      Navigator.pop(context);
      widget.onSuccess?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Text('🎙️ ', style: TextStyle(fontSize: 20)),
              Expanded(
                child: Text(
                  'Harika! Anı kapsülün kaydedildi ve +15 Hatıra Puanı kazandın! 🎉',
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: KidsTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
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
                  color: KidsTheme.purpleAccent.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Text('🎙️', style: TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pazar Röportajı & Anı Kapsülü',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Gelecekteki kendine sesli ve yazılı hatıra bırak',
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
              color: KidsTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: KidsTheme.purpleAccent.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text('❓', style: TextStyle(fontSize: 16)),
                    SizedBox(width: 6),
                    Text(
                      'Haftanın Özel Sorusu:',
                      style: TextStyle(color: KidsTheme.goldLight, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _weeklyQuestion,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          TextField(
            controller: _answerCtrl,
            maxLines: 3,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Cevabını buraya yaz... (Örn: Matematik sınavından 100 aldığım an çok mutlu oldum!)',
              hintStyle: const TextStyle(color: KidsTheme.textMuted, fontSize: 12),
              filled: true,
              fillColor: KidsTheme.surfaceElevated,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 18),

          ElevatedButton(
            onPressed: _isSaving ? null : _handleSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: KidsTheme.purpleAccent,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.save_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Anı Kapsülüne Kaydet (+15 Puan) 🎙️',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
