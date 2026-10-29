import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/fam_theme.dart';
import '../../services/coach_service.dart';
import '../../services/supabase_service.dart';
import '../../models/coach_group_model.dart';
import 'coach_auth_screen.dart';

class CoachHomeScreen extends StatefulWidget {
  const CoachHomeScreen({super.key});

  @override
  State<CoachHomeScreen> createState() => _CoachHomeScreenState();
}

class _CoachHomeScreenState extends State<CoachHomeScreen> with SingleTickerProviderStateMixin {
  List<CoachGroupModel> _groups = [];
  CoachGroupModel? _selectedGroup;
  List<CoachStudentSummary> _students = [];
  List<CoachLeaderboardEntry> _leaderboard = [];
  bool _isLoading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadCoachData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCoachData() async {
    setState(() => _isLoading = true);
    final groups = await CoachService.fetchMyCoachGroups();
    if (mounted) {
      setState(() {
        _groups = groups;
        if (groups.isNotEmpty) {
          _selectedGroup = groups.first;
        }
      });
      if (_selectedGroup != null) {
        await _loadGroupDetails(_selectedGroup!.id);
      } else {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadGroupDetails(String groupId) async {
    final list = await CoachService.fetchGroupStudentsSummary(groupId);
    final lboard = await CoachService.getCoachGroupLeaderboard(groupId);
    if (mounted) {
      setState(() {
        _students = list;
        _leaderboard = lboard;
        _isLoading = false;
      });
    }
  }

  void _showCreateGroupDialog() {
    final nameCtrl = TextEditingController(text: '7. Sınıf Matematik Koçluğu');
    final schoolCtrl = TextEditingController();
    final cityCtrl = TextEditingController(text: 'Düzce');
    final districtCtrl = TextEditingController(text: 'Akçakoca');
    final bioCtrl = TextEditingController(text: 'Beceri temelli yeni nesil soru ve net artışı koçluğu.');
    int gradeLevel = 7;
    String subject = 'matematik';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          backgroundColor: FamTheme.surfaceElevated,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.school_rounded, color: FamTheme.primary),
              SizedBox(width: 10),
              Text('Yeni Branş Koçluk Grubu', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Grup / Kulüp Adı',
                    labelStyle: TextStyle(color: FamTheme.textMuted),
                    hintText: 'Örn: 7. Sınıf LGS Matematik Kulübü',
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: subject,
                  dropdownColor: FamTheme.surfaceElevated,
                  decoration: const InputDecoration(labelText: 'Ders / Branş', labelStyle: TextStyle(color: FamTheme.textMuted)),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  items: const [
                    DropdownMenuItem(value: 'matematik', child: Text('📐 Matematik (Soru & Net)')),
                    DropdownMenuItem(value: 'turkce', child: Text('📖 Türkçe (Kitap, Deyim & Kelime)')),
                    DropdownMenuItem(value: 'ingilizce', child: Text('🌍 İngilizce (Soru & Kelime Haznesi)')),
                    DropdownMenuItem(value: 'fen', child: Text('🔬 Fen Bilimleri (Soru & Net)')),
                    DropdownMenuItem(value: 'sosyal', child: Text('🏛️ Sosyal Bilgiler (Soru & Net)')),
                    DropdownMenuItem(value: 'lgs_genel', child: Text('🎯 LGS Genel Koçluk')),
                  ],
                  onChanged: (v) {
                    if (v != null) setDState(() => subject = v);
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  value: gradeLevel,
                  dropdownColor: FamTheme.surfaceElevated,
                  decoration: const InputDecoration(labelText: 'Kademe Seviyesi', labelStyle: TextStyle(color: FamTheme.textMuted)),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  items: List.generate(12, (i) => i + 1)
                      .map((lvl) => DropdownMenuItem(value: lvl, child: Text('$lvl. Sınıf')))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDState(() => gradeLevel = v);
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: cityCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        decoration: const InputDecoration(labelText: 'İl / Şehir', labelStyle: TextStyle(color: FamTheme.textMuted)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: districtCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        decoration: const InputDecoration(labelText: 'İlçe / Bölge', labelStyle: TextStyle(color: FamTheme.textMuted)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: schoolCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: const InputDecoration(
                    labelText: 'Okul / Kurum (İsteğe Bağlı)',
                    labelStyle: TextStyle(color: FamTheme.textMuted),
                    hintText: 'Örn: Akçakoca Ortaokulu',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: bioCtrl,
                  maxLines: 2,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: const InputDecoration(
                    labelText: 'Koçluk Tanıtımı & Hedefler',
                    labelStyle: TextStyle(color: FamTheme.textMuted),
                    hintText: 'Öğrenciler için haftalık hedeflerinizi özetleyin',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Vazgeç', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isNotEmpty) {
                  Navigator.pop(ctx);
                  final grp = await CoachService.createCoachGroup(
                    name: name,
                    gradeLevel: gradeLevel,
                    subject: subject,
                    schoolName: schoolCtrl.text.trim(),
                    city: cityCtrl.text.trim(),
                    district: districtCtrl.text.trim(),
                    bio: bioCtrl.text.trim(),
                  );
                  if (grp != null) {
                    _loadCoachData();
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: FamTheme.primary),
              child: const Text('Grubu Başlat', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FamTheme.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: FamTheme.rose, size: 24),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Koç Hesabını Sil',
                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: const Text(
          'Dikkat: Bu işlem geri alınamaz!\n\n'
          '• Oluşturduğunuz tüm kademe grupları silinir.\n'
          '• Öğrenci bağlantıları ve ödev kayıtları tamamen temizlenir.\n'
          '• Hesabınız App Store ve KVKK kurallarına uygun olarak anında yok edilir.',
          style: TextStyle(color: FamTheme.textMuted, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Vazgeç', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _performDeleteAccount();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: FamTheme.rose,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text(
              'Evet, Hesabımı Kalıcı Olarak Sil',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _performDeleteAccount() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: FamTheme.rose),
      ),
    );

    final res = await CoachService.deleteCoachAccount();

    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: FamTheme.rose,
            content: Text(res['message'] ?? 'Koç hesabınız kalıcı olarak silindi.'),
          ),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const CoachAuthScreen()),
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: FamTheme.rose,
            content: Text(res['message'] ?? 'Silme işlemi gerçekleştirilemedi.'),
          ),
        );
      }
    }
  }

  Future<void> _handleSignOut() async {
    await SupabaseService.client.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const CoachAuthScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FamTheme.background,
      appBar: AppBar(
        backgroundColor: FamTheme.surface,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _selectedGroup != null
                  ? '${_selectedGroup!.name} (${_getSubjectEmoji(_selectedGroup!.subject)})'
                  : 'Branş Koçluk Masası',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white),
            ),
            Text(
              _selectedGroup != null ? '${_selectedGroup!.city} • ${_selectedGroup!.gradeLevel}. Sınıf' : 'Öğretmen & Mentor Masası',
              style: const TextStyle(fontSize: 11, color: FamTheme.textMuted),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: FamTheme.primaryLight),
            tooltip: 'Yeni Kademe Grubu Aç',
            onPressed: _showCreateGroupDialog,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white70),
            color: FamTheme.surfaceElevated,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onSelected: (val) {
              if (val == 'logout') {
                _handleSignOut();
              } else if (val == 'delete_account') {
                _showDeleteAccountDialog();
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                enabled: false,
                child: Text(
                  SupabaseService.client.auth.currentUser?.email ?? 'Koç Hesabı',
                  style: const TextStyle(fontSize: 12, color: FamTheme.textMuted, fontWeight: FontWeight.bold),
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, color: Colors.white70, size: 18),
                    SizedBox(width: 10),
                    Text('Oturumu Kapat', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete_account',
                child: Row(
                  children: [
                    Icon(Icons.delete_forever_rounded, color: FamTheme.rose, size: 18),
                    SizedBox(width: 10),
                    Text('Hesabımı Kalıcı Olarak Sil', style: TextStyle(color: FamTheme.rose, fontSize: 13, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: FamTheme.primary,
          labelColor: Colors.white,
          unselectedLabelColor: FamTheme.textMuted,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          tabs: const [
            Tab(icon: Icon(Icons.groups_rounded, size: 18), text: 'Öğrenciler'),
            Tab(icon: Icon(Icons.doorbell_rounded, size: 18), text: 'Başvurular'),
            Tab(icon: Icon(Icons.emoji_events_rounded, size: 18), text: 'Grup Ligi'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: FamTheme.primary))
          : _groups.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    _buildGroupHeader(),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildActiveStudentsView(),
                          _buildPendingApplicationsView(),
                          _buildLeaderboardView(),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  String _getSubjectEmoji(String subject) {
    switch (subject.toLowerCase()) {
      case 'matematik':
        return '📐 Matematik';
      case 'turkce':
        return '📖 Türkçe';
      case 'ingilizce':
        return '🌍 İngilizce';
      case 'fen':
        return '🔬 Fen';
      case 'sosyal':
        return '🏛️ Sosyal';
      default:
        return '🎯 LGS';
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cast_for_education_rounded, size: 64, color: FamTheme.primaryLight),
            const SizedBox(height: 16),
            const Text(
              'Henüz Bir Branş Grubu Açmadınız',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              'Matematik, Türkçe veya İngilizce branşınızda öğrencileri toplayıp çetele ve lig başlatmak için ilk grubunuzu açın.',
              textAlign: TextAlign.center,
              style: TextStyle(color: FamTheme.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _showCreateGroupDialog,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text('İlk Branş Grubumu Başlat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: FamTheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupHeader() {
    final inviteLink = 'https://familytostudy.com/koc/${_selectedGroup?.groupCode}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: FamTheme.surface,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: FamTheme.primary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Kod: ${_selectedGroup?.groupCode}',
                        style: const TextStyle(color: FamTheme.primaryLight, fontWeight: FontWeight.w800, fontSize: 11),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: inviteLink));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('🔗 Katılım linki panoya kopyalandı! Velilere veya öğrencilere iletebilirsiniz.')),
                        );
                      },
                      child: const Row(
                        children: [
                          Icon(Icons.link_rounded, color: Color(0xFF38BDF8), size: 16),
                          SizedBox(width: 4),
                          Text('Katılım Linki', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
                if ((_selectedGroup?.bio ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    _selectedGroup!.bio,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: FamTheme.textMuted, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(backgroundColor: FamTheme.emerald, content: Text('Tüm teslim edilen görevler onaylandı! (+50 Puan)')),
              );
            },
            icon: const Icon(Icons.done_all_rounded, size: 16, color: Colors.white),
            label: const Text('Toplu Onay', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: FamTheme.emerald, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveStudentsView() {
    final active = _students.where((s) => s.status == 'approved').toList();
    if (active.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.group_off_rounded, color: FamTheme.textMuted, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Grupta Onaylı Öğrenci Yok',
              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Öğrencilere "${_selectedGroup?.groupCode}" kodunu verin veya katılım linkini paylaşın.',
              style: const TextStyle(color: FamTheme.textMuted, fontSize: 12),
            ),
          ],
        ),
      );
    }

    final sub = _selectedGroup?.subject ?? 'matematik';

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: active.length,
      itemBuilder: (ctx, i) {
        final s = active[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: FamTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: FamTheme.primary.withOpacity(0.2),
                child: const Text('🎓', style: TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.studentName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                    const SizedBox(height: 4),
                    _buildStudentMetricSubtitle(s, sub),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline_rounded, color: FamTheme.rose, size: 20),
                tooltip: 'Gruptan Çıkar',
                onPressed: () => _confirmRemoveStudent(s),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStudentMetricSubtitle(CoachStudentSummary s, String sub) {
    if (sub == 'matematik' || sub == 'fen') {
      return Text(
        '${s.totalQuestionsSolved} Soru • ${s.totalNet.toStringAsFixed(1)} Net',
        style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.w700),
      );
    } else if (sub == 'turkce') {
      return Text(
        '${s.totalPagesRead} Sayfa Kitap • ${s.totalIdiomsLearned} Deyim • ${s.totalWordsLearned} Kelime',
        style: const TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.w700),
      );
    } else if (sub == 'ingilizce') {
      return Text(
        '${s.totalWordsLearned} Yeni Kelime • ${s.totalQuestionsSolved} Soru',
        style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 12, fontWeight: FontWeight.w700),
      );
    }
    return Text(
      '${s.totalQuestionsSolved} Soru • ${s.totalPagesRead} Sayfa',
      style: const TextStyle(color: FamTheme.textMuted, fontSize: 12),
    );
  }

  Widget _buildPendingApplicationsView() {
    final pending = _students.where((s) => s.status.contains('pending')).toList();
    if (pending.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline_rounded, color: FamTheme.emerald, size: 48),
            SizedBox(height: 12),
            Text('Bekleyen Başvuru Yok', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
            SizedBox(height: 6),
            Text('Dışarıdan gelen yeni öğrenci talepleri burada listelenir.', style: TextStyle(color: FamTheme.textMuted, fontSize: 12)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: pending.length,
      itemBuilder: (ctx, i) {
        final s = pending[i];
        final isParentWait = s.status == 'pending_parent';
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: FamTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: FamTheme.amber.withOpacity(0.2),
                child: const Text('🚪', style: TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.studentName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(
                      isParentWait ? 'Veli Onayı Bekleniyor' : 'Koç Onayınız Bekleniyor',
                      style: TextStyle(
                        color: isParentWait ? FamTheme.amber : const Color(0xFF38BDF8),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check_circle_rounded, color: FamTheme.emerald, size: 28),
                    tooltip: 'Gruba Kabul Et',
                    onPressed: () async {
                      if (_selectedGroup != null) {
                        await CoachService.respondToApplication(
                          groupId: _selectedGroup!.id,
                          studentUserId: s.studentUserId,
                          action: 'coach_approve',
                        );
                        _loadGroupDetails(_selectedGroup!.id);
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel_rounded, color: FamTheme.rose, size: 28),
                    tooltip: 'Başvuruyu Reddet',
                    onPressed: () async {
                      if (_selectedGroup != null) {
                        await CoachService.respondToApplication(
                          groupId: _selectedGroup!.id,
                          studentUserId: s.studentUserId,
                          action: 'reject',
                        );
                        _loadGroupDetails(_selectedGroup!.id);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLeaderboardView() {
    if (_leaderboard.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emoji_events_outlined, color: FamTheme.textMuted, size: 48),
            SizedBox(height: 12),
            Text('Liderlik Tablosu Hazırlanıyor', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
            SizedBox(height: 6),
            Text('Öğrenciler soru çözüp kitap okudukça sıralama otomatik güncellenir.', style: TextStyle(color: FamTheme.textMuted, fontSize: 12)),
          ],
        ),
      );
    }

    final sub = _selectedGroup?.subject ?? 'matematik';

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _leaderboard.length,
      itemBuilder: (ctx, i) {
        final item = _leaderboard[i];
        final isTop3 = item.rank <= 3;
        final medal = item.rank == 1 ? '🥇' : item.rank == 2 ? '🥈' : item.rank == 3 ? '🥉' : '#${item.rank}';

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isTop3 ? FamTheme.primary.withOpacity(0.12) : FamTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isTop3 ? FamTheme.primary.withOpacity(0.4) : Colors.white.withOpacity(0.06)),
          ),
          child: Row(
            children: [
              Text(medal, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.studentName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                    const SizedBox(height: 4),
                    _buildLeaderboardMetricSubtitle(item, sub),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLeaderboardMetricSubtitle(CoachLeaderboardEntry item, String sub) {
    if (sub == 'matematik' || sub == 'fen') {
      return Text(
        '${item.totalNet.toStringAsFixed(1)} Net (${item.totalCorrect} D / ${item.totalWrong} Y)',
        style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.w800),
      );
    } else if (sub == 'turkce') {
      return Text(
        '${item.totalPagesRead} Sayfa • ${item.totalIdiomsLearned} Deyim/Atasözü • ${item.totalWordsLearned} Kelime',
        style: const TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.w800),
      );
    } else if (sub == 'ingilizce') {
      return Text(
        '${item.totalWordsLearned} Yeni İngilizce Kelime • ${item.totalQuestions} Soru',
        style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 12, fontWeight: FontWeight.w800),
      );
    }
    return Text('${item.totalQuestions} Soru Çözüldü', style: const TextStyle(color: FamTheme.textMuted, fontSize: 12));
  }

  void _confirmRemoveStudent(CoachStudentSummary s) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FamTheme.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Öğrenciyi Gruptan Çıkar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text(
          '${s.studentName} isimli öğrenciyi "${_selectedGroup?.name}" grubundan çıkarmak istediğinize emin misiniz?',
          style: const TextStyle(color: FamTheme.textMuted, fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç', style: TextStyle(color: Colors.white70))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (_selectedGroup != null) {
                await CoachService.respondToApplication(
                  groupId: _selectedGroup!.id,
                  studentUserId: s.studentUserId,
                  action: 'remove',
                );
                _loadGroupDetails(_selectedGroup!.id);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: FamTheme.rose),
            child: const Text('Gruptan Çıkar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
