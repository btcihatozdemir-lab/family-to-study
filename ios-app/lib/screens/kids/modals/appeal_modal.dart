import 'package:flutter/material.dart';
import '../../../models/user_model.dart';
import '../../../services/supabase_service.dart';
import '../../../theme/kids_theme.dart';

class AppealModal extends StatefulWidget {
  final UserModel student;
  final VoidCallback? onSuccess;

  const AppealModal({
    super.key,
    required this.student,
    this.onSuccess,
  });

  static Future<void> show(BuildContext context, UserModel student, {VoidCallback? onSuccess}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AppealModal(student: student, onSuccess: onSuccess),
    );
  }

  @override
  State<AppealModal> createState() => _AppealModalState();
}

class _AppealModalState extends State<AppealModal> {
  final TextEditingController _reasonCtrl = TextEditingController();
  bool _isSubmitting = false;
  String _selectedReason = 'Yanlışlıkla ekran kapandı / kaza oldu';

  final List<String> _quickReasons = [
    'Yanlışlıkla ekran kapandı / kaza oldu',
    'Görevi tam vaktinde bitirmiştim ama sistem algılamadı',
    'Kardeşim tableti elimden kaptı',
    'Ödevimi bitirdim ancak onay beklerken süre doldu',
  ];

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final text = _reasonCtrl.text.trim().isNotEmpty ? _reasonCtrl.text.trim() : _selectedReason;
    setState(() => _isSubmitting = true);

    final ok = await SupabaseService.submitAppeal(
      studentId: widget.student.id,
      familyId: widget.student.familyId,
      reasonText: text,
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
              Text('⚖️ ', style: TextStyle(fontSize: 20)),
              Expanded(
                child: Text(
                  'İtirazın Adalet Divanına (Anne/Babaya) iletildi! İncelenip kalkanın onarılacaktır.',
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
        SnackBar(
          content: const Text('Bugünkü itiraz hakkınızı zaten kullandınız veya bir hata oluştu.'),
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
                  color: KidsTheme.rose.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Text('⚖️', style: TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Adalet Divanı / Hakem Heyeti',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Kırılan kalkanın veya reddedilen görevin için itiraz et',
                      style: TextStyle(color: KidsTheme.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          const Text(
            'Hızlı Savunma Seçenekleri:',
            style: TextStyle(color: KidsTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          ..._quickReasons.map((reason) {
            final isSelected = _selectedReason == reason && _reasonCtrl.text.isEmpty;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedReason = reason;
                  _reasonCtrl.clear();
                });
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? KidsTheme.primary.withOpacity(0.25) : KidsTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? KidsTheme.primary : Colors.white12,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: isSelected ? KidsTheme.primary : Colors.white38,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        reason,
                        style: TextStyle(
                          color: isSelected ? Colors.white : KidsTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 8),
          TextField(
            controller: _reasonCtrl,
            maxLines: 2,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Veya kendi cümlenle açıkla: Ne oldu?',
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
            onPressed: _isSubmitting ? null : _handleSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: KidsTheme.rose,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.gavel_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'İtirazımı Anne/Babaya Gönder ⚖️',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
