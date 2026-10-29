import 'package:flutter/material.dart';
import '../../../theme/kids_theme.dart';
import '../../../models/user_model.dart';
import '../../../models/coach_group_model.dart';
import '../../../services/coach_service.dart';

class SubjectCoachDiscoveryModal extends StatefulWidget {
  final UserModel student;

  const SubjectCoachDiscoveryModal({
    super.key,
    required this.student,
  });

  @override
  State<SubjectCoachDiscoveryModal> createState() => _SubjectCoachDiscoveryModalState();
}

class _SubjectCoachDiscoveryModalState extends State<SubjectCoachDiscoveryModal> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<CoachGroupModel> _discoveredCoaches = [];
  bool _isLoading = true;
  String _selectedSubject = '';
  final TextEditingController _cityFilterCtrl = TextEditingController();

  // Günlük İstatistik Giriş Kontrolleri
  String _logSubject = 'matematik';
  final TextEditingController _questionsCtrl = TextEditingController(text: '30');
  final TextEditingController _correctCtrl = TextEditingController(text: '26');
  final TextEditingController _wrongCtrl = TextEditingController(text: '4');
  final TextEditingController _pagesCtrl = TextEditingController(text: '20');
  final TextEditingController _wordsCtrl = TextEditingController(text: '5');
  final TextEditingController _idiomsCtrl = TextEditingController(text: '2');
  final TextEditingController _durationCtrl = TextEditingController(text: '45');
  bool _isLogging = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCoaches();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _cityFilterCtrl.dispose();
    _questionsCtrl.dispose();
    _correctCtrl.dispose();
    _wrongCtrl.dispose();
    _pagesCtrl.dispose();
    _wordsCtrl.dispose();
    _idiomsCtrl.dispose();
    _durationCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCoaches() async {
    setState(() => _isLoading = true);
    final list = await CoachService.discoverCoachGroups(
      gradeLevel: widget.student.gradeLevel,
      subject: _selectedSubject.isNotEmpty ? _selectedSubject : null,
      city: _cityFilterCtrl.text.trim().isNotEmpty ? _cityFilterCtrl.text.trim() : null,
    );
    if (mounted) {
      setState(() {
        _discoveredCoaches = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _submitDailyLog() async {
    setState(() => _isLogging = true);
    final q = int.tryParse(_questionsCtrl.text.trim()) ?? 0;
    final c = int.tryParse(_correctCtrl.text.trim()) ?? 0;
    final w = int.tryParse(_wrongCtrl.text.trim()) ?? 0;
    final p = int.tryParse(_pagesCtrl.text.trim()) ?? 0;
    final words = int.tryParse(_wordsCtrl.text.trim()) ?? 0;
    final idioms = int.tryParse(_idiomsCtrl.text.trim()) ?? 0;
    final dur = int.tryParse(_durationCtrl.text.trim()) ?? 0;

    final res = await CoachService.logSubjectActivity(
      studentUserId: widget.student.id,
      familyId: widget.student.familyId,
      subject: _logSubject,
      questions: q,
      correct: c,
      wrong: w,
      pagesRead: p,
      wordsLearned: words,
      idiomsLearned: idioms,
      durationMinutes: dur,
    );

    if (mounted) {
      setState(() => _isLogging = false);
      if (res['success'] == true) {
        final net = res['net_score'] ?? 0.0;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: KidsTheme.emerald,
            content: Text('🎉 Harika! $_logSubject dersin başarıyla kaydedildi. Net: $net. Veli ve Koçuna iletildi!'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: KidsTheme.rose,
            content: Text(res['message'] ?? 'Kayıt yapılırken bir hata oluştu.'),
          ),
        );
      }
    }
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
          // Tutamaç & Başlık
          const SizedBox(height: 12),
          Container(
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Text('🎓', style: TextStyle(fontSize: 26)),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Branş Koçları & Kulüpler',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                      Text(
                        'Matematik, Türkçe, İngilizce Ligi & Günlük Net Kaydı',
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
          const SizedBox(height: 10),

          // Tab Bar
          TabBar(
            controller: _tabController,
            indicatorColor: KidsTheme.primary,
            labelColor: Colors.white,
            unselectedLabelColor: KidsTheme.textMuted,
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            tabs: const [
              Tab(icon: Icon(Icons.search_rounded, size: 18), text: 'Koçları Keşfet'),
              Tab(icon: Icon(Icons.edit_note_rounded, size: 18), text: 'Dersini Kaydet'),
            ],
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDiscoveryTab(),
                _buildLogSubjectTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscoveryTab() {
    return Column(
      children: [
        // Filtreler (Dersler & Konum)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('', 'Tüm Dersler'),
                const SizedBox(width: 8),
                _buildFilterChip('matematik', '📐 Matematik'),
                const SizedBox(width: 8),
                _buildFilterChip('turkce', '📖 Türkçe'),
                const SizedBox(width: 8),
                _buildFilterChip('ingilizce', '🌍 İngilizce'),
                const SizedBox(width: 8),
                _buildFilterChip('fen', '🔬 Fen Bilimleri'),
              ],
            ),
          ),
        ),

        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: KidsTheme.primary))
              : _discoveredCoaches.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.school_outlined, color: KidsTheme.textMuted, size: 48),
                          const SizedBox(height: 12),
                          const Text(
                            'Bu Filtrede Açık Koçluk Kulübü Bulunamadı',
                            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${widget.student.gradeLevel}. Sınıf için öğretmeninizden grup davet kodu isteyebilirsiniz.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: KidsTheme.textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _discoveredCoaches.length,
                      itemBuilder: (ctx, i) {
                        final coach = _discoveredCoaches[i];
                        return _buildCoachCard(coach);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String subject, String label) {
    final isSelected = _selectedSubject == subject;
    return InkWell(
      onTap: () {
        setState(() => _selectedSubject = subject);
        _loadCoaches();
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
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildCoachCard(CoachGroupModel coach) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KidsTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: KidsTheme.primary.withOpacity(0.2),
                child: const Text('🎓', style: TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(coach.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(
                      '${coach.city.isNotEmpty ? coach.city : 'Türkiye'} • ${coach.gradeLevel}. Sınıf • 👥 ${coach.activeStudentsCount} Öğrenci',
                      style: const TextStyle(color: KidsTheme.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () => _handleApply(coach),
                style: ElevatedButton.styleFrom(
                  backgroundColor: KidsTheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Katıl', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
              ),
            ],
          ),
          if (coach.bio.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(coach.bio, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ],
      ),
    );
  }

  Future<void> _handleApply(CoachGroupModel coach) async {
    final res = await CoachService.applyToCoachGroup(
      groupCode: coach.groupCode,
      studentUserId: widget.student.id,
      familyId: widget.student.familyId,
      requiresParentApproval: true,
    );

    if (mounted) {
      if (res['success'] == true) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: KidsTheme.surfaceElevated,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.mark_email_read_rounded, color: KidsTheme.emerald),
                SizedBox(width: 8),
                Text('Başvuru İletildi! 🎉', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Text(
              '${coach.name} grubuna katılma isteğin alındı.\n\n'
              'Güvenliğin için veline (anne/babana) onay bildirimi gönderildi. Onaylandığında gruptaki lig sıralamasına katılacaksın!',
              style: const TextStyle(color: KidsTheme.textMuted, fontSize: 13, height: 1.4),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(backgroundColor: KidsTheme.emerald),
                child: const Text('Tamam', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: KidsTheme.rose, content: Text(res['message'] ?? 'Başvuru yapılamadı.')),
        );
      }
    }
  }

  Widget _buildLogSubjectTab() {
    final isTurkce = _logSubject == 'turkce';
    final isIngilizce = _logSubject == 'ingilizce';
    final isMatematikOrFen = _logSubject == 'matematik' || _logSubject == 'fen';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Ders Seçimi
          DropdownButtonFormField<String>(
            value: _logSubject,
            dropdownColor: KidsTheme.surfaceElevated,
            decoration: const InputDecoration(labelText: 'Hangi Ders Üzerine Çalıştın?', labelStyle: TextStyle(color: KidsTheme.textMuted)),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            items: const [
              DropdownMenuItem(value: 'matematik', child: Text('📐 Matematik')),
              DropdownMenuItem(value: 'turkce', child: Text('📖 Türkçe & Edebiyat')),
              DropdownMenuItem(value: 'ingilizce', child: Text('🌍 İngilizce')),
              DropdownMenuItem(value: 'fen', child: Text('🔬 Fen Bilimleri')),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _logSubject = v);
            },
          ),
          const SizedBox(height: 16),

          // Soru & Net Alanları
          Row(
            children: [
              Expanded(
                child: _buildInputField(_questionsCtrl, 'Çözülen Soru', 'Örn: 30', Icons.help_outline_rounded),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildInputField(_durationCtrl, 'Süre (Dakika)', 'Örn: 40', Icons.timer_outlined),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (isMatematikOrFen) ...[
            Row(
              children: [
                Expanded(child: _buildInputField(_correctCtrl, 'Doğru Sayısı', 'Örn: 26', Icons.check_circle_outline)),
                const SizedBox(width: 10),
                Expanded(child: _buildInputField(_wrongCtrl, 'Yanlış Sayısı', 'Örn: 4', Icons.cancel_outlined)),
              ],
            ),
            const SizedBox(height: 12),
          ],

          if (isTurkce) ...[
            Row(
              children: [
                Expanded(child: _buildInputField(_pagesCtrl, 'Okunan Kitap (Sayfa)', 'Örn: 25', Icons.menu_book_rounded)),
                const SizedBox(width: 10),
                Expanded(child: _buildInputField(_idiomsCtrl, 'Yeni Deyim / Atasözü', 'Örn: 2', Icons.lightbulb_outline)),
              ],
            ),
            const SizedBox(height: 12),
            _buildInputField(_wordsCtrl, 'Öğrenilen Yeni Kelimeler', 'Örn: 5', Icons.translate_rounded),
            const SizedBox(height: 12),
          ],

          if (isIngilizce) ...[
            _buildInputField(_wordsCtrl, 'Yeni İngilizce Kelime Sayısı', 'Örn: 8 (Vocabulary)', Icons.language_rounded),
            const SizedBox(height: 12),
          ],

          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _isLogging ? null : _submitDailyLog,
            style: ElevatedButton.styleFrom(
              backgroundColor: KidsTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _isLogging
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.rocket_launch_rounded, size: 20),
                      SizedBox(width: 8),
                      Text('Ders Başarımı Kaydet & XP Kazan', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField(TextEditingController ctrl, String label, String hint, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: KidsTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: KidsTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w700),
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 12),
          border: InputBorder.none,
          prefixIcon: Icon(icon, color: const Color(0xFF38BDF8), size: 18),
        ),
      ),
    );
  }
}
