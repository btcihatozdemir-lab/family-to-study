import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../../theme/fam_theme.dart';
import '../../services/supabase_service.dart';
import '../../services/session_manager.dart';
import '../../models/user_model.dart';
import 'fam_home_screen.dart';
import 'onboarding_screen.dart';

class FamAuthScreen extends StatefulWidget {
  const FamAuthScreen({super.key});

  @override
  State<FamAuthScreen> createState() => _FamAuthScreenState();
}

class _FamAuthScreenState extends State<FamAuthScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Aile Kodu & Ebeveyn PIN Sekmesi
  final TextEditingController _familyCodeController = TextEditingController(text: 'FAMZDE-2026');
  final TextEditingController _pinController = TextEditingController(text: '1234');
  bool _isLoading = false;
  String? _errorMessage;
  List<UserModel> _parents = [];
  UserModel? _selectedParent;

  // Yeni Aile Kurma Sekmesi
  final TextEditingController _newFamilyNameController = TextEditingController();
  final TextEditingController _parentNameController = TextEditingController();
  String _selectedRole = 'Baba';
  String _selectedGender = 'male';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _lookupFamily();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _familyCodeController.dispose();
    _pinController.dispose();
    _newFamilyNameController.dispose();
    _parentNameController.dispose();
    super.dispose();
  }

  Future<void> _checkParentSessionAndNavigate() async {
    final profile = await SupabaseService.getCurrentParentProfile();
    if (!mounted) return;

    if (profile['needs_onboarding'] == true) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
    } else if (profile['success'] == true) {
      await SessionManager.updateSession(
        newUserId: profile['user_id']?.toString() ?? '',
        newFamilyId: profile['family_id']?.toString() ?? '',
        newRole: profile['role']?.toString() ?? 'parent',
        newName: profile['name']?.toString() ?? '',
        newRoleTitle: profile['avatar_config']?['roleTitle']?.toString() ?? 'Veli',
        newGender: profile['gender']?.toString() ?? 'male',
        newIsPrimaryAdmin: profile['is_primary_admin'] == true,
      );
      SupabaseService.subscribeToRealtimeEvents();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const FamHomeScreen()),
      );
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = profile['message']?.toString() ?? 'Giriş doğrulanamadı.';
      });
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final success = await SupabaseService.signInWithGoogle();
    if (mounted) {
      if (success) {
        await _checkParentSessionAndNavigate();
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Google ile giriş başlatılamadı veya iptal edildi.';
        });
      }
    }
  }

  Future<void> _handleAppleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final success = await SupabaseService.signInWithApple();
    if (mounted) {
      if (success) {
        await _checkParentSessionAndNavigate();
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Apple ile giriş tamamlanamadı veya iptal edildi.';
        });
      }
    }
  }

  Future<void> _handleParentPinLogin() async {
    if (_selectedParent == null) {
      setState(() => _errorMessage = 'Lütfen giriş yapacak ebeveyn profilini seçin.');
      return;
    }

    final pin = _pinController.text.trim();
    if (pin.isEmpty) {
      setState(() => _errorMessage = 'Lütfen PIN veya şifrenizi girin.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final user = await SupabaseService.loginStudentWithPin(
      studentId: _selectedParent!.id,
      pin: pin,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (user != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const FamHomeScreen()),
        );
      } else {
        setState(() => _errorMessage = 'Hatalı PIN! Lütfen şifrenizi kontrol edin.');
      }
    }
  }

  Future<void> _handleCreateFamily() async {
    final familyName = _newFamilyNameController.text.trim();
    final parentName = _parentNameController.text.trim();

    if (familyName.isEmpty || parentName.isEmpty) {
      setState(() => _errorMessage = 'Lütfen aile adı ve adınızı eksiksiz doldurun.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Supabase üzerinden yeni aile ve ilk kurucu ebeveyn oluşturma
    try {
      final code = 'FAM${familyName.substring(0, 3).toUpperCase()}-${DateTime.now().year}';
      final familyRes = await SupabaseService.client.from('families').insert({
        'name': familyName,
        'family_code': code,
      }).select().single();

      final newFamId = familyRes['id'].toString();

      final userRes = await SupabaseService.client.from('users').insert({
        'family_id': newFamId,
        'name': parentName,
        'role': 'parent',
        'is_primary_admin': true,
        'gender': _selectedGender,
        'avatar_config': {
          'roleTitle': _selectedRole,
          'avatarEmoji': _selectedGender == 'female' ? '👩‍💼' : '👨‍💼',
        },
      }).select().single();

      final createdUser = UserModel.fromJson(userRes);
      await SessionManager.saveUser(
        newUserId: createdUser.id,
        newFamilyId: createdUser.familyId,
        newRole: createdUser.role,
        newName: createdUser.name,
        newRoleTitle: createdUser.roleTitle,
        newGender: createdUser.gender,
        newIsPrimaryAdmin: true,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const FamHomeScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Aile kurulumu sırasında hata oluştu: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  _buildHeader(),
                  const SizedBox(height: 24),

                  // OAuth Butonları: Apple + Google
                  _buildOAuthButtons(),
                  const SizedBox(height: 18),

                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.white.withOpacity(0.12))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'veya Ebeveyn Şifresi ile',
                          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.white.withOpacity(0.12))),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Sekmeler: Kayıtlı Aile / Yeni Aile Kur
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
                      tabs: const [
                        Tab(icon: Icon(Icons.shield_rounded, size: 18), text: 'Mevcut Aile'),
                        Tab(icon: Icon(Icons.add_home_rounded, size: 18), text: 'Yeni Aile Kur'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (_errorMessage != null) ...[
                    _buildErrorBox(_errorMessage!),
                    const SizedBox(height: 16),
                  ],

                  SizedBox(
                    height: 380,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildExistingFamilyTab(),
                        _buildCreateFamilyTab(),
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

  Widget _buildHeader() {
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
          padding: const EdgeInsets.all(12),
          child: Image.asset(
            'assets/images/family_logo.png',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.shield_rounded,
              color: FamTheme.primary,
              size: 48,
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'FamilyToStudy Fam',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Ebeveyn & Veli Komuta Merkezi',
          style: TextStyle(
            color: FamTheme.textMuted,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildOAuthButtons() {
    return Column(
      children: [
        // App Store Guideline 4.8: Sign in with Apple
        SizedBox(
          height: 50,
          width: double.infinity,
          child: SignInWithAppleButton(
            onPressed: _isLoading ? null : _handleAppleSignIn,
            text: 'Apple ile Ebeveyn Girişi Yap',
            style: SignInWithAppleButtonStyle.white,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        const SizedBox(height: 10),
        _buildGoogleButton(),
      ],
    );
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      height: 50,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleGoogleSignIn,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E293B),
          foregroundColor: Colors.white,
          side: BorderSide(color: Colors.white.withOpacity(0.12)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🌐', style: TextStyle(fontSize: 18)),
            SizedBox(width: 10),
            Text(
              'Google ile Ebeveyn Girişi Yap',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExistingFamilyTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Aile Kodu Arama
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: FamTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: FamTheme.primary.withOpacity(0.4)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  child: TextField(
                    controller: _familyCodeController,
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      hintText: 'AİLE KODU (FAMZDE-2026)',
                      hintStyle: TextStyle(color: FamTheme.textMuted, fontSize: 12),
                      border: InputBorder.none,
                      prefixIcon: Icon(Icons.cottage_rounded, color: FamTheme.primary, size: 20),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isLoading ? null : _lookupFamily,
                style: ElevatedButton.styleFrom(
                  backgroundColor: FamTheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.search_rounded, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_parents.isNotEmpty) ...[
            const Text(
              'Giriş Yapacak Ebeveyni Seçin:',
              style: TextStyle(color: FamTheme.textMuted, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _parents.map((p) {
                final isSelected = _selectedParent?.id == p.id;
                return InkWell(
                  onTap: () => setState(() => _selectedParent = p),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 135,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? FamTheme.primary.withOpacity(0.3) : FamTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? FamTheme.primary : Colors.white.withOpacity(0.1),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: FamTheme.primary.withOpacity(0.2),
                          child: Text(
                            p.avatarEmoji.isNotEmpty ? p.avatarEmoji : (p.gender == 'female' ? '👩‍💼' : '👨‍💼'),
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        Text(
                          p.roleTitle,
                          style: const TextStyle(color: Color(0xFF4CC9F0), fontSize: 10, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // PIN Girişi
            Container(
              decoration: BoxDecoration(
                color: FamTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              child: TextField(
                controller: _pinController,
                obscureText: true,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: '${_selectedParent?.name ?? "Ebeveyn"} Şifre / PIN',
                  hintStyle: const TextStyle(color: FamTheme.textMuted, fontSize: 12),
                  border: InputBorder.none,
                  prefixIcon: const Icon(Icons.lock_rounded, color: FamTheme.primary, size: 20),
                ),
                onSubmitted: (_) => _handleParentPinLogin(),
              ),
            ),
            const SizedBox(height: 16),

            ElevatedButton(
              onPressed: _isLoading ? null : _handleParentPinLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: FamTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      '${_selectedParent?.name ?? "Ebeveyn"} Olarak Giriş Yap',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                    ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: FamTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: const Text(
                'Lütfen yukarıdan aile kodunuzu sorgulayın veya Google ile giriş yapın.',
                textAlign: TextAlign.center,
                style: TextStyle(color: FamTheme.textMuted, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCreateFamilyTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              color: FamTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            child: TextField(
              controller: _newFamilyNameController,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(
                hintText: 'Aile Adı (Örn: Yılmaz Ailesi)',
                hintStyle: TextStyle(color: FamTheme.textMuted, fontSize: 12),
                border: InputBorder.none,
                prefixIcon: Icon(Icons.family_restroom_rounded, color: FamTheme.primary, size: 20),
              ),
            ),
          ),
          const SizedBox(height: 12),

          Container(
            decoration: BoxDecoration(
              color: FamTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            child: TextField(
              controller: _parentNameController,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(
                hintText: 'Adınız Soyadınız (Örn: Mehmet Yılmaz)',
                hintStyle: TextStyle(color: FamTheme.textMuted, fontSize: 12),
                border: InputBorder.none,
                prefixIcon: Icon(Icons.person_rounded, color: FamTheme.primary, size: 20),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Akrabalık Rolü ve Cinsiyet
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: FamTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedRole,
                      dropdownColor: FamTheme.surface,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      items: ['Baba', 'Anne', 'Hala', 'Teyze', 'Dayı', 'Amca', 'Veli']
                          .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedRole = val;
                            if (val == 'Anne' || val == 'Hala' || val == 'Teyze') {
                              _selectedGender = 'female';
                            } else {
                              _selectedGender = 'male';
                            }
                          });
                        }
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: FamTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedGender,
                      dropdownColor: FamTheme.surface,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      items: const [
                        DropdownMenuItem(value: 'male', child: Text('👨 Erkek')),
                        DropdownMenuItem(value: 'female', child: Text('👩 Kadın')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedGender = val);
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          ElevatedButton(
            onPressed: _isLoading ? null : _handleCreateFamily,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text(
                    'Yeni Aile Hesabını Oluştur 🚀',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBox(String msg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: FamTheme.rose.withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FamTheme.rose.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: FamTheme.rose, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(msg, style: const TextStyle(color: FamTheme.rose, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
