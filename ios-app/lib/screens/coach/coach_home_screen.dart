import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/fam_theme.dart';
import '../../services/coach_service.dart';
import '../../models/coach_group_model.dart';

class CoachHomeScreen extends StatefulWidget {
  const CoachHomeScreen({super.key});

  @override
  State<CoachHomeScreen> createState() => _CoachHomeScreenState();
}

class _CoachHomeScreenState extends State<CoachHomeScreen> {
  List<CoachGroupModel> _groups = [];
  CoachGroupModel? _selectedGroup;
  List<CoachStudentSummary> _students = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCoachData();
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
        await _loadGroupStudents(_selectedGroup!.id);
      } else {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadGroupStudents(String groupId) async {
    final list = await CoachService.fetchGroupStudentsSummary(groupId);
    if (mounted) {
      setState(() {
        _students = list;
        _isLoading = false;
      });
    }
  }

  void _showCreateGroupDialog() {
    final nameCtrl = TextEditingController(text: '7. Sınıf LGS Koçluk Grubu');
    int gradeLevel = 7;

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
              Text('Yeni Kademe Grubu Aç', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Grup Adı',
                  labelStyle: TextStyle(color: FamTheme.textMuted),
                  hintText: 'Örn: 7. Sınıf LGS Grubu',
                ),
              ),
              const SizedBox(height: 14),
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
            ],
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
                  final grp = await CoachService.createCoachGroup(name: name, gradeLevel: gradeLevel);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FamTheme.background,
      appBar: AppBar(
        backgroundColor: FamTheme.surface,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kademe Koçluk Masası', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
            Text('Öğretmen & Mentor Yönetim Portalı', style: TextStyle(fontSize: 11, color: FamTheme.textMuted)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: FamTheme.primaryLight),
            tooltip: 'Yeni Kademe Grubu Aç',
            onPressed: _showCreateGroupDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: FamTheme.primary))
          : _groups.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    _buildGroupHeader(),
                    Expanded(child: _buildStudentMatrix()),
                  ],
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
            const Icon(Icons.cast_for_education_rounded, size: 64, color: FamTheme.primaryLight),
            const SizedBox(height: 16),
            const Text(
              'Henüz Bir Kademe Grubu Açmadınız',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              'Öğrencilerinizin soru, kitap ve ödev takibini tek ekrandan yürütmek için ilk grubunuzu başlatın.',
              textAlign: TextAlign.center,
              style: TextStyle(color: FamTheme.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _showCreateGroupDialog,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text('İlk Kademe Grubumu Aç', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
    return Container(
      padding: const EdgeInsets.all(16),
      color: FamTheme.surface,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedGroup?.name ?? '',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
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
                        Clipboard.setData(ClipboardData(text: _selectedGroup?.groupCode ?? ''));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Grup davet kodu panoya kopyalandı!')),
                        );
                      },
                      child: const Icon(Icons.copy_rounded, color: FamTheme.textMuted, size: 16),
                    ),
                  ],
                ),
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
            label: const Text('Tümünü Onayla', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: FamTheme.emerald),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentMatrix() {
    if (_students.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.group_off_rounded, color: FamTheme.textMuted, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Grupta Henüz Öğrenci Yok',
              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Öğrencilere "${_selectedGroup?.groupCode}" kodunu vererek katılmalarını sağlayın.',
              style: const TextStyle(color: FamTheme.textMuted, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _students.length,
      itemBuilder: (ctx, i) {
        final s = _students[i];
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
                    Text(
                      '${s.totalQuestionsSolved} Soru • ${s.totalPagesRead} Sayfa Kitap',
                      style: const TextStyle(color: FamTheme.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: s.isTodayComplete ? FamTheme.emerald.withOpacity(0.2) : FamTheme.amber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  s.isTodayComplete ? 'Tamamlandı' : 'Bekliyor',
                  style: TextStyle(
                    color: s.isTodayComplete ? FamTheme.emerald : FamTheme.amber,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
