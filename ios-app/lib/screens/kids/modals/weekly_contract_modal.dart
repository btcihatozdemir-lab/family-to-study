import 'package:flutter/material.dart';
import '../../../theme/kids_theme.dart';
import '../../../models/user_model.dart';
import '../../../services/supabase_service.dart';

class WeeklyContractModal extends StatefulWidget {
  final UserModel student;

  const WeeklyContractModal({
    super.key,
    required this.student,
  });

  static void show(BuildContext context, UserModel student) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WeeklyContractModal(student: student),
    );
  }

  @override
  State<WeeklyContractModal> createState() => _WeeklyContractModalState();
}

class _WeeklyContractModalState extends State<WeeklyContractModal> {
  Map<String, dynamic> _contractData = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkContract();
  }

  Future<void> _checkContract() async {
    setState(() => _isLoading = true);
    final res = await SupabaseService.checkAndClaimWeeklyContract(
      familyId: widget.student.familyId,
      studentId: widget.student.id,
    );
    if (mounted) {
      setState(() {
        _contractData = res;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalQ = (_contractData['total_questions'] as num?)?.toInt() ?? 0;
    final targetQ = (_contractData['target_questions'] as num?)?.toInt() ?? 150;
    final totalP = (_contractData['total_pages'] as num?)?.toInt() ?? 0;
    final targetP = (_contractData['target_pages'] as num?)?.toInt() ?? 100;
    final isDone = _contractData['is_completed'] == true;
    final jokerEarned = _contractData['joker_day_earned'] == true;

    final qProgress = targetQ > 0 ? (totalQ / targetQ).clamp(0.0, 1.0) : 0.0;
    final pProgress = targetP > 0 ? (totalP / targetP).clamp(0.0, 1.0) : 0.0;

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
          const SizedBox(height: 16),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Text('📜', style: TextStyle(fontSize: 26)),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Haftalık Aile Sözleşmesi',
                        style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
                      ),
                      Text(
                        'Hedefini erken bitir -> Hafta sonu Joker Gün & +2 Saat Oyun Kazan!',
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
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: KidsTheme.primary))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Joker Gün Rozeti
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isDone
                                  ? [const Color(0xFF10B981).withOpacity(0.3), const Color(0xFF059669).withOpacity(0.15)]
                                  : [KidsTheme.primary.withOpacity(0.2), const Color(0xFF8B5CF6).withOpacity(0.15)],
                            ),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: isDone ? const Color(0xFF10B981) : KidsTheme.primary.withOpacity(0.4),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(isDone ? '🃏' : '⏳', style: const TextStyle(fontSize: 36)),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isDone ? 'Joker Gün Aktif! 🎉' : 'Joker Gün Hedefi',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      isDone
                                          ? 'Haftalık hedefini tamamladın! Hafta sonu +2 saat ekstra PC oyun süresi hesabına tanımlandı.'
                                          : 'Cuma akşamına kadar hedefleri tamamla, hafta sonu sınırsız keyif yap.',
                                      style: const TextStyle(color: KidsTheme.textMuted, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Soru Hedefi
                        _buildProgressCard(
                          title: 'Haftalık Soru Hedefi',
                          current: totalQ,
                          target: targetQ,
                          progress: qProgress,
                          icon: Icons.quiz_rounded,
                          color: const Color(0xFF38BDF8),
                          unit: 'Soru',
                        ),
                        const SizedBox(height: 14),

                        // Kitap Okuma Hedefi
                        _buildProgressCard(
                          title: 'Haftalık Kitap Hedefi',
                          current: totalP,
                          target: targetP,
                          progress: pProgress,
                          icon: Icons.menu_book_rounded,
                          color: const Color(0xFF10B981),
                          unit: 'Sayfa',
                        ),
                        const SizedBox(height: 24),

                        ElevatedButton.icon(
                          onPressed: _checkContract,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Durumu Güncelle & Joker Kontrolü Yap', style: TextStyle(fontWeight: FontWeight.bold)),
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

  Widget _buildProgressCard({
    required String title,
    required int current,
    required int target,
    required double progress,
    required IconData icon,
    required Color color,
    required String unit,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KidsTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: 8),
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              Text(
                '$current / $target $unit',
                style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}
