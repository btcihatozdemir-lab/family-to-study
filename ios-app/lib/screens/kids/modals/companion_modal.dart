import 'package:flutter/material.dart';
import '../../../models/user_model.dart';
import '../../../theme/kids_theme.dart';

class CompanionModal extends StatefulWidget {
  final UserModel student;

  const CompanionModal({super.key, required this.student});

  static Future<void> show(BuildContext context, UserModel student) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CompanionModal(student: student),
    );
  }

  @override
  State<CompanionModal> createState() => _CompanionModalState();
}

class _CompanionModalState extends State<CompanionModal> with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  int _petHappiness = 85;
  int _petEnergy = 90;
  int _petXp = 45;
  String _petStatusMessage = 'Seninle görev yapmayı çok seviyorum! 🔥';
  String _currentActionEmoji = '🐉';

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _feedPet() {
    setState(() {
      _petEnergy = (_petEnergy + 10).clamp(0, 100);
      _petXp = (_petXp + 15).clamp(0, 100);
      _currentActionEmoji = '🍖';
      _petStatusMessage = 'Nefis! Enerjim tavan yaptı! 💪';
    });
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() => _currentActionEmoji = '🐉');
      }
    });
  }

  void _petPet() {
    setState(() {
      _petHappiness = (_petHappiness + 15).clamp(0, 100);
      _petXp = (_petXp + 10).clamp(0, 100);
      _currentActionEmoji = '❤️';
      _petStatusMessage = 'Mırrr! Sevilmek harika bir his! 🥰';
    });
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() => _currentActionEmoji = '🐉');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: KidsTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Başlık
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Text('🐉', style: TextStyle(fontSize: 26)),
                  SizedBox(width: 8),
                  Text(
                    'Sanal Yoldaşım: Ateş Ejderi',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: KidsTheme.gold.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: KidsTheme.goldLight),
                ),
                child: Text(
                  'Lv.${widget.student.level}',
                  style: const TextStyle(
                    color: KidsTheme.goldLight,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Animasyonlu Ejderha Alanı
          ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.05).animate(
              CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut),
            ),
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    KidsTheme.primary.withOpacity(0.4),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Center(
                child: Text(
                  _currentActionEmoji,
                  style: const TextStyle(fontSize: 72),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Durum Mesajı Balonu
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: KidsTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Text(
              _petStatusMessage,
              style: const TextStyle(
                color: KidsTheme.goldLight,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // İlerleme Barları (Mutluluk, Enerji, XP)
          _buildStatBar('Mutluluk', _petHappiness, Colors.pinkAccent, '❤️'),
          const SizedBox(height: 8),
          _buildStatBar('Enerji', _petEnergy, Colors.amber, '⚡'),
          const SizedBox(height: 8),
          _buildStatBar('Evrim XP', _petXp, KidsTheme.cyan, '🌟'),
          const SizedBox(height: 24),

          // Aksiyon Butonları
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _feedPet,
                  icon: const Text('🍖', style: TextStyle(fontSize: 18)),
                  label: const Text('Besle (+15 XP)', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: KidsTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _petPet,
                  icon: const Text('💖', style: TextStyle(fontSize: 18)),
                  label: const Text('Sev (+10 XP)', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pink.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatBar(String title, int value, Color color, String emoji) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: const TextStyle(color: KidsTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Text(
              '%$value',
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: value / 100.0,
            backgroundColor: KidsTheme.surfaceElevated,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}
