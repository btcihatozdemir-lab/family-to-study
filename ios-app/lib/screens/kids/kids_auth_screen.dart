import 'package:flutter/material.dart';
import '../../theme/kids_theme.dart';
import '../../services/supabase_service.dart';
import '../../models/user_model.dart';
import 'kids_home_screen.dart';
import '../fam/fam_home_screen.dart';

class KidsAuthScreen extends StatefulWidget {
  const KidsAuthScreen({super.key});

  @override
  State<KidsAuthScreen> createState() => _KidsAuthScreenState();
}

class _KidsAuthScreenState extends State<KidsAuthScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Aile Profili Sekmesi Durumları
  final TextEditingController _familyCodeController = TextEditingController(text: 'FAMZDE-2026');
  bool _isFamilyLoading = false;
  String? _familyError;
  Map<String, dynamic>? _foundFamily;
  List<UserModel> _familyMembers = [];
  UserModel? _selectedMember;
  final TextEditingController _memberPinController = TextEditingController();

  // Doğrudan Kullanıcı Adı / Kod Sekmesi Durumları
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isDirectLoading = false;
  String? _directError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Açılışta varsayılan aile kodunu otomatik sorgula
    _lookupFamily();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _familyCodeController.dispose();
    _memberPinController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// 1. Aile Kodu Sorgulama (Örn: FAMZDE-2026)
  Future<void> _lookupFamily() async {
    final code = _familyCodeController.text.trim();
    if (code.isEmpty) {
      setState(() => _familyError = 'Lütfen aile kodunuzu girin.');
      return;
    }

    setState(() {
      _isFamilyLoading = true;
      _familyError = null;
      _selectedMember = null;
    });

    final fam = await SupabaseService.fetchFamilyByCode(code);
    if (fam != null) {
      final members = await SupabaseService.fetchFamilyMembers(fam['id'].toString());
      if (mounted) {
        setState(() {
          _foundFamily = fam;
          _familyMembers = members;
          _isFamilyLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _familyError = 'Bu koda ait aile bulunamadı. Lütfen ebeveyn panelinizdeki aile kodunu kontrol edin.';
          _foundFamily = null;
          _familyMembers = [];
          _isFamilyLoading = false;
        });
      }
    }
  }

  /// 2. Birey Seçildiğinde PIN Doğrulama
  Future<void> _handleMemberPinLogin() async {
    if (_selectedMember == null) return;
    final pin = _memberPinController.text.trim();
    if (pin.isEmpty) {
      setState(() => _familyError = 'Lütfen PIN / şifrenizi girin.');
      return;
    }

    setState(() {
      _isFamilyLoading = true;
      _familyError = null;
    });

    final user = await SupabaseService.loginStudentWithPin(
      studentId: _selectedMember!.id,
      pin: pin,
    );

    setState(() => _isFamilyLoading = false);

    if (user != null && mounted) {
      _navigateHome(user);
    } else {
      setState(() => _familyError = 'Hatalı PIN! Lütfen şifrenizi kontrol edin.');
    }
  }

  /// 3. Doğrudan Kullanıcı Adı & Şifre veya Eşleştirme Kodu ile Giriş
  Future<void> _handleDirectLogin() async {
    final userOrCode = _usernameController.text.trim();
    final pass = _passwordController.text.trim();

    if (userOrCode.isEmpty) {
      setState(() => _directError = 'Kullanıcı adı veya 6 haneli kod girin.');
      return;
    }

    setState(() {
      _isDirectLoading = true;
      _directError = null;
    });

    UserModel? user;

    // Şifre girilmişse önce Kullanıcı Adı + Şifre dene
    if (pass.isNotEmpty) {
      user = await SupabaseService.loginWithUsernameAndPassword(
        username: userOrCode,
        password: pass,
      );
    }

    // Bulunamazsa 6 haneli eşleştirme kodu olarak dene (Örn: 889-891)
    user ??= await SupabaseService.loginWithPairingCode(userOrCode);

    // Bulunamazsa sihirli link jetonu olarak dene
    user ??= await SupabaseService.loginWithMagicToken(userOrCode);

    setState(() => _isDirectLoading = false);

    if (user != null && mounted) {
      _navigateHome(user);
    } else {
      setState(() {
        _directError = 'Giriş başarısız. Kullanıcı adı, şifre veya eşleştirme kodunu kontrol edin.';
      });
    }
  }

  /// Hızlı Ebeveyn Girişi (Tek Tıkla Giriş)
  Future<void> _handleQuickParentLogin(UserModel parent, [String pin = '1234']) async {
    setState(() {
      _isFamilyLoading = true;
      _familyError = null;
    });

    final user = await SupabaseService.loginStudentWithPin(
      studentId: parent.id,
      pin: pin,
    );

    setState(() => _isFamilyLoading = false);

    if (user != null && mounted) {
      _navigateHome(user);
    } else {
      setState(() => _familyError = 'Ebeveyn girişi başarısız. Lütfen şifrenizi kontrol edin.');
    }
  }

  void _navigateHome(UserModel user) {
    if (user.role == 'parent') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const FamHomeScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => KidsHomeScreen(initialStudent: user)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KidsTheme.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo ve Başlık
                  _buildBrandHeader(),
                  const SizedBox(height: 16),

                  // Ebeveyn Hızlı Geçiş Bannerı (Göz Alıcı Vurgu)
                  _buildParentQuickSwitchBanner(),
                  const SizedBox(height: 16),

                  // Sekme Başlıkları (3 Sekme: Öğrenci, Ebeveyn, Kod)
                  Container(
                    decoration: BoxDecoration(
                      color: KidsTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        color: KidsTheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      labelColor: Colors.white,
                      unselectedLabelColor: KidsTheme.textMuted,
                      labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                      tabs: const [
                        Tab(
                          icon: Icon(Icons.school_rounded, size: 18),
                          text: '🧒 Öğrenci',
                        ),
                        Tab(
                          icon: Icon(Icons.shield_rounded, size: 18),
                          text: '🛡️ Ebeveyn',
                        ),
                        Tab(
                          icon: Icon(Icons.key_rounded, size: 18),
                          text: '🔑 Kod / PIN',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Sekme İçerikleri
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    child: SizedBox(
                      height: 460,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildFamilyProfilesTab(),
                          _buildParentAuthTab(),
                          _buildDirectLoginTab(),
                        ],
                      ),
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

  Widget _buildParentQuickSwitchBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF4361EE).withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4361EE).withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF4361EE).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Text('🛡️', style: TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ebeveyn / Veli Misiniz?',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Fam Yönetim Paneline bağlanın',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              _tabController.animateTo(1);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4361EE),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Ebeveyn Girişi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandHeader() {
    return Column(
      children: [
        Container(
          width: 86,
          height: 86,
          decoration: BoxDecoration(
            color: KidsTheme.surface,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: KidsTheme.primary.withOpacity(0.5), width: 2),
            boxShadow: [
              BoxShadow(
                color: KidsTheme.primary.withOpacity(0.35),
                blurRadius: 28,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(10),
          child: Image.asset(
            'assets/images/kids_logo.png',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.stars_rounded,
              color: KidsTheme.gold,
              size: 48,
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'FamilyToStudy',
          style: TextStyle(
            color: KidsTheme.textWhite,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Aile İçi Oyunlaştırma & Güvenli Giriş',
          style: TextStyle(
            color: KidsTheme.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /// 1. Sekme: Aile Kodu -> Çocuk Profilleri -> PIN
  Widget _buildFamilyProfilesTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Aile Kodu Giriş Kutusu
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: KidsTheme.cardDecoration(
                    borderColor: KidsTheme.primary.withOpacity(0.3),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  child: TextField(
                    controller: _familyCodeController,
                    style: const TextStyle(
                      color: KidsTheme.goldLight,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      hintText: 'AİLE KODU (Örn: FAMZDE-2026)',
                      hintStyle: TextStyle(
                        color: KidsTheme.textMuted,
                        fontSize: 12,
                        letterSpacing: 1,
                      ),
                      border: InputBorder.none,
                      prefixIcon: Icon(Icons.cottage_rounded, color: KidsTheme.gold, size: 20),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isFamilyLoading ? null : _lookupFamily,
                style: ElevatedButton.styleFrom(
                  backgroundColor: KidsTheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isFamilyLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.search_rounded, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Hata Mesajı
          if (_familyError != null) ...[
            _buildErrorBox(_familyError!),
            const SizedBox(height: 12),
          ],

          // Aile Bulunduysa Bireyleri Listele
          if (_foundFamily != null) ...[
            Text(
              '🏡 ${_foundFamily!['name']} — Kim Giriş Yapıyor?',
              style: const TextStyle(
                color: KidsTheme.cyanSoft,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 10),

            // Üye Kartları (Yatay veya Grid)
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _familyMembers.map((member) {
                final isSelected = _selectedMember?.id == member.id;
                final isChild = member.role == 'child';

                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedMember = member;
                      _memberPinController.clear();
                      _familyError = null;
                    });
                  },
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    width: 135,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? KidsTheme.primary.withOpacity(0.25)
                          : KidsTheme.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isSelected ? KidsTheme.primaryLight : Colors.white.withOpacity(0.08),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: isChild ? KidsTheme.emerald.withOpacity(0.2) : Colors.purple.withOpacity(0.2),
                          child: Text(
                            member.avatarEmoji.isNotEmpty ? member.avatarEmoji : (isChild ? (member.gender == 'female' ? '👧' : '👦') : (member.gender == 'female' ? '👩' : '👨')),
                            style: const TextStyle(fontSize: 22),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          member.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isSelected ? Colors.white : KidsTheme.textWhite,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          member.isPrimaryAdmin
                              ? '${member.roleTitle} (Yönetici) 👑'
                              : member.roleTitle,
                          style: TextStyle(
                            color: isChild ? KidsTheme.emerald : KidsTheme.primaryLight,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Seçilen Birey İçin PIN Girişi
            if (_selectedMember != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: KidsTheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: KidsTheme.gold.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '🔑 ${_selectedMember!.name} için PIN / Şifre:',
                      style: const TextStyle(
                        color: KidsTheme.goldLight,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _memberPinController,
                      obscureText: true,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        letterSpacing: 6,
                        fontWeight: FontWeight.w900,
                      ),
                      decoration: InputDecoration(
                        hintText: '••••',
                        hintStyle: const TextStyle(color: KidsTheme.textMuted, letterSpacing: 4),
                        filled: true,
                        fillColor: Colors.black.withOpacity(0.25),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onSubmitted: (_) => _handleMemberPinLogin(),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _isFamilyLoading ? null : _handleMemberPinLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: KidsTheme.emerald,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isFamilyLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                            )
                          : Text(
                              '${_selectedMember!.name} Olarak Başla 🚀',
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  /// 2. Sekme: Doğrudan Kullanıcı Adı + Şifre veya Eşleştirme Kodu
  Widget _buildDirectLoginTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Kullanıcı Adı veya Kod
          Container(
            decoration: KidsTheme.cardDecoration(
              borderColor: KidsTheme.primary.withOpacity(0.3),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            child: TextField(
              controller: _usernameController,
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(
                hintText: 'Kullanıcı Adı veya 6 Haneli Kod (889-891)',
                hintStyle: TextStyle(color: KidsTheme.textMuted, fontSize: 12),
                border: InputBorder.none,
                prefixIcon: Icon(Icons.person_rounded, color: KidsTheme.primaryLight, size: 20),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Şifre / PIN
          Container(
            decoration: KidsTheme.cardDecoration(
              borderColor: KidsTheme.primary.withOpacity(0.3),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            child: TextField(
              controller: _passwordController,
              obscureText: true,
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(
                hintText: 'Şifre / PIN (Eşleştirme kodunda boş bırakın)',
                hintStyle: TextStyle(color: KidsTheme.textMuted, fontSize: 12),
                border: InputBorder.none,
                prefixIcon: Icon(Icons.lock_rounded, color: KidsTheme.gold, size: 20),
              ),
              onSubmitted: (_) => _handleDirectLogin(),
            ),
          ),
          const SizedBox(height: 14),

          if (_directError != null) ...[
            _buildErrorBox(_directError!),
            const SizedBox(height: 14),
          ],

          ElevatedButton(
            onPressed: _isDirectLoading ? null : _handleDirectLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: KidsTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _isDirectLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Güvenli Giriş Yap', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBox(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: KidsTheme.rose.withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KidsTheme.rose.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: KidsTheme.rose, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: KidsTheme.rose, fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  /// Ebeveyn / Veli Yönetim Giriş Sekmesi
  Widget _buildParentAuthTab() {
    final parents = _familyMembers.where((m) => m.role == 'parent').toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF4361EE).withOpacity(0.4)),
            ),
            child: const Row(
              children: [
                Text('🛡️', style: TextStyle(fontSize: 24)),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ebeveyn Komuta Paneli (Fam)',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Giriş yapmak istediğiniz ebeveyn profilini seçin.',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          if (parents.isEmpty && _isFamilyLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(color: Color(0xFF4361EE)),
              ),
            )
          else if (parents.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: KidsTheme.cardDecoration(),
              child: const Text(
                'Bu ailede kayıtlı ebeveyn bulunamadı.',
                style: TextStyle(color: KidsTheme.textMuted, fontSize: 12),
              ),
            )
          else ...[
            // Ebeveyn Profil Kartları
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: parents.map((parent) {
                final isSelected = _selectedMember?.id == parent.id;

                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedMember = parent;
                      _memberPinController.text = '1234';
                      _familyError = null;
                    });
                  },
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    width: 140,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF4361EE).withOpacity(0.25) : KidsTheme.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF4361EE) : Colors.white.withOpacity(0.1),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: const Color(0xFF4361EE).withOpacity(0.2),
                          child: Text(
                            parent.avatarEmoji.isNotEmpty
                                ? parent.avatarEmoji
                                : (parent.gender == 'female' ? '👩‍💼' : '👨‍💼'),
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          parent.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          parent.isPrimaryAdmin ? '${parent.roleTitle} 👑' : parent.roleTitle,
                          style: const TextStyle(
                            color: Color(0xFF4CC9F0),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // PIN Kutusu
            Container(
              decoration: KidsTheme.cardDecoration(borderColor: const Color(0xFF4361EE).withOpacity(0.4)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              child: TextField(
                controller: _memberPinController,
                obscureText: true,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: '${_selectedMember?.name ?? "Ebeveyn"} PIN / Şifresi',
                  hintStyle: const TextStyle(color: KidsTheme.textMuted, fontSize: 12),
                  border: InputBorder.none,
                  prefixIcon: const Icon(Icons.lock_rounded, color: Color(0xFF4CC9F0), size: 20),
                ),
                onSubmitted: (_) {
                  if (_selectedMember != null) {
                    _handleMemberPinLogin();
                  } else if (parents.isNotEmpty) {
                    _handleQuickParentLogin(parents.first, _memberPinController.text.trim());
                  }
                },
              ),
            ),
            const SizedBox(height: 12),

            if (_familyError != null) ...[
              _buildErrorBox(_familyError!),
              const SizedBox(height: 12),
            ],

            ElevatedButton.icon(
              onPressed: () {
                if (_selectedMember != null) {
                  _handleMemberPinLogin();
                } else if (parents.isNotEmpty) {
                  _handleQuickParentLogin(parents.first, _memberPinController.text.trim());
                }
              },
              icon: const Text('🛡️', style: TextStyle(fontSize: 18)),
              label: Text(
                _selectedMember != null
                    ? '${_selectedMember!.name} Olarak Paneli Aç'
                    : 'Ebeveyn Paneline Giriş Yap',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4361EE),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 10),

            // Hızlı 1-Tık Kurucu Girişi Butonu
            OutlinedButton.icon(
              onPressed: () {
                final primary = parents.firstWhere((p) => p.isPrimaryAdmin, orElse: () => parents.first);
                _handleQuickParentLogin(primary, '1234');
              },
              icon: const Text('👑', style: TextStyle(fontSize: 16)),
              label: const Text(
                'Hızlı Giriş: Cihat Özdemir (Kurucu Baba)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: KidsTheme.gold,
                side: BorderSide(color: KidsTheme.gold.withOpacity(0.5)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
