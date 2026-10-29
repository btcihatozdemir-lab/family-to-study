import 'package:flutter/material.dart';
import '../../../models/user_model.dart';
import '../../../services/supabase_service.dart';
import '../../../services/subscription_service.dart';
import '../../../services/tts_service.dart';
import '../../../theme/fam_theme.dart';

class FamilySettingsTab extends StatefulWidget {
  final String familyId;
  final VoidCallback onRefreshAll;

  const FamilySettingsTab({
    super.key,
    required this.familyId,
    required this.onRefreshAll,
  });

  @override
  State<FamilySettingsTab> createState() => _FamilySettingsTabState();
}

class _FamilySettingsTabState extends State<FamilySettingsTab> {
  List<UserModel> _members = [];
  Map<String, dynamic>? _settings;
  bool _isLoading = true;

  // Haftalık Program Editör Durumu
  UserModel? _selectedChildForSchedule;
  int _selectedDay = 1; // 1: Pazartesi
  final TextEditingController _lessonsController = TextEditingController();
  bool _hasPe = false;
  bool _hasArt = false;

  final List<String> _dayNames = [
    'Pazartesi',
    'Salı',
    'Çarşamba',
    'Perşembe',
    'Cuma',
    'Cumartesi',
    'Pazar'
  ];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _lessonsController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    final members = await SupabaseService.fetchFamilyMembers(widget.familyId);
    final settings = await SupabaseService.fetchFamilySettings(widget.familyId);

    if (mounted) {
      setState(() {
        _members = members;
        _settings = settings;
        final children = members.where((m) => m.role == 'child').toList();
        if (children.isNotEmpty && _selectedChildForSchedule == null) {
          _selectedChildForSchedule = children.first;
        }
        _isLoading = false;
      });
      _loadScheduleForDay();
    }
  }

  Future<void> _loadScheduleForDay() async {
    if (_selectedChildForSchedule == null) return;
    final sched = await SupabaseService.fetchDaySchedule(
      userId: _selectedChildForSchedule!.id,
      dayOfWeek: _selectedDay,
    );
    if (mounted) {
      setState(() {
        if (sched != null) {
          _lessonsController.text = sched.lessons.join(', ');
          _hasPe = sched.hasPeClass;
          _hasArt = sched.hasArtClass;
        } else {
          _lessonsController.clear();
          _hasPe = false;
          _hasArt = false;
        }
      });
    }
  }

  void _showAddMemberDialog() {
    String name = '';
    String role = 'parent';
    String roleTitle = 'Baba';
    String gender = 'male';
    String emoji = '👨‍💼';
    String grade = 'Yetişkin';
    String pin = '1234';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: FamTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(
            children: [
              Text('👤', style: TextStyle(fontSize: 22)),
              SizedBox(width: 8),
              Text('Yeni Aile Bireyi Ekle', style: TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Rol Seçici (Ebeveyn / Çocuk)
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('👨‍👩‍👧 Ebeveyn / Veli'),
                        selected: role == 'parent',
                        onSelected: (val) {
                          if (val) {
                            setDlgState(() {
                              role = 'parent';
                              roleTitle = 'Baba';
                              gender = 'male';
                              emoji = '👨‍💼';
                              grade = 'Yetişkin';
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('🧒 Öğrenci'),
                        selected: role == 'child',
                        onSelected: (val) {
                          if (val) {
                            setDlgState(() {
                              role = 'child';
                              roleTitle = 'Çocuk';
                              gender = 'female';
                              emoji = '🦄';
                              grade = '5. Sınıf';
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Akrabalık Unvanı (Baba, Anne, Abla, Abi, Hala, Dayı...)
                if (role == 'parent') ...[
                  const Text('Akrabalık Unvanı:', style: TextStyle(color: FamTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      {'t': 'Baba', 'e': '👨‍💼', 'g': 'male'},
                      {'t': 'Anne', 'e': '👩‍💼', 'g': 'female'},
                      {'t': 'Abla', 'e': '👧', 'g': 'female'},
                      {'t': 'Abi', 'e': '👦', 'g': 'male'},
                      {'t': 'Hala', 'e': '🧕', 'g': 'female'},
                      {'t': 'Dayı', 'e': '🧔', 'g': 'male'},
                      {'t': 'Teyze', 'e': '👩‍🦰', 'g': 'female'},
                      {'t': 'Amca', 'e': '👨‍🦰', 'g': 'male'},
                      {'t': 'Dede', 'e': '👴', 'g': 'male'},
                      {'t': 'Anneanne', 'e': '👵', 'g': 'female'},
                      {'t': 'Veli', 'e': '🧑‍✈️', 'g': 'male'},
                    ].map((item) {
                      final isSel = roleTitle == item['t'];
                      return InkWell(
                        onTap: () {
                          setDlgState(() {
                            roleTitle = item['t']!;
                            emoji = item['e']!;
                            gender = item['g']!;
                          });
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isSel ? FamTheme.primary : FamTheme.surfaceElevated,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isSel ? FamTheme.primaryLight : Colors.white12),
                          ),
                          child: Text('${item['e']} ${item['t']}', style: TextStyle(color: isSel ? Colors.white : Colors.white70, fontSize: 11)),
                        ),
                      );
                    }).toList(),
                  ),
                ] else ...[
                  // Çocuk Cinsiyeti
                  const Text('Öğrenci Cinsiyeti:', style: TextStyle(color: FamTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setDlgState(() {
                              gender = 'female';
                              emoji = '🦄';
                            });
                          },
                          icon: const Text('👧'),
                          label: const Text('Kız Öğrenci'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: gender == 'female' ? const Color(0xFFDB2777) : FamTheme.surfaceElevated,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setDlgState(() {
                              gender = 'male';
                              emoji = '🦁';
                            });
                          },
                          icon: const Text('👦'),
                          label: const Text('Erkek Öğrenci'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: gender == 'male' ? FamTheme.primary : FamTheme.surfaceElevated,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 12),

                // İsim
                TextField(
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Ad Soyad',
                    labelStyle: TextStyle(color: FamTheme.textMuted),
                    hintText: 'Örn: Ahmet Özdemir',
                    hintStyle: TextStyle(color: Colors.white24),
                  ),
                  onChanged: (v) => name = v,
                ),
                const SizedBox(height: 8),

                // Sınıf / Seviye
                if (role == 'child')
                  TextField(
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'Sınıf / Seviye',
                      labelStyle: TextStyle(color: FamTheme.textMuted),
                      hintText: 'Örn: 4. Sınıf',
                      hintStyle: TextStyle(color: Colors.white24),
                    ),
                    onChanged: (v) => grade = v,
                  ),

                const SizedBox(height: 8),

                // PIN / Giriş Şifresi
                TextField(
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Giriş PIN Kodu (6 Hane)',
                    labelStyle: TextStyle(color: FamTheme.textMuted),
                    hintText: '123456',
                    hintStyle: TextStyle(color: Colors.white24),
                  ),
                  onChanged: (v) => pin = v,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Vazgeç', style: TextStyle(color: FamTheme.textMuted)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (name.trim().isEmpty) return;

                // Free Tier Limiti: En fazla 1 çocuk profil eklenebilir
                final currentChildren = _members.where((m) => m.role == 'child').length;
                if (role == 'child' && currentChildren >= 1 && !SubscriptionService.isPro) {
                  Navigator.pop(ctx);
                  SubscriptionService.withProCheck(
                    context,
                    onAllowed: () => _showAddMemberDialog(),
                    featureTitle: '2. Çocuk ve Kardeş Ekleme',
                  );
                  return;
                }

                Navigator.pop(ctx);
                await SupabaseService.addFamilyMember(
                  familyId: widget.familyId,
                  name: name.trim(),
                  role: role,
                  roleTitle: roleTitle,
                  gender: gender,
                  emoji: emoji,
                  grade: grade,
                  pin: pin.trim().isNotEmpty ? pin.trim() : '123456',
                );
                _loadAll();
                widget.onRefreshAll();
              },
              style: ElevatedButton.styleFrom(backgroundColor: FamTheme.emerald),
              child: const Text('Ekle', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showUpdateChestDialog() {
    int goal = _settings?['family_chest_goal'] ?? 1000;
    String title = _settings?['family_chest_reward_title'] ?? 'Ailece Pizza & Sinema Gecesi!';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FamTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('🏺 Aile Hazine Sandığı Hedefi', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Hedef Ödül Başlığı',
                labelStyle: TextStyle(color: FamTheme.textMuted),
              ),
              controller: TextEditingController(text: title),
              onChanged: (v) => title = v,
            ),
            const SizedBox(height: 10),
            TextField(
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Hedef Puan',
                labelStyle: TextStyle(color: FamTheme.textMuted),
              ),
              controller: TextEditingController(text: goal.toString()),
              onChanged: (v) => goal = int.tryParse(v) ?? goal,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal', style: TextStyle(color: FamTheme.textMuted))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await SupabaseService.updateFamilyChestGoal(
                familyId: widget.familyId,
                goal: goal,
                title: title,
              );
              _loadAll();
            },
            style: ElevatedButton.styleFrom(backgroundColor: FamTheme.primary),
            child: const Text('Kaydet', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showOfflinePinDialog() {
    String pin = _settings?['offline_master_pin_hash'] ?? '1234';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FamTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('🔑 Çevrimdışı Master PIN', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'İnternet bağlantısı kesildiğinde veya acil durumlarda çocuk ekran kilidini doğrudan açmak için kullanılan şifredir.',
              style: TextStyle(color: FamTheme.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              style: const TextStyle(color: Colors.white, letterSpacing: 2, fontWeight: FontWeight.bold),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Yeni Master PIN',
                labelStyle: TextStyle(color: FamTheme.textMuted),
              ),
              controller: TextEditingController(text: pin.length > 6 ? pin.substring(0, 4) : pin),
              onChanged: (v) => pin = v,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal', style: TextStyle(color: FamTheme.textMuted))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await SupabaseService.updateOfflineMasterPin(
                familyId: widget.familyId,
                pin: pin.trim(),
              );
              _loadAll();
            },
            style: ElevatedButton.styleFrom(backgroundColor: FamTheme.primary),
            child: const Text('Güncelle', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveSchedule() async {
    if (_selectedChildForSchedule == null) return;
    final rawLessons = _lessonsController.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

    final ok = await SupabaseService.upsertSchoolScheduleItem(
      familyId: widget.familyId,
      userId: _selectedChildForSchedule!.id,
      dayOfWeek: _selectedDay,
      lessons: rawLessons,
      hasPeClass: _hasPe,
      hasArtClass: _hasArt,
    );

    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('📅 ${_dayNames[_selectedDay - 1]} ders programı başarıyla kaydedildi!'),
          backgroundColor: FamTheme.emerald,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: FamTheme.primaryLight));
    }

    final children = _members.where((m) => m.role == 'child').toList();
    final chestGoal = _settings?['family_chest_goal'] ?? 1000;
    final chestCurrent = _settings?['family_chest_current'] ?? 0;
    final chestTitle = _settings?['family_chest_reward_title'] ?? 'Ailece Pizza & Sinema Gecesi!';
    final chestProgress = (chestCurrent / chestGoal).clamp(0.0, 1.0);

    return RefreshIndicator(
      onRefresh: _loadAll,
      color: FamTheme.primaryLight,
      backgroundColor: FamTheme.surfaceElevated,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // 1. AİLE SANDIĞI HEDEFİ
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF831843), Color(0xFF4C0519), Color(0xFF1E1B4B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.pinkAccent.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Text('🏺', style: TextStyle(fontSize: 22)),
                        SizedBox(width: 8),
                        Text(
                          'AİLE HAZİNE SANDIĞI',
                          style: TextStyle(color: Colors.pinkAccent, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.1),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_rounded, color: Colors.white70, size: 18),
                      onPressed: _showUpdateChestDialog,
                    ),
                  ],
                ),
                Text(
                  chestTitle,
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: chestProgress,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.pinkAccent),
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('$chestCurrent Puan Birikti', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    Text('Hedef: $chestGoal Puan', style: const TextStyle(color: Colors.pinkAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 2. OTOMASYON, OTOPİLOT & HAPPY HOUR
          Container(
            padding: const EdgeInsets.all(16),
            decoration: FamTheme.cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text('⚡', style: TextStyle(fontSize: 20)),
                    SizedBox(width: 8),
                    Text(
                      'Veli Otopilot & Sürpriz İndirim',
                      style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          TTSService.speak('Veli otopilot modu 4 saatliğine aktif edildi.');
                          await SupabaseService.setParentAutopilot(familyId: widget.familyId, hours: 4);
                          _loadAll();
                        },
                        icon: const Icon(Icons.smart_toy_rounded, color: FamTheme.primaryLight, size: 16),
                        label: const Text('4 Saat Otopilot', style: TextStyle(color: Colors.white, fontSize: 11)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: FamTheme.primary.withOpacity(0.5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          TTSService.speak('Dikkat! Markette yüzde 30 sürpriz indirim başladı!');
                          await SupabaseService.startHappyHour(familyId: widget.familyId, discountPercent: 30, durationMinutes: 60);
                          _loadAll();
                        },
                        icon: const Icon(Icons.local_offer_rounded, color: Colors.amberAccent, size: 16),
                        label: const Text('%30 Happy Hour', style: TextStyle(color: Colors.white, fontSize: 11)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.amber.withOpacity(0.5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        onPressed: _showOfflinePinDialog,
                        icon: const Icon(Icons.key_rounded, color: FamTheme.cyan, size: 16),
                        label: const Text('Çevrimdışı Master PIN', style: TextStyle(color: FamTheme.cyan, fontSize: 11)),
                      ),
                    ),
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () async {
                          await SupabaseService.triggerSundayPiggyBonus(widget.familyId);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('🏺 +%20 Altın Kasa faizi çocuklara dağıtıldı!'), backgroundColor: FamTheme.emerald),
                          );
                        },
                        icon: const Icon(Icons.savings_rounded, color: Colors.amber, size: 16),
                        label: const Text('+%20 Kasa Faizi Dağıt', style: TextStyle(color: Colors.amber, fontSize: 11)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 3. AİLE BİREYLERİ LİSTESİ & YÖNETİMİ
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Text('👨‍👩‍👧‍👦', style: TextStyle(fontSize: 20)),
                  SizedBox(width: 8),
                  Text(
                    'Aile Bireyleri & Roller',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {
                  final currentChildren = _members.where((m) => m.role == 'child').length;
                  if (currentChildren >= 1 && !SubscriptionService.isPro) {
                    SubscriptionService.withProCheck(
                      context,
                      onAllowed: _showAddMemberDialog,
                      featureTitle: 'Birden Fazla Çocuk Ekleme',
                    );
                  } else {
                    _showAddMemberDialog();
                  }
                },
                icon: const Icon(Icons.person_add_rounded, size: 16, color: Colors.white),
                label: const Text('Birey Ekle', style: TextStyle(color: Colors.white, fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FamTheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          ..._members.map((m) {
            final isParent = m.role == 'parent';
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: FamTheme.cardDecoration(),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: isParent ? Colors.purple.withOpacity(0.2) : FamTheme.emerald.withOpacity(0.2),
                    child: Text(m.avatarEmoji, style: const TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(m.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                            if (m.isPrimaryAdmin) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                                child: const Text('Yönetici 👑', style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          '${m.roleTitle} • ${m.gender == 'female' ? 'Kadın / Kız' : 'Erkek'} • ${isParent ? 'Veli Paneli' : 'Öğrenci'}',
                          style: const TextStyle(color: FamTheme.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  if (!m.isPrimaryAdmin)
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: FamTheme.surface,
                            title: const Text('Birey Silinsin mi?', style: TextStyle(color: Colors.white)),
                            content: Text('${m.name} aileden silinecektir.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                child: const Text('Sil'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await SupabaseService.deleteFamilyMember(m.id);
                          _loadAll();
                        }
                      },
                    ),
                ],
              ),
            );
          }),

          const SizedBox(height: 18),

          // 4. HAFTALIK DERS PROGRAMI & ÇANTA EDİTÖRÜ
          if (children.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: FamTheme.cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Text('📅', style: TextStyle(fontSize: 20)),
                      SizedBox(width: 8),
                      Text(
                        'Haftalık Ders & Çanta Programı',
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Öğrenci Seçici
                  Row(
                    children: [
                      const Text('Öğrenci: ', style: TextStyle(color: FamTheme.textMuted, fontSize: 12)),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        dropdownColor: FamTheme.surfaceElevated,
                        value: _selectedChildForSchedule?.id,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        items: children.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                        onChanged: (id) {
                          setState(() {
                            _selectedChildForSchedule = children.firstWhere((c) => c.id == id);
                          });
                          _loadScheduleForDay();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Gün Seçici (Pazartesi ... Pazar)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(7, (idx) {
                        final dayNum = idx + 1;
                        final isSel = _selectedDay == dayNum;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: InkWell(
                            onTap: () {
                              setState(() => _selectedDay = dayNum);
                              _loadScheduleForDay();
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSel ? FamTheme.primary : FamTheme.surfaceElevated,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(_dayNames[idx], style: TextStyle(color: isSel ? Colors.white : Colors.white70, fontSize: 11)),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Dersler Girişi (Virgülle Ayrılmış)
                  TextField(
                    controller: _lessonsController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'Dersler (Virgülle ayırın)',
                      labelStyle: TextStyle(color: FamTheme.textMuted),
                      hintText: 'Türkçe, Matematik, Fen Bilimleri, İngilizce',
                      hintStyle: TextStyle(color: Colors.white24),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Özel Çanta Kutuları
                  Row(
                    children: [
                      Expanded(
                        child: CheckboxListTile(
                          title: const Text('🏃 Beden Eğitimi (Spor Çantası)', style: TextStyle(color: Colors.white, fontSize: 11)),
                          value: _hasPe,
                          contentPadding: EdgeInsets.zero,
                          activeColor: FamTheme.primary,
                          onChanged: (v) => setState(() => _hasPe = v ?? false),
                        ),
                      ),
                      Expanded(
                        child: CheckboxListTile(
                          title: const Text('🎨 Görsel Sanatlar (Boya/Resim)', style: TextStyle(color: Colors.white, fontSize: 11)),
                          value: _hasArt,
                          contentPadding: EdgeInsets.zero,
                          activeColor: FamTheme.primary,
                          onChanged: (v) => setState(() => _hasArt = v ?? false),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saveSchedule,
                      icon: const Icon(Icons.save_rounded, size: 16, color: Colors.white),
                      label: const Text('Programı Kaydet', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(backgroundColor: FamTheme.emerald),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
