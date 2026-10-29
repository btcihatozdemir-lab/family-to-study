import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../../theme/fam_theme.dart';
import '../../services/supabase_service.dart';
import '../../services/session_manager.dart';
import 'coach_home_screen.dart';

class CoachAuthScreen extends StatefulWidget {
  const CoachAuthScreen({super.key});

  @override
  State<CoachAuthScreen> createState() => _CoachAuthScreenState();
}

class _CoachAuthScreenState extends State<CoachAuthScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _schoolNameController = TextEditingController();

  bool _isSignUp = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _schoolNameController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final success = await SupabaseService.signInWithGoogle();
    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        _navigateHome();
      } else {
        setState(() => _errorMessage = 'Google ile giriş başlatılamadı.');
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
      setState(() => _isLoading = false);
      if (success) {
        _navigateHome();
      } else {
        setState(() => _errorMessage = 'Apple ile giriş tamamlanamadı.');
      }
    }
  }

  Future<void> _handleEmailAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Lütfen e-posta ve şifrenizi girin.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isSignUp) {
        final fullName = _fullNameController.text.trim();
        final school = _schoolNameController.text.trim();

        if (fullName.isEmpty) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Lütfen adınızı ve soyadınızı girin.';
          });
          return;
        }

        final res = await SupabaseService.client.auth.signUp(
          email: email,
          password: password,
          data: {
            'full_name': fullName,
            'role': 'coach',
            'school_name': school,
          },
        );

        if (res.user != null) {
          _navigateHome();
        } else {
          setState(() => _errorMessage = 'Kayıt oluşturulamadı.');
        }
      } else {
        final res = await SupabaseService.client.auth.signInWithPassword(
          email: email,
          password: password,
        );

        if (res.user != null) {
          _navigateHome();
        } else {
          setState(() => _errorMessage = 'E-posta veya şifre hatalı.');
        }
      }
    } catch (e) {
      setState(() => _errorMessage = 'Giriş hatası: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const CoachHomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 28),

                  // OAuth Butonları
                  _buildOAuthSection(),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.white.withOpacity(0.12))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'veya E-Posta ile',
                          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.white.withOpacity(0.12))),
                    ],
                  ),
                  const SizedBox(height: 20),

                  if (_errorMessage != null) ...[
                    _buildErrorBox(_errorMessage!),
                    const SizedBox(height: 16),
                  ],

                  // Form Kartı
                  _buildFormCard(),
                  const SizedBox(height: 16),

                  // Kayıt Ol / Giriş Yap Değiştirme
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isSignUp = !_isSignUp;
                        _errorMessage = null;
                      });
                    },
                    child: Text(
                      _isSignUp
                          ? 'Zaten bir koç hesabınız var mı? Giriş Yapın'
                          : 'Yeni bir Öğretmen/Koç Hesabı Oluşturun',
                      style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 13, fontWeight: FontWeight.w700),
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
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.4), width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF38BDF8).withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Center(
            child: Text('🎓', style: TextStyle(fontSize: 42)),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'FamilyOS Koç Masası',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Öğretmen, Eğitim Mentoru & Kademe Koçu Portalı',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildOAuthSection() {
    return Column(
      children: [
        // Sign in with Apple
        SizedBox(
          height: 50,
          width: double.infinity,
          child: SignInWithAppleButton(
            onPressed: _isLoading ? null : _handleAppleSignIn,
            text: 'Apple ile Öğretmen Girişi',
            style: SignInWithAppleButtonStyle.white,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        const SizedBox(height: 10),

        // Google Sign-In
        SizedBox(
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
                  'Google / MEB E-Posta ile Giriş',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isSignUp) ...[
            _buildInputField(
              controller: _fullNameController,
              label: 'AD SOYAD / ÜNVAN',
              hint: 'Örn: Cihat Özdemir (Sosyal Bilgiler)',
              icon: Icons.person_rounded,
            ),
            const SizedBox(height: 12),
            _buildInputField(
              controller: _schoolNameController,
              label: 'OKUL / KADEME ADI (İSTEĞE BAĞLI)',
              hint: 'Örn: Akçakoca Ortaokulu',
              icon: Icons.account_balance_rounded,
            ),
            const SizedBox(height: 12),
          ],
          _buildInputField(
            controller: _emailController,
            label: 'E-POSTA ADRESİ',
            hint: 'ogretmen@meb.k12.tr veya gmail.com',
            icon: Icons.alternate_email_rounded,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          _buildInputField(
            controller: _passwordController,
            label: 'ŞİFRE',
            hint: '••••••••',
            icon: Icons.lock_outline_rounded,
            isPassword: true,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isLoading ? null : _handleEmailAuth,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4361EE),
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
                      Icon(_isSignUp ? Icons.how_to_reg_rounded : Icons.login_rounded, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        _isSignUp ? 'Koç Hesabı Oluştur & Başla' : 'Koç Masasına Giriş Yap',
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
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.w700),
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 12),
          border: InputBorder.none,
          prefixIcon: Icon(icon, color: const Color(0xFF38BDF8), size: 18),
        ),
      ),
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
}
