import 'package:flutter/material.dart';
import '../../../theme/kids_theme.dart';
import '../../../models/user_model.dart';
import '../../../models/family_contract_model.dart';
import '../../../services/supabase_service.dart';

class FamilyNewspaperModal extends StatefulWidget {
  final UserModel student;

  const FamilyNewspaperModal({
    super.key,
    required this.student,
  });

  static void show(BuildContext context, UserModel student) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FamilyNewspaperModal(student: student),
    );
  }

  @override
  State<FamilyNewspaperModal> createState() => _FamilyNewspaperModalState();
}

class _FamilyNewspaperModalState extends State<FamilyNewspaperModal> {
  WeeklyNewspaperModel? _newspaper;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNewspaper();
  }

  Future<void> _loadNewspaper() async {
    setState(() => _isLoading = true);
    final paper = await SupabaseService.fetchWeeklyNewspaper(widget.student.familyId);
    if (mounted) {
      setState(() {
        _newspaper = paper;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
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
          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Text('📰', style: TextStyle(fontSize: 22)),
                    SizedBox(width: 8),
                    Text(
                      'Haftalık Aile Gazetesi',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
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
                : _newspaper == null
                    ? const Center(child: Text('Gazete yüklenemedi.', style: TextStyle(color: KidsTheme.textMuted)))
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Gazete Künyesi
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: const BoxDecoration(
                                border: Border(
                                  top: BorderSide(color: Colors.white24, width: 2),
                                  bottom: BorderSide(color: Colors.white24, width: 2),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    'THE ${widget.student.name.toUpperCase()} POSTASI',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontFamily: 'serif',
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Pazar Akşamı Özel Baskısı • Aile Başarı ve Mizah Gazetesi',
                                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Manşet
                            Text(
                              _newspaper!.headline,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFFFBBF24),
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _newspaper!.subheadline,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Rakamlarla Bu Hafta
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.04),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: Colors.white10),
                                    ),
                                    child: Column(
                                      children: [
                                        const Text('📐 Çözülen Soru', style: TextStyle(color: KidsTheme.textMuted, fontSize: 11)),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${_newspaper!.totalQuestions}',
                                          style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 20, fontWeight: FontWeight.w900),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.04),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: Colors.white10),
                                    ),
                                    child: Column(
                                      children: [
                                        const Text('📖 Kitap Sayfası', style: TextStyle(color: KidsTheme.textMuted, fontSize: 11)),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${_newspaper!.totalPagesRead}',
                                          style: const TextStyle(color: Color(0xFF10B981), fontSize: 20, fontWeight: FontWeight.w900),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Haber Hikayeleri
                            ..._newspaper!.stories.map((story) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.03),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '📌 ${story['title'] ?? ''}',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      story['body'] ?? '',
                                      style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
