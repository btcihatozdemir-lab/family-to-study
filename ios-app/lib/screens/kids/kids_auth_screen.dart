import 'package:flutter/material.dart';
import '../../theme/kids_theme.dart';
import '../../services/supabase_service.dart';
import 'kids_home_screen.dart';

class KidsAuthScreen extends StatefulWidget {
  const KidsAuthScreen({super.key});

  @override
  State<KidsAuthScreen> createState() => _KidsAuthScreenState();
}

class _KidsAuthScreenState extends State<KidsAuthScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _handleLogin() async {
    final input = _codeController.text.trim();
    if (input.isEmpty) {
      setState(() => _errorMessage = 'Lütfen 6 haneli kodunuzu veya PIN\'inizi girin.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // 1. Önce 6 Haneli Eşleştirme Kodu (Örn: 849-201) olarak dene
    var user = await SupabaseService.loginWithPairingCode(input);

    // 2. Olmazsa PIN / Şifre olarak dene
    user ??= await SupabaseService.loginWithPin(input);

    // 3. Olmazsa Sihirli Link jetonu olarak dene
    user ??= await SupabaseService.loginWithMagicToken(input);

    setState(() => _isLoading = false);

    if (user != null && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => KidsHomeScreen(initialStudent: user!)),
      );
    } else {
      setState(() {
        _errorMessage = 'Kod bulunamadı. Lütfen ebeveyn panelinizdeki 6 haneli kodu kontrol edin.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KidsTheme.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Kids Logo
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: KidsTheme.surface,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: KidsTheme.primary.withOpacity(0.5), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: KidsTheme.primary.withOpacity(0.3),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Image.asset(
                    'assets/images/kids_logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.stars_rounded,
                      color: KidsTheme.gold,
                      size: 54,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Başlık & Rozet
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: KidsTheme.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: KidsTheme.primary.withOpacity(0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome, color: KidsTheme.gold, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'AİLE AKADEMİSİ • KIDS',
                        style: TextStyle(
                          color: KidsTheme.primaryLight,
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                const Text(
                  'FamilyToStudy Kids',
                  style: TextStyle(
                    color: KidsTheme.textWhite,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),

                const Text(
                  'Ebeveyn panelinizde size özel üretilen 6 haneli kod veya şifrenizi girin:',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: KidsTheme.textMuted,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 32),

                // Kod Giriş Alanı
                Container(
                  decoration: KidsTheme.cardDecoration(
                    borderColor: KidsTheme.primary.withOpacity(0.4),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: TextField(
                    controller: _codeController,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: KidsTheme.goldLight,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                    ),
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _handleLogin(),
                    decoration: const InputDecoration(
                      hintText: '849-201 veya PIN',
                      hintStyle: TextStyle(
                        color: KidsTheme.textMuted,
                        fontSize: 16,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w600,
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Hata mesajı
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: KidsTheme.rose.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: KidsTheme.rose.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: KidsTheme.rose, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: KidsTheme.rose,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Giriş Yap Butonu
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: KidsTheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 8,
                      shadowColor: KidsTheme.primary.withOpacity(0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Maceraya Başla',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward_rounded, size: 20),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
