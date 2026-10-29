import 'package:flutter/material.dart';
import '../../theme/fam_theme.dart';
import '../../services/supabase_service.dart';
import '../../l10n/app_localizations.dart';
import 'fam_home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 1. Sekme: Kendi Ailemi Kur
  final TextEditingController _createFamilyNameController = TextEditingController();
  final TextEditingController _createParentNameController = TextEditingController();
  String _createRoleTitle = 'Baba';
  String _createGender = 'male';

  // 2. Sekme: Eşimin Ailesine Katıl
  final TextEditingController _joinFamilyCodeController = TextEditingController();
  final TextEditingController _joinParentNameController = TextEditingController();
  String _joinRoleTitle = 'Anne';
  String _joinGender = 'female';

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Supabase auth oturumunda email veya isim varsa varsayılan koy
    final user = SupabaseService.client.auth.currentUser;
    if (user != null) {
      final name = user.userMetadata?['full_name'] ?? user.userMetadata?['name'] ?? '';
      if (name.isNotEmpty) {
        _createParentNameController.text = name;
        _joinParentNameController.text = name;
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _createFamilyNameController.dispose();
    _createParentNameController.dispose();
    _joinFamilyCodeController.dispose();
    _joinParentNameController.dispose();
    super.dispose();
  }

  Future<void> _handleCreateFamily() async {
    final famName = _createFamilyNameController.text.trim();
    final parentName = _createParentNameController.text.trim();

    if (famName.isEmpty || parentName.isEmpty) {
      setState(() => _errorMessage = 'Lütfen Aile Adı ve Kendi Adınızı eksiksiz girin.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await SupabaseService.createFamilyAndOwner(
      familyName: famName,
      parentName: parentName,
      roleTitle: _createRoleTitle,
      gender: _createGender,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: FamTheme.emerald,
            content: Row(
              children: [
                const Icon(Icons.stars_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${famName} kuruldu! 7 Günlük Pro Denemeniz başladı.',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const FamHomeScreen()),
        );
      } else {
        setState(() => _errorMessage = res['message'] ?? 'Aile oluşturulamadı.');
      }
    }
  }

  Future<void> _handleJoinFamily() async {
    final code = _joinFamilyCodeController.text.trim();
    final parentName = _joinParentNameController.text.trim();

    if (code.isEmpty || parentName.isEmpty) {
      setState(() => _errorMessage = 'Lütfen Aile Kodu ve Kendi Adınızı eksiksiz girin.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await SupabaseService.joinFamilyAsParent(
      familyCode: code,
      parentName: parentName,
      roleTitle: _joinRoleTitle,
      gender: _joinGender,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: FamTheme.emerald,
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${res['family_name'] ?? 'Aileye'} başarıyla katıldınız!',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const FamHomeScreen()),
        );
      } else {
        setState(() => _errorMessage = res['message'] ?? 'Aileye katılma başarısız oldu.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: FamTheme.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildHeader(l10n),
                  const SizedBox(height: 24),

                  // Sekmeler
                  Container(
                    decoration: BoxDecoration(
                      color: FamTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        color: FamTheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      labelColor: Colors.white,
                      unselectedLabelColor: FamTheme.textMuted,
                      labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                      tabs: [
                        Tab(icon: const Icon(Icons.add_home_rounded, size: 18), text: l10n.createMyFamily),
                        Tab(icon: const Icon(Icons.group_add_rounded, size: 18), text: l10n.joinPartnerFamily),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (_errorMessage != null) ...[
                    _buildErrorBox(_errorMessage!),
                    const SizedBox(height: 16),
                  ],

                  SizedBox(
                    height: 440,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildCreateFamilyTab(l10n),
                        _buildJoinFamilyTab(l10n),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n) {
    return Column(
      children: [
        Container(
          width: 86,
          height: 86,
          decoration: BoxDecoration(
            color: FamTheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: FamTheme.primary.withOpacity(0.5), width: 2),
            boxShadow: [
              BoxShadow(
                color: FamTheme.primary.withOpacity(0.3),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: const Icon(
            Icons.family_restroom_rounded,
            color: FamTheme.primary,
            size: 48,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          l10n.onboardingWelcomeTitle,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.onboardingWelcomeSubtitle,
          style: const TextStyle(
            color: FamTheme.textMuted,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBox(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: FamTheme.rose.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FamTheme.rose.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: FamTheme.rose, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: FamTheme.rose, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateFamilyTab(AppLocalizations l10n) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 7 Günlük Deneme Rozeti
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [FamTheme.primary.withOpacity(0.2), FamTheme.amber.withOpacity(0.2)],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: FamTheme.amber.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                const Text('👑', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.sevenDayTrialBadge,
                    style: const TextStyle(color: FamTheme.amber, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _buildInputField(
            controller: _createFamilyNameController,
            label: l10n.familyNameLabel,
            hint: 'Örn: Özdemir Ailesi',
            icon: Icons.cottage_rounded,
          ),
          const SizedBox(height: 12),

          _buildInputField(
            controller: _createParentNameController,
            label: l10n.parentNameLabel,
            hint: 'Örn: Caner Özdemir',
            icon: Icons.person_rounded,
          ),
          const SizedBox(height: 12),

          // Rol ve Cinsiyet Seçimi
          Row(
            children: [
              Expanded(
                child: _buildDropdown(
                  label: l10n.roleLabel,
                  value: _createRoleTitle,
                  items: const ['Baba', 'Anne', 'Ebeveyn'],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _createRoleTitle = val;
                        if (val == 'Anne') _createGender = 'female';
                        if (val == 'Baba') _createGender = 'male';
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildDropdown(
                  label: l10n.genderLabel,
                  value: _createGender,
                  items: const ['male', 'female'],
                  displayMap: const {'male': 'Erkek 👨', 'female': 'Kadın 👩'},
                  onChanged: (val) {
                    if (val != null) setState(() => _createGender = val);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          ElevatedButton(
            onPressed: _isLoading ? null : _handleCreateFamily,
            style: ElevatedButton.styleFrom(
              backgroundColor: FamTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.rocket_launch_rounded, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        l10n.createAndStartButton,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinFamilyTab(AppLocalizations l10n) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: FamTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: FamTheme.textMuted, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Eşinizin veya diğer ebeveynin ayarlar sekmesindeki Aile Kodu\'nu girin.',
                    style: TextStyle(color: FamTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _buildInputField(
            controller: _joinFamilyCodeController,
            label: l10n.partnerCodeLabel,
            hint: 'Örn: FAM-9X2A veya FAMZDE-2026',
            icon: Icons.key_rounded,
            capitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 12),

          _buildInputField(
            controller: _joinParentNameController,
            label: l10n.parentNameLabel,
            hint: 'Örn: Ayşe Özdemir',
            icon: Icons.person_rounded,
          ),
          const SizedBox(height: 12),

          // Rol ve Cinsiyet Seçimi
          Row(
            children: [
              Expanded(
                child: _buildDropdown(
                  label: l10n.roleLabel,
                  value: _joinRoleTitle,
                  items: const ['Anne', 'Baba', 'Ebeveyn'],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _joinRoleTitle = val;
                        if (val == 'Anne') _joinGender = 'female';
                        if (val == 'Baba') _joinGender = 'male';
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildDropdown(
                  label: l10n.genderLabel,
                  value: _joinGender,
                  items: const ['female', 'male'],
                  displayMap: const {'female': 'Kadın 👩', 'male': 'Erkek 👨'},
                  onChanged: (val) {
                    if (val != null) setState(() => _joinGender = val);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          ElevatedButton(
            onPressed: _isLoading ? null : _handleJoinFamily,
            style: ElevatedButton.styleFrom(
              backgroundColor: FamTheme.emerald,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.link_rounded, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        l10n.joinFamilyButton,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextCapitalization capitalization = TextCapitalization.words,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: FamTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: TextField(
        controller: controller,
        textCapitalization: capitalization,
        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: FamTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w700),
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 12),
          border: InputBorder.none,
          prefixIcon: Icon(icon, color: FamTheme.primary, size: 20),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    Map<String, String>? displayMap,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: FamTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: FamTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w700),
          border: InputBorder.none,
        ),
        dropdownColor: FamTheme.surfaceElevated,
        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
        items: items
            .map((e) => DropdownMenuItem(
                  value: e,
                  child: Text(displayMap?[e] ?? e),
                ))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}
