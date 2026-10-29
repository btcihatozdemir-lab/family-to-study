import 'package:flutter/material.dart';
import '../../../theme/kids_theme.dart';
import '../../../models/user_model.dart';
import '../../../services/supabase_service.dart';

class RegionalLeaderboardModal extends StatefulWidget {
  final UserModel student;

  const RegionalLeaderboardModal({
    super.key,
    required this.student,
  });

  static void show(BuildContext context, UserModel student) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RegionalLeaderboardModal(student: student),
    );
  }

  @override
  State<RegionalLeaderboardModal> createState() => _RegionalLeaderboardModalState();
}

class _RegionalLeaderboardModalState extends State<RegionalLeaderboardModal> with SingleTickerProviderStateMixin {
  late TabController _scopeTabController;
  String _selectedSubject = 'matematik';
  List<dynamic> _leaderboard = [];
  bool _isLoading = true;
  String _studentCity = 'Düzce';

  @override
  void initState() {
    super.initState();
    _scopeTabController = TabController(length: 3, vsync: this);
    _studentCity = widget.student.city;
    _scopeTabController.addListener(() {
      if (!_scopeTabController.indexIsChanging) {
        _loadLeaderboard();
      }
    });
    _loadLeaderboard();
  }

  @override
  void dispose() {
    _scopeTabController.dispose();
    super.dispose();
  }

  String _getScope() {
    switch (_scopeTabController.index) {
      case 0:
        return 'city';
      case 1:
        return 'region';
      case 2:
        return 'school';
      default:
        return 'city';
    }
  }

  Future<void> _loadLeaderboard() async {
    setState(() => _isLoading = true);
    final scope = _getScope();
    final res = await SupabaseService.fetchRegionalLeaderboard(
      studentId: widget.student.id,
      subject: _selectedSubject,
      scope: scope,
    );

    if (mounted) {
      setState(() {
        _leaderboard = res['leaderboard'] is List ? res['leaderboard'] : [];
        if (res['student_city'] != null) {
          _studentCity = res['student_city'].toString();
        }
        _isLoading = false;
      });
    }
  }

  void _showCityEditDialog() {
    final cityCtrl = TextEditingController(text: _studentCity);
    final districtCtrl = TextEditingController(text: widget.student.district);
    final schoolCtrl = TextEditingController(text: widget.student.schoolName ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KidsTheme.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.location_on_rounded, color: KidsTheme.primary),
            SizedBox(width: 8),
            Text('Şehir & Okul Bilgisi', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: cityCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(labelText: 'Şehir / İl', labelStyle: TextStyle(color: KidsTheme.textMuted)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: districtCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(labelText: 'İlçe / Bölge', labelStyle: TextStyle(color: KidsTheme.textMuted)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: schoolCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: const InputDecoration(labelText: 'Okul Adı', labelStyle: TextStyle(color: KidsTheme.textMuted)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç', style: TextStyle(color: Colors.white60))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await SupabaseService.updateStudentLocation(
                studentId: widget.student.id,
                city: cityCtrl.text.trim(),
                district: districtCtrl.text.trim(),
                schoolName: schoolCtrl.text.trim(),
              );
              setState(() => _studentCity = cityCtrl.text.trim());
              _loadLeaderboard();
            },
            style: ElevatedButton.styleFrom(backgroundColor: KidsTheme.primary),
            child: const Text('Kaydet', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
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

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Text('📍', style: TextStyle(fontSize: 26)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '$_studentCity & Bölge Ligi',
                            style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: _showCityEditDialog,
                            child: const Icon(Icons.edit_location_alt_rounded, color: Color(0xFF38BDF8), size: 18),
                          ),
                        ],
                      ),
                      Text(
                        '${widget.student.gradeLevel}. Sınıf • Kendi Şehrin ve Çevre İllerdeki Sıralaman',
                        style: const TextStyle(color: KidsTheme.textMuted, fontSize: 11),
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
          const SizedBox(height: 8),

          // Scope Tabs (Şehrim, Çevre İller, Okulum)
          TabBar(
            controller: _scopeTabController,
            indicatorColor: KidsTheme.primary,
            labelColor: Colors.white,
            unselectedLabelColor: KidsTheme.textMuted,
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            tabs: [
              Tab(text: '🏛️ $_studentCity Geneli'),
              const Tab(text: '🌐 Çevre İller (Bölge)'),
              const Tab(text: '🏫 Okulum'),
            ],
          ),

          // Subject Chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildSubjectChip('matematik', '📐 Matematik Neti'),
                  const SizedBox(width: 8),
                  _buildSubjectChip('turkce', '📖 Türkçe & Kitap'),
                  const SizedBox(width: 8),
                  _buildSubjectChip('ingilizce', '🌍 İngilizce Kelime'),
                  const SizedBox(width: 8),
                  _buildSubjectChip('fen', '🔬 Fen Bilimleri'),
                ],
              ),
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: KidsTheme.primary))
                : _leaderboard.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _leaderboard.length,
                        itemBuilder: (ctx, i) {
                          final item = _leaderboard[i];
                          return _buildLeaderboardTile(item);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectChip(String subject, String label) {
    final isSelected = _selectedSubject == subject;
    return InkWell(
      onTap: () {
        setState(() => _selectedSubject = subject);
        _loadLeaderboard();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? KidsTheme.primary : KidsTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? KidsTheme.primary : Colors.white.withOpacity(0.08)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.leaderboard_outlined, color: KidsTheme.textMuted, size: 48),
            const SizedBox(height: 12),
            Text(
              '$_studentCity bölgesinde henüz sıralama oluşmadı',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Günün ilk sorusunu çözerek şehrinin liderlik tablosuna 1. sıradan adını yazdırabilirsin!',
              textAlign: TextAlign.center,
              style: TextStyle(color: KidsTheme.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaderboardTile(dynamic item) {
    final rank = item['rank'] ?? 1;
    final isMe = item['is_current_student'] == true;
    final isTop3 = rank <= 3;
    final medal = rank == 1 ? '🥇' : rank == 2 ? '🥈' : rank == 3 ? '🥉' : '#$rank';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isMe
            ? const Color(0xFF38BDF8).withOpacity(0.18)
            : isTop3
                ? KidsTheme.primary.withOpacity(0.1)
                : KidsTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMe
              ? const Color(0xFF38BDF8)
              : isTop3
                  ? KidsTheme.primary.withOpacity(0.3)
                  : Colors.white.withOpacity(0.06),
          width: isMe ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(medal, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      item['display_name'] ?? 'Öğrenci',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF38BDF8),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('SEN', style: TextStyle(color: Color(0xFF0F172A), fontSize: 9, fontWeight: FontWeight.w900)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${item['city'] ?? ''} • ${item['district'] ?? ''}',
                  style: const TextStyle(color: KidsTheme.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          _buildScoreBadge(item),
        ],
      ),
    );
  }

  Widget _buildScoreBadge(dynamic item) {
    if (_selectedSubject == 'matematik' || _selectedSubject == 'fen') {
      final net = (item['total_net'] as num?)?.toDouble() ?? 0.0;
      return Text(
        '${net.toStringAsFixed(1)} Net',
        style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.w900, fontSize: 14),
      );
    } else if (_selectedSubject == 'turkce') {
      final pages = item['total_pages_read'] ?? 0;
      return Text(
        '$pages Sayfa',
        style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w900, fontSize: 14),
      );
    } else if (_selectedSubject == 'ingilizce') {
      final words = item['total_words_learned'] ?? 0;
      return Text(
        '$words Kelime',
        style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.w900, fontSize: 14),
      );
    }
    final q = item['total_questions'] ?? 0;
    return Text('$q Soru', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13));
  }
}
