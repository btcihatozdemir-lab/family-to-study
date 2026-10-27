import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/supabase_service.dart';
import '../../services/session_manager.dart';
import '../../theme/kids_theme.dart';
import 'tabs/missions_tab.dart';
import 'tabs/schedule_bag_tab.dart';
import 'tabs/treasure_vault_tab.dart';
import 'tabs/walkie_talkie_tab.dart';
import 'overlays/focus_lock_overlay.dart';
import 'overlays/morning_alarm_overlay.dart';
import 'kids_auth_screen.dart';

class KidsHomeScreen extends StatefulWidget {
  final UserModel initialStudent;

  const KidsHomeScreen({super.key, required this.initialStudent});

  @override
  State<KidsHomeScreen> createState() => _KidsHomeScreenState();
}

class _KidsHomeScreenState extends State<KidsHomeScreen> {
  late UserModel _student;
  int _currentTabIndex = 0;
  StreamSubscription<UserModel>? _studentSub;

  @override
  void initState() {
    super.initState();
    _student = widget.initialStudent;
    _refreshStudent();

    // Listen to Supabase Realtime live student updates (points, shields, states)
    _studentSub = SupabaseService.studentUpdateController.stream.listen((updated) {
      if (mounted && updated.id == _student.id) {
        setState(() {
          _student = updated;
        });
      }
    });
  }

  @override
  void dispose() {
    _studentSub?.cancel();
    super.dispose();
  }

  Future<void> _refreshStudent() async {
    final fresh = await SupabaseService.fetchStudentProfile(_student.id);
    if (fresh != null && mounted) {
      setState(() {
        _student = fresh;
      });
    }
  }

  void _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KidsTheme.cardSlate,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Çıkış Yapılsın mı?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Oturumu kapatmak istediğinize emin misiniz? Tekrar PIN veya sihirli kodla giriş yapabilirsiniz.',
          style: TextStyle(color: KidsTheme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç', style: TextStyle(color: KidsTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: KidsTheme.roseLight),
            child: const Text('Çıkış Yap', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await SessionManager.clearSession();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const KidsAuthScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KidsTheme.bgMidnight,
      body: Stack(
        children: [
          // Main Scaffold content
          Column(
            children: [
              // Top Bar
              _buildTopBar(),

              // Selected Tab View
              Expanded(
                child: IndexedStack(
                  index: _currentTabIndex,
                  children: [
                    MissionsTab(student: _student, onRefreshUser: _refreshStudent),
                    ScheduleBagTab(student: _student),
                    TreasureVaultTab(student: _student, onRefreshUser: _refreshStudent),
                    WalkieTalkieTab(student: _student, onRefreshUser: _refreshStudent),
                  ],
                ),
              ),
            ],
          ),

          // Focus Lock Overlay (When student is in study or routine mode)
          if (_student.isStudying)
            FocusLockOverlay(
              student: _student,
              onDismiss: _refreshStudent,
            ),

          // Morning Wake-Up Alarm Overlay (When student wakes up)
          if (_student.currentState == 'WAKE_UP_ALARM')
            MorningAlarmOverlay(
              student: _student,
              onDismissed: _refreshStudent,
            ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 14,
      ),
      decoration: BoxDecoration(
        color: KidsTheme.surfaceElevated,
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar with Level Tag
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [KidsTheme.indigoPrimary, KidsTheme.purpleAccent],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        _student.avatarEmoji,
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: KidsTheme.goldAmber,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: KidsTheme.bgMidnight, width: 1.5),
                      ),
                      child: Text(
                        'Lv.${_student.level}',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),

              // Name and XP Progress
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _student.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        _buildStateChip(),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: _student.levelProgress,
                              minHeight: 6,
                              backgroundColor: Colors.white12,
                              valueColor: const AlwaysStoppedAnimation<Color>(KidsTheme.cyanSoft),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(_student.levelProgress * 100).toInt()}%',
                          style: const TextStyle(fontSize: 10, color: KidsTheme.textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Points & Shields Pill
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Gold Points
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: KidsTheme.goldAmber.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: KidsTheme.goldAmber.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🪙', style: TextStyle(fontSize: 13)),
                        const SizedBox(width: 4),
                        Text(
                          '${_student.pointsBalance}',
                          style: const TextStyle(
                            color: KidsTheme.goldAmber,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Daily Shields
                  _buildShieldsRow(),
                ],
              ),

              const SizedBox(width: 4),
              // Menu / Logout button
              IconButton(
                icon: const Icon(Icons.more_vert, color: KidsTheme.textMuted, size: 20),
                onPressed: _handleLogout,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStateChip() {
    Color bg;
    Color fg;
    String label;

    switch (_student.currentState) {
      case 'STUDY_TIME':
        bg = KidsTheme.indigoPrimary.withOpacity(0.2);
        fg = KidsTheme.indigoPrimary;
        label = 'Ders';
        break;
      case 'ROUTINE_TIME':
        bg = KidsTheme.cyanSoft.withOpacity(0.2);
        fg = KidsTheme.cyanSoft;
        label = 'Rutin';
        break;
      case 'WAKE_UP_ALARM':
        bg = KidsTheme.goldAmber.withOpacity(0.2);
        fg = KidsTheme.goldAmber;
        label = 'Alarm';
        break;
      case 'FREE_TIME':
      default:
        bg = KidsTheme.emeraldGreen.withOpacity(0.2);
        fg = KidsTheme.emeraldGreen;
        label = 'Serbest';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildShieldsRow() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        final bool isIntact = index < _student.dailyShields;
        return Padding(
          padding: const EdgeInsets.only(left: 2),
          child: Text(
            isIntact ? '🛡️' : '💔',
            style: TextStyle(
              fontSize: 12,
              color: isIntact ? Colors.white : Colors.white24,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: KidsTheme.surfaceElevated,
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, '📋', 'Görevler'),
              _buildNavItem(1, '🎒', 'Ders & Çanta'),
              _buildNavItem(2, '🏺', 'Kasa & Pazar'),
              _buildNavItem(3, '📻', 'Telsiz'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, String emoji, String label) {
    final bool isSelected = _currentTabIndex == index;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() => _currentTabIndex = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? KidsTheme.indigoPrimary.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              emoji,
              style: TextStyle(
                fontSize: isSelected ? 22 : 19,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : KidsTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
