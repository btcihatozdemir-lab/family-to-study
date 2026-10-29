import 'package:flutter/material.dart';
import '../../../theme/fam_theme.dart';
import '../../../models/user_model.dart';
import '../../../models/coach_group_model.dart';
import '../../../services/coach_service.dart';

class StudentSubjectReportModal extends StatefulWidget {
  final UserModel child;
  final String familyId;

  const StudentSubjectReportModal({
    super.key,
    required this.child,
    required this.familyId,
  });

  static void show(BuildContext context, UserModel child, String familyId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StudentSubjectReportModal(child: child, familyId: familyId),
    );
  }

  @override
  State<StudentSubjectReportModal> createState() => _StudentSubjectReportModalState();
}

class _StudentSubjectReportModalState extends State<StudentSubjectReportModal> {
  List<StudentSubjectSummary> _summaries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    final list = await CoachService.getStudentSubjectSummary(
      studentUserId: widget.child.id,
      familyId: widget.familyId,
    );
    if (mounted) {
      setState(() {
        _summaries = list;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: FamTheme.background,
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: FamTheme.primary.withOpacity(0.2),
                  child: Text(widget.child.avatarEmoji, style: const TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.child.name} - Akademik Branş Karnesi',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const Text(
                        'Son 30 Günlük Soru, Net, Kitap ve Kelime İstatistikleri',
                        style: TextStyle(color: FamTheme.textMuted, fontSize: 11),
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
                ? const Center(child: CircularProgressIndicator(color: FamTheme.primaryLight))
                : _summaries.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _summaries.length,
                        itemBuilder: (ctx, i) {
                          final item = _summaries[i];
                          return _buildSubjectReportCard(item);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📊', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 14),
            const Text(
              'Henüz Ders İstatistiği Kaydedilmedi',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.child.name} mobil uygulamadan veya Windows bilgisayarından soru çözüp kitap okudukça branş netleri burada canlı listelenecektir.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: FamTheme.textMuted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectReportCard(StudentSubjectSummary item) {
    final sub = item.subject.toLowerCase();
    String title = 'Genel Ders';
    String emoji = '📚';
    Color accentColor = FamTheme.primary;

    if (sub == 'matematik') {
      title = 'Matematik';
      emoji = '📐';
      accentColor = const Color(0xFF38BDF8);
    } else if (sub == 'turkce') {
      title = 'Türkçe & Edebiyat';
      emoji = '📖';
      accentColor = const Color(0xFF10B981);
    } else if (sub == 'ingilizce') {
      title = 'İngilizce (Yabancı Dil)';
      emoji = '🌍';
      accentColor = const Color(0xFFF59E0B);
    } else if (sub == 'fen') {
      title = 'Fen Bilimleri';
      emoji = '🔬';
      accentColor = const Color(0xFF8B5CF6);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FamTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${item.totalStudyMinutes} Dk Çalışma',
                  style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Metrik Grid
          Row(
            children: [
              _buildMetricTile('Çözülen Soru', '${item.totalQuestions}', Icons.help_outline),
              const SizedBox(width: 8),
              if (sub == 'matematik' || sub == 'fen') ...[
                _buildMetricTile('Net Başarısı', item.totalNet.toStringAsFixed(1), Icons.trending_up, color: const Color(0xFF38BDF8)),
                const SizedBox(width: 8),
                _buildMetricTile('Doğru / Yanlış', '${item.totalCorrect} / ${item.totalWrong}', Icons.done_all),
              ] else if (sub == 'turkce') ...[
                _buildMetricTile('Kitap (Sayfa)', '${item.totalPagesRead}', Icons.menu_book, color: const Color(0xFF10B981)),
                const SizedBox(width: 8),
                _buildMetricTile('Deyim / Atasözü', '${item.totalIdiomsLearned}', Icons.lightbulb, color: const Color(0xFFFBBF24)),
              ] else if (sub == 'ingilizce') ...[
                _buildMetricTile('Yeni Kelime', '${item.totalWordsLearned}', Icons.translate, color: const Color(0xFFF59E0B)),
                const SizedBox(width: 8),
                _buildMetricTile('Soru', '${item.totalQuestions}', Icons.quiz),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, IconData icon, {Color? color}) {
    final c = color ?? Colors.white70;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: FamTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Column(
          children: [
            Icon(icon, color: c, size: 16),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: FamTheme.textMuted, fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
