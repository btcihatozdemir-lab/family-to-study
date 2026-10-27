import 'package:flutter/material.dart';
import '../../../models/user_model.dart';
import '../../../services/supabase_service.dart';
import '../../../theme/fam_theme.dart';

class LiveDashboardTab extends StatefulWidget {
  final String familyId;
  final VoidCallback onRefreshAll;

  const LiveDashboardTab({
    super.key,
    required this.familyId,
    required this.onRefreshAll,
  });

  @override
  State<LiveDashboardTab> createState() => _LiveDashboardTabState();
}

class _LiveDashboardTabState extends State<LiveDashboardTab> {
  List<UserModel> _children = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChildren();
  }

  Future<void> _loadChildren() async {
    setState(() => _isLoading = true);
    final kids = await SupabaseService.fetchFamilyChildren(widget.familyId);
    if (mounted) {
      setState(() {
        _children = kids;
        _isLoading = false;
      });
    }
  }

  void _showSetStateModal(UserModel child) {
    showModalBottomSheet(
      context: context,
      backgroundColor: FamTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '${child.name} İçin Durum Yönetimi',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Odak & Ders Modu Butonları
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: FamTheme.primary.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Text('🎯', style: TextStyle(fontSize: 20)),
                ),
                title: const Text('Ders & Odak Moduna Al (Kilit)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text('Cihaz ekranını ders modunda kilitler', style: TextStyle(color: FamTheme.textMuted, fontSize: 12)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: FamTheme.textMuted),
                onTap: () {
                  Navigator.pop(ctx);
                  _showDurationPicker(child, 'STUDY_TIME');
                },
              ),
              const Divider(color: Colors.white10),

              // Rutin Modu
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: FamTheme.cyan.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Text('📋', style: TextStyle(fontSize: 20)),
                ),
                title: const Text('Rutin Tamamlama Modu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text('Sabah/Akşam hazırlık rutini için kilit', style: TextStyle(color: FamTheme.textMuted, fontSize: 12)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: FamTheme.textMuted),
                onTap: () {
                  Navigator.pop(ctx);
                  _showDurationPicker(child, 'ROUTINE_TIME');
                },
              ),
              const Divider(color: Colors.white10),

              // Serbest Zaman Modu
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: FamTheme.emerald.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Text('🟢', style: TextStyle(fontSize: 20)),
                ),
                title: const Text('Serbest Zamana Geçir', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text('Tüm kilitleri kaldırır, serbest erişim açar', style: TextStyle(color: FamTheme.textMuted, fontSize: 12)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await SupabaseService.setChildState(
                    studentId: child.id,
                    newState: 'FREE_TIME',
                  );
                  _loadChildren();
                  widget.onRefreshAll();
                },
              ),
              const Divider(color: Colors.white10),

              // Uyanma Alarmı
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: FamTheme.gold.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Text('⏰', style: TextStyle(fontSize: 20)),
                ),
                title: const Text('Sabah Uyanma Alarmı Çaldır', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text('Öğrencinin ekranında sesli alarm modunu tetikler', style: TextStyle(color: FamTheme.textMuted, fontSize: 12)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await SupabaseService.setChildState(
                    studentId: child.id,
                    newState: 'WAKE_UP_ALARM',
                  );
                  _loadChildren();
                  widget.onRefreshAll();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDurationPicker(UserModel child, String state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: FamTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${state == 'STUDY_TIME' ? 'Ders' : 'Rutin'} Süresi Seçin',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Süre bittiğinde durum otomatik olarak serbest zamana geçer.',
                style: TextStyle(color: FamTheme.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [25, 40, 60, 90].map((mins) {
                  return ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await SupabaseService.setChildState(
                        studentId: child.id,
                        newState: state,
                        durationMinutes: mins,
                      );
                      _loadChildren();
                      widget.onRefreshAll();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FamTheme.surfaceElevated,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      side: const BorderSide(color: FamTheme.primary),
                    ),
                    child: Text('$mins Dk', style: const TextStyle(fontWeight: FontWeight.bold)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadChildren();
        widget.onRefreshAll();
      },
      color: FamTheme.primaryLight,
      backgroundColor: FamTheme.surfaceElevated,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // Banner: Family Overview
          _buildFamilyHeaderBanner(),
          const SizedBox(height: 20),

          // Section Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Text('👨‍👩‍👧‍👦', style: TextStyle(fontSize: 20)),
                  SizedBox(width: 8),
                  Text(
                    'Çocukların Canlı Durumu',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_children.length} Öğrenci',
                  style: const TextStyle(color: FamTheme.textMuted, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Children Cards
          if (_isLoading && _children.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(color: FamTheme.primaryLight),
              ),
            )
          else if (_children.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              decoration: FamTheme.cardDecoration(),
              child: const Column(
                children: [
                  Text('🦁', style: TextStyle(fontSize: 38)),
                  SizedBox(height: 10),
                  Text(
                    'Kayıtlı Çocuk Bulunamadı',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Ailenize yeni bir öğrenci eklemek için ebeveyn portalını veya eşleştirme kodunu kullanabilirsiniz.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: FamTheme.textMuted, fontSize: 13),
                  ),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _children.length,
              itemBuilder: (context, index) {
                final child = _children[index];
                return _buildChildCard(child);
              },
            ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildFamilyHeaderBanner() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            FamTheme.primary.withOpacity(0.35),
            FamTheme.secondary.withOpacity(0.25),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: FamTheme.primary.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text('🛡️', style: TextStyle(fontSize: 26)),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Aile Akademisi Canlı Telemetri',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Öğrencilerinizin canlı durumlarını anlık yönetin, ekran kilidi uygulayın ve takdir bonusu dağıtın.',
                      style: TextStyle(
                        color: FamTheme.textMuted,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final res = await SupabaseService.triggerDailyZeroViolationBonus(widget.familyId);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(res ? '🛡️ İhlalsiz öğrencilere kalkan ödülü verildi!' : 'İşlem tamamlandı')),
                      );
                      _loadChildren();
                      widget.onRefreshAll();
                    }
                  },
                  icon: const Text('🛡️', style: TextStyle(fontSize: 13)),
                  label: const Text('Sıfır İhlal Bonusu (+15)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: FamTheme.emerald,
                    side: BorderSide(color: FamTheme.emerald.withOpacity(0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final res = await SupabaseService.triggerSundayPiggyBonus(widget.familyId);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(res ? '🏺 Haftalık %10 Kumbara temettüsü yatırıldı!' : 'İşlem tamamlandı')),
                      );
                      _loadChildren();
                      widget.onRefreshAll();
                    }
                  },
                  icon: const Text('🏺', style: TextStyle(fontSize: 13)),
                  label: const Text('Kumbara %10 Temettü', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: FamTheme.gold,
                    side: BorderSide(color: FamTheme.gold.withOpacity(0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChildCard(UserModel child) {
    final bool isStudy = child.currentState == 'STUDY_TIME';
    final bool isRoutine = child.currentState == 'ROUTINE_TIME';
    final bool isAlarm = child.currentState == 'WAKE_UP_ALARM';

    Color stateColor = FamTheme.emerald;
    String stateText = 'Serbest Zaman';
    String stateEmoji = '🟢';

    if (isStudy) {
      stateColor = FamTheme.primaryLight;
      stateText = 'Ders Modu (Kilitli)';
      stateEmoji = '🎯';
    } else if (isRoutine) {
      stateColor = FamTheme.cyan;
      stateText = 'Rutin Hazırlık';
      stateEmoji = '📋';
    } else if (isAlarm) {
      stateColor = FamTheme.gold;
      stateText = 'Uyanma Alarmı';
      stateEmoji = '⏰';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: FamTheme.cardDecoration(
        borderColor: isStudy ? FamTheme.primaryLight.withOpacity(0.5) : null,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: FamTheme.surfaceElevated,
                    shape: BoxShape.circle,
                    border: Border.all(color: stateColor, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      child.avatarEmoji,
                      style: const TextStyle(fontSize: 26),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Name and Status
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              child.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: stateColor.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(stateEmoji, style: const TextStyle(fontSize: 10)),
                                const SizedBox(width: 4),
                                Text(
                                  stateText,
                                  style: TextStyle(
                                    color: stateColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            '${child.pointsBalance} 🪙 Puan',
                            style: const TextStyle(
                              color: FamTheme.gold,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${child.piggyBankBalance} 🏺 Kasada',
                            style: const TextStyle(
                              color: FamTheme.cyan,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Shields & Modifier
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: List.generate(3, (i) {
                        final bool intact = i < child.dailyShields;
                        return Padding(
                          padding: const EdgeInsets.only(left: 2),
                          child: Text(
                            intact ? '🛡️' : '💔',
                            style: const TextStyle(fontSize: 14),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        InkWell(
                          onTap: () async {
                            await SupabaseService.updateChildShields(child.id, -1);
                            _loadChildren();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('➖', style: TextStyle(fontSize: 10)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () async {
                            await SupabaseService.updateChildShields(child.id, 1);
                            _loadChildren();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('➕', style: TextStyle(fontSize: 10)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          Divider(color: Colors.white.withOpacity(0.06), height: 1),

          // Action Toolbar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showSetStateModal(child),
                    icon: const Text('⚡', style: TextStyle(fontSize: 14)),
                    label: const Text('Durumu Yönet'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FamTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: () async {
                    // Quick Free / Unlock
                    await SupabaseService.setChildState(
                      studentId: child.id,
                      newState: 'FREE_TIME',
                    );
                    _loadChildren();
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.white.withOpacity(0.15)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Kilidi Aç', style: TextStyle(color: Colors.white70, fontSize: 13)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
