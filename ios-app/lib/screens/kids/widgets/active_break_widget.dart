import 'dart:math';
import 'package:flutter/material.dart';
import '../../../models/user_model.dart';
import '../../../services/supabase_service.dart';
import '../../../services/tts_service.dart';
import '../../../theme/kids_theme.dart';

class BreakChallenge {
  final String id;
  final String emoji;
  final String title;
  final String badge;
  final IconData icon;

  const BreakChallenge({
    required this.id,
    required this.emoji,
    required this.title,
    required this.badge,
    required this.icon,
  });
}

class ActiveBreakWidget extends StatefulWidget {
  final UserModel student;
  final VoidCallback onRefreshUser;

  const ActiveBreakWidget({
    super.key,
    required this.student,
    required this.onRefreshUser,
  });

  @override
  State<ActiveBreakWidget> createState() => _ActiveBreakWidgetState();
}

class _ActiveBreakWidgetState extends State<ActiveBreakWidget> {
  static const List<BreakChallenge> challenges = [
    BreakChallenge(
      id: 'jump-breathe',
      emoji: '🌬️',
      title: 'Pencereyi aç, 5 derin nefes al ve 10 kez zıpla!',
      badge: 'Oksijen & Kardiyo',
      icon: Icons.air_rounded,
    ),
    BreakChallenge(
      id: 'water-eyes',
      emoji: '💧',
      title: 'Mutfağa git, bir bardak su iç ve gözlerini 20 saniye uzağa bakarak dinlendir!',
      badge: 'Hidrasyon & Göz',
      icon: Icons.water_drop_rounded,
    ),
    BreakChallenge(
      id: 'shoulder-stretch',
      emoji: '🧘‍♂️',
      title: 'Omuzlarını 10 kez geriye çevir ve kollarını yukarı uzatarak esne!',
      badge: 'Duruş & Esneme',
      icon: Icons.self_improvement_rounded,
    ),
    BreakChallenge(
      id: 'neck-march',
      emoji: '🏃‍♂️',
      title: 'Ayağa kalk, 30 saniye olduğun yerde tempolu yürü ve kollarını salla!',
      badge: 'Kan Dolaşımı',
      icon: Icons.directions_run_rounded,
    ),
  ];

  int _selectedIndex = 0;
  bool _isSpinning = false;
  bool _completedThisBreak = false;

  void _spinWheel() {
    if (_isSpinning) return;
    setState(() {
      _isSpinning = true;
      _completedThisBreak = false;
    });

    int ticks = 0;
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 90));
      if (!mounted) return false;
      setState(() {
        _selectedIndex = (_selectedIndex + 1) % challenges.length;
      });
      ticks++;
      if (ticks >= 12) {
        setState(() {
          _selectedIndex = Random().nextInt(challenges.length);
          _isSpinning = false;
        });
        TTSService.speak(challenges[_selectedIndex].title);
        return false;
      }
      return true;
    });
  }

  Future<void> _handleComplete() async {
    if (_completedThisBreak || _isSpinning) return;
    setState(() => _completedThisBreak = true);

    final ch = challenges[_selectedIndex];
    TTSService.speak('Harika! Enerji molasını tamamladın, tebrikler!');

    // Puan ekle (+5 Puan)
    final freshPoints = widget.student.pointsBalance + 5;
    try {
      await SupabaseService.client
          .from('users')
          .update({'points_balance': freshPoints})
          .eq('id', widget.student.id);

      widget.onRefreshUser();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 Harika! "${ch.badge}" tamamlandı ve +5 Enerji Puanı kazandın!'),
            backgroundColor: KidsTheme.emerald,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print('[ActiveBreakWidget] Hata: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ch = challenges[_selectedIndex];
    final bool isBreakTime = widget.student.currentState == 'BREAK_TIME';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isBreakTime
              ? [const Color(0xFF064E3B), const Color(0xFF0F766E), const Color(0xFF0F172A)]
              : [const Color(0xFF0F172A), const Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isBreakTime ? KidsTheme.emerald : Colors.cyan.withOpacity(0.3),
          width: isBreakTime ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (isBreakTime ? KidsTheme.emerald : Colors.cyan).withOpacity(0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isBreakTime ? KidsTheme.emerald.withOpacity(0.2) : Colors.cyan.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Text(ch.emoji, style: const TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          isBreakTime ? '🔔 MOLA & ENERJİ ZAMANI' : '⚡ BİLİŞSEL ENERJİ MOLASI',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: isBreakTime ? KidsTheme.emeraldLight : KidsTheme.cyan,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.amberAccent.withOpacity(0.4)),
                          ),
                          child: const Text(
                            '+5 Puan',
                            style: TextStyle(color: Colors.amberAccent, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ch.badge,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              // Çarkı Çevir Butonu
              IconButton(
                onPressed: _isSpinning ? null : _spinWheel,
                icon: const Icon(Icons.refresh_rounded, color: Colors.cyanAccent),
                tooltip: 'Başka Egzersiz Seç',
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Challenge Açıklaması
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Text(
              ch.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Butonlar (Yaptım / Çevir)
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _completedThisBreak ? null : _handleComplete,
                  icon: Icon(
                    _completedThisBreak ? Icons.check_circle_rounded : Icons.bolt_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  label: Text(
                    _completedThisBreak ? 'Tamamlandı (+5 Puan) ✅' : 'Egzersizi Yaptım (+5 Puan) ⚡',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _completedThisBreak ? Colors.teal.shade800 : KidsTheme.emerald,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _isSpinning ? null : _spinWheel,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.cyanAccent.withOpacity(0.4)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Değiştir 🎲', style: TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
