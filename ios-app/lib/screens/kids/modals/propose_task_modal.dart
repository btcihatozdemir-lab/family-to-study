import 'package:flutter/material.dart';
import '../../../models/user_model.dart';
import '../../../services/supabase_service.dart';
import '../../../theme/kids_theme.dart';

class ProposeTaskModal extends StatefulWidget {
  final UserModel student;
  final VoidCallback? onSuccess;

  const ProposeTaskModal({super.key, required this.student, this.onSuccess});

  static Future<void> show(BuildContext context, UserModel student, {VoidCallback? onSuccess}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProposeTaskModal(student: student, onSuccess: onSuccess),
    );
  }

  @override
  State<ProposeTaskModal> createState() => _ProposeTaskModalState();
}

class _ProposeTaskModalState extends State<ProposeTaskModal> {
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  int _proposedPoints = 30;
  bool _isSubmitting = false;

  final List<String> _quickTasks = [
    '🧹 Odamı baştan sona süpürüp sileceğim',
    '📚 Kitaplığımı alfabetik sıraya dizeceğim',
    '🪴 Evdeki tüm saksı bitkilerini sulayacağım',
    '🍽️ Akşam sofrasını eksiksiz kurup kaldıracağım',
    '👟 Aile ayakkabılık dolabını tertemiz dizeceğim',
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen önermek istediğin görevin başlığını yaz.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final ok = await SupabaseService.proposeTask(
      familyId: widget.student.familyId,
      studentId: widget.student.id,
      title: title,
      description: _descCtrl.text.trim(),
      points: _proposedPoints,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (ok) {
      Navigator.pop(context);
      widget.onSuccess?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Text('💡 ', style: TextStyle(fontSize: 20)),
              Expanded(
                child: Text(
                  'Tebrikler! Görev teklifin ebeveynine iletildi. Onaylanınca puanını kazanacaksın!',
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
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Görev önerisi iletilirken bir hata oluştu.'),
          backgroundColor: KidsTheme.rose,
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
                  color: KidsTheme.primary.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Text('💡', style: TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Anne/Babama Görev Öner',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Kendi inisiyatifinle yeni bir görev teklif et ve puan kazan!',
                      style: TextStyle(color: KidsTheme.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          const Text(
            'Hızlı Görev Fikirleri:',
            style: TextStyle(color: KidsTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _quickTasks.map((qt) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    backgroundColor: KidsTheme.surfaceElevated,
                    label: Text(qt, style: const TextStyle(fontSize: 11, color: Colors.white)),
                    onPressed: () {
                      setState(() {
                        _titleCtrl.text = qt;
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _titleCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              labelText: 'Görev Başlığı',
              labelStyle: const TextStyle(color: KidsTheme.textSecondary),
              hintText: 'Örn: Tüm ayakkabı dolabını baştan dizeceğim',
              hintStyle: const TextStyle(color: KidsTheme.textMuted, fontSize: 12),
              filled: true,
              fillColor: KidsTheme.surfaceElevated,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 10),

          TextField(
            controller: _descCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              labelText: 'Açıklama (İsteğe bağlı)',
              labelStyle: const TextStyle(color: KidsTheme.textSecondary),
              hintText: 'Nasıl yapacağını kısaca açıkla...',
              hintStyle: const TextStyle(color: KidsTheme.textMuted, fontSize: 12),
              filled: true,
              fillColor: KidsTheme.surfaceElevated,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 14),

          // Puan Seçici Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Önerilen Ödül:',
                style: TextStyle(color: KidsTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: KidsTheme.gold.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: KidsTheme.goldLight),
                ),
                child: Text(
                  '+$_proposedPoints Puan 🪙',
                  style: const TextStyle(color: KidsTheme.goldLight, fontWeight: FontWeight.w900, fontSize: 14),
                ),
              ),
            ],
          ),
          Slider(
            value: _proposedPoints.toDouble(),
            min: 10,
            max: 100,
            divisions: 18,
            activeColor: KidsTheme.gold,
            inactiveColor: Colors.white12,
            onChanged: (val) => setState(() => _proposedPoints = val.round()),
          ),
          const SizedBox(height: 14),

          ElevatedButton(
            onPressed: _isSubmitting ? null : _handleSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: KidsTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _isSubmitting
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.send_rounded, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Görev Teklifini İlet 💡',
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
