import 'package:flutter/material.dart';
import '../../../models/user_model.dart';
import '../../../services/supabase_service.dart';
import '../../../services/tts_service.dart';
import '../../../theme/kids_theme.dart';

class MorningAlarmOverlay extends StatefulWidget {
  final UserModel student;
  final VoidCallback onDismissed;

  const MorningAlarmOverlay({
    super.key,
    required this.student,
    required this.onDismissed,
  });

  @override
  State<MorningAlarmOverlay> createState() => _MorningAlarmOverlayState();
}

class _MorningAlarmOverlayState extends State<MorningAlarmOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    // Speak cheerful wake-up greeting via TTS
    TtsService.speak(
      'Günaydın ${widget.student.name}! Harika bir gün seni bekliyor, haydi yataktan kalkma vakti!',
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    TtsService.stop();
    super.dispose();
  }

  Future<void> _handleWakeUp() async {
    setState(() => _isDismissing = true);
    await TtsService.stop();
    await SupabaseService.dismissWakeUpAlarm(widget.student.id);
    if (mounted) {
      widget.onDismissed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: KidsTheme.bgMidnight.withOpacity(0.98),
      width: double.infinity,
      height: double.infinity,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // Pulsing Sun & Alarm Ring
              ScaleTransition(
                scale: Tween<double>(begin: 0.9, end: 1.15).animate(
                  CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
                ),
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: KidsTheme.goldAmber.withOpacity(0.4),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ],
                    gradient: const RadialGradient(
                      colors: [
                        KidsTheme.goldAmber,
                        Colors.deepOrangeAccent,
                      ],
                    ),
                  ),
                  child: const Center(
                    child: Text('🌅', style: TextStyle(fontSize: 64)),
                  ),
                ),
              ),
              const SizedBox(height: 36),

              Text(
                'Günaydın ${widget.student.name}!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Uyanma ve güne enerjik başlama zamanı.\nYatağını topla, elini yüzünü yıka ve rutine başla!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: KidsTheme.textMuted,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),

              // Bonus Daily Shield Reminder
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: KidsTheme.cardSlate,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: KidsTheme.goldAmber.withOpacity(0.3)),
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
                            'Günlük 3 Kalkanın Yenilendi!',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            'Sabah rutinini vaktinde tamamlayarak altın puanları topla.',
                            style: TextStyle(
                              color: KidsTheme.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),

              // Wake up action button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isDismissing ? null : _handleWakeUp,
                  icon: _isDismissing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('☀️', style: TextStyle(fontSize: 22)),
                  label: Text(
                    _isDismissing ? 'Gün Başlatılıyor...' : 'Uyandım, Güne Başlıyorum!',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: KidsTheme.goldAmber,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 6,
                    shadowColor: KidsTheme.goldAmber.withOpacity(0.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
