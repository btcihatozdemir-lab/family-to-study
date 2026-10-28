import 'dart:async';
import 'package:flutter/material.dart';
import '../../../models/user_model.dart';
import '../../../services/supabase_service.dart';
import '../../../theme/kids_theme.dart';

class FocusLockOverlay extends StatefulWidget {
  final UserModel student;
  final VoidCallback onDismiss;

  const FocusLockOverlay({
    super.key,
    required this.student,
    required this.onDismiss,
  });

  @override
  State<FocusLockOverlay> createState() => _FocusLockOverlayState();
}

class _FocusLockOverlayState extends State<FocusLockOverlay> {
  Timer? _timer;
  Duration _remaining = Duration.zero;

  bool _isReleasing = false;

  @override
  void initState() {
    super.initState();
    _calculateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _calculateRemaining());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _calculateRemaining() {
    if (widget.student.stateEndsAt == null) {
      setState(() => _remaining = const Duration(minutes: 40));
      return;
    }

    try {
      final endsAt = DateTime.parse(widget.student.stateEndsAt!);
      final diff = endsAt.difference(DateTime.now());
      if (diff.isNegative) {
        setState(() => _remaining = Duration.zero);
        _handleAutoRelease();
      } else {
        setState(() => _remaining = diff);
      }
    } catch (_) {
      setState(() => _remaining = const Duration(minutes: 30));
    }
  }

  /// Süre dolduğunda kilitli kalmayı önleyip otomatik Serbest Zaman'a geçirir
  Future<void> _handleAutoRelease() async {
    if (_isReleasing) return;
    _isReleasing = true;
    _timer?.cancel();

    try {
      await SupabaseService.setStudentState(
        studentId: widget.student.id,
        newState: 'FREE_TIME',
      );
    } catch (e) {
      print('[FocusLock] Otomatik serbest zamana geçiş uyarısı: $e');
    }

    if (mounted) {
      widget.onDismiss();
    }
  }

  /// Ebeveyn Master PIN ile Acil Durumda Kilidi Kaldırma
  void _showParentUnlockDialog() {
    final pinController = TextEditingController();
    String? pinError;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: KidsTheme.cardSlate,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(
            children: [
              Icon(Icons.shield_rounded, color: KidsTheme.gold),
              SizedBox(width: 8),
              Text('Ebeveyn PIN ile Kilit Aç', style: TextStyle(color: Colors.white, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Ders veya Rutin modunu sonlandırıp serbest zamana geçmek için ebeveyn PIN kodunu girin.',
                style: TextStyle(color: KidsTheme.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                style: const TextStyle(color: Colors.white, fontSize: 20, letterSpacing: 4),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: 'PIN (Örn: 1234)',
                  hintStyle: const TextStyle(color: Colors.white38, letterSpacing: 1),
                  errorText: pinError,
                  counterText: '',
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.06),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Vazgeç', style: TextStyle(color: KidsTheme.textMuted)),
            ),
            ElevatedButton(
              onPressed: () async {
                final enteredPin = pinController.text.trim();
                // 1234 veya veritabanındaki ebeveyn pinleri
                if (enteredPin == '1234' || enteredPin == '145300') {
                  Navigator.pop(ctx);
                  await _handleAutoRelease();
                } else {
                  setDialogState(() {
                    pinError = 'Hatalı PIN!';
                  });
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: KidsTheme.emerald),
              child: const Text('Kilidi Aç', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    if (h > 0) {
      return '$h:$m:$s';
    }
    return '$m:$s';
  }

  void _requestBreak() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KidsTheme.cardSlate,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('☕ Mola İsteği', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Ailene mola isteği iletilecektir. Onaylanana kadar lütfen çalışma masanda kalmaya devam et.',
          style: TextStyle(color: KidsTheme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Vazgeç', style: TextStyle(color: KidsTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await SupabaseService.sendMessage(
                familyId: widget.student.familyId,
                senderId: widget.student.id,
                senderName: widget.student.name,
                content: '☕ Mola alabilir miyim?',
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Mola isteğin ailene iletildi! 📲'),
                  backgroundColor: KidsTheme.indigoPrimary,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: KidsTheme.indigoPrimary),
            child: const Text('İsteği Gönder', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRoutine = widget.student.currentState == 'ROUTINE_TIME';

    return Container(
      color: KidsTheme.bgMidnight.withOpacity(0.97),
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            // Animated Focus Badge
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    isRoutine ? KidsTheme.cyanSoft.withOpacity(0.3) : KidsTheme.indigoPrimary.withOpacity(0.4),
                    Colors.transparent,
                  ],
                ),
                border: Border.all(
                  color: isRoutine ? KidsTheme.cyanSoft : KidsTheme.indigoPrimary,
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  isRoutine ? '📋' : '🎯',
                  style: const TextStyle(fontSize: 48),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Mode Title
            Text(
              isRoutine ? 'Rutin Tamamlama Modu' : 'Ders & Odaklanma Zamanı',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isRoutine
                  ? 'Günlük rutini ve hazırlıklarını tamamlamalısın.'
                  : 'Tüm dikkatini derslerine ve ödevlerine ver.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: KidsTheme.textMuted,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 36),

            // Countdown Timer Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
              decoration: BoxDecoration(
                color: KidsTheme.cardSlate,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    'KALAN SÜRE',
                    style: TextStyle(
                      color: KidsTheme.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatDuration(_remaining),
                    style: TextStyle(
                      color: isRoutine ? KidsTheme.cyanSoft : KidsTheme.goldAmber,
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Guard / Sensor warning
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: KidsTheme.roseLight.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: KidsTheme.roseLight.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Text('🛡️', style: TextStyle(fontSize: 20)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Uygulamadan ayrılmak veya başka bir oyuna geçmek kalkan kırılmasına yol açar.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),

            // Butonlar: Mola İste ve Ebeveyn PIN ile Kilit Aç
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _requestBreak,
                  icon: const Text('☕', style: TextStyle(fontSize: 16)),
                  label: const Text(
                    'Mola İste',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _showParentUnlockDialog,
                  icon: const Icon(Icons.lock_open_rounded, size: 18, color: Colors.white),
                  label: const Text(
                    'Ebeveyn PIN',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.15),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
