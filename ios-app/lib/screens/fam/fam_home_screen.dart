import 'package:flutter/material.dart';
import '../../services/session_manager.dart';
import '../../theme/fam_theme.dart';
import 'tabs/live_dashboard_tab.dart';
import 'tabs/approvals_tab.dart';
import 'tabs/task_hub_tab.dart';
import 'tabs/justice_walkie_tab.dart';
import 'tabs/family_settings_tab.dart';
import 'fam_auth_screen.dart';

class FamHomeScreen extends StatefulWidget {
  const FamHomeScreen({super.key});

  @override
  State<FamHomeScreen> createState() => _FamHomeScreenState();
}

class _FamHomeScreenState extends State<FamHomeScreen> {
  int _currentTabIndex = 0;

  void _handleRefreshAll() {
    setState(() {});
  }

  void _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: FamTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Çıkış Yapılsın mı?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Ebeveyn oturumunu kapatmak istediğinize emin misiniz?',
          style: TextStyle(color: FamTheme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç', style: TextStyle(color: FamTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: FamTheme.rose),
            child: const Text('Çıkış Yap', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await SessionManager.clearSession();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const FamAuthScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final familyId = SessionManager.familyId.isNotEmpty ? SessionManager.familyId : 'fam-ozdemir';

    return Scaffold(
      backgroundColor: FamTheme.background,
      body: Column(
        children: [
          // Top Navigation Bar
          _buildTopBar(),

          // Indexed Tabs
          Expanded(
            child: IndexedStack(
              index: _currentTabIndex,
              children: [
                LiveDashboardTab(familyId: familyId, onRefreshAll: _handleRefreshAll),
                ApprovalsTab(familyId: familyId, onRefreshAll: _handleRefreshAll),
                TaskHubTab(familyId: familyId, onRefreshAll: _handleRefreshAll),
                JusticeWalkieTab(familyId: familyId, onRefreshAll: _handleRefreshAll),
                FamilySettingsTab(familyId: familyId, onRefreshAll: _handleRefreshAll),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildTopBar() {
    final familyName = SessionManager.familyName.isNotEmpty ? SessionManager.familyName : 'Aile Akademisi';

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 12,
      ),
      decoration: BoxDecoration(
        color: FamTheme.surface,
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      child: Row(
        children: [
          // Family Brand Logo
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: FamTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: FamTheme.primary.withOpacity(0.3)),
            ),
            padding: const EdgeInsets.all(4),
            child: Image.asset(
              'assets/images/family_logo.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(Icons.family_restroom, color: FamTheme.primaryLight),
            ),
          ),
          const SizedBox(width: 12),

          // Title & Subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        familyName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (SessionManager.isPrimaryAdmin) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: FamTheme.gold.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: FamTheme.gold.withOpacity(0.5)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('👑 Kurucu', style: TextStyle(color: FamTheme.goldLight, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                Row(
                  children: [
                    Text(
                      '🛡️ ${SessionManager.userName} (${SessionManager.roleTitle})',
                      style: const TextStyle(color: FamTheme.textMuted, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Logout Button
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: FamTheme.textMuted, size: 20),
            onPressed: _handleLogout,
            tooltip: 'Çıkış Yap',
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: FamTheme.surface,
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, '🏠', 'Çocuklar'),
              _buildNavItem(1, '🔔', 'Onay Masası'),
              _buildNavItem(2, '⚡', 'Görev & Pazar'),
              _buildNavItem(3, '⚖️', 'Divan & Telsiz'),
              _buildNavItem(4, '⚙️', 'Aile Yönetimi'),
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
          color: isSelected ? FamTheme.primary.withOpacity(0.2) : Colors.transparent,
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
                color: isSelected ? Colors.white : FamTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
