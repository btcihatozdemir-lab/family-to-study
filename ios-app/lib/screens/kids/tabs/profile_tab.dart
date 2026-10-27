import 'package:flutter/material.dart';
import '../../../models/user_model.dart';
import '../../../services/supabase_service.dart';
import '../../../services/session_manager.dart';
import '../../../theme/kids_theme.dart';
import '../kids_auth_screen.dart';

class ProfileTab extends StatefulWidget {
  final UserModel student;
  final VoidCallback onRefreshUser;

  const ProfileTab({
    super.key,
    required this.student,
    required this.onRefreshUser,
  });

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final List<String> _availableEmojis = ['🦄', '🦁', '🚀', '⭐', '🐯', '🐼', '🦊', '🐉', '🤖', '🦅'];

  Future<void> _changeAvatarEmoji(String newEmoji) async {
    try {
      await SupabaseService.client.from('users').update({
        'avatar_config': {
          'emoji': newEmoji,
          'bg': widget.student.avatarBg,
        },
      }).eq('id', widget.student.id);

      widget.onRefreshUser();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Profil avatarın $newEmoji olarak güncellendi!'),
          backgroundColor: KidsTheme.emerald,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('[changeAvatarEmoji] Hata: $e');
    }
  }

  void _showEmojiPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: KidsTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
              ),
              const SizedBox(height: 16),
              const Text(
                'Avatar Emojini Seç',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _availableEmojis.map((emoji) {
                  final isSelected = widget.student.avatarEmoji == emoji;
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      _changeAvatarEmoji(emoji);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected ? KidsTheme.primary : KidsTheme.surfaceElevated,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? KidsTheme.goldLight : Colors.white12,
                          width: 2,
                        ),
                      ),
                      child: Text(emoji, style: const TextStyle(fontSize: 28)),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KidsTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Çıkış Yapılsın mı?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'Oturumu kapatmak istediğine emin misin? Aile kodu veya PIN ile tekrar giriş yapabilirsin.',
          style: TextStyle(color: KidsTheme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç', style: TextStyle(color: KidsTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: KidsTheme.rose),
            child: const Text('Çıkış Yap', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await SessionManager.clearSession();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const KidsAuthScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final student = widget.student;

    return RefreshIndicator(
      onRefresh: () async => widget.onRefreshUser(),
      color: KidsTheme.primary,
      backgroundColor: KidsTheme.surface,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          // 1. Profil Başlık Kartı
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  KidsTheme.primary.withOpacity(0.4),
                  KidsTheme.purpleAccent.withOpacity(0.2),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: KidsTheme.primary.withOpacity(0.4)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6)),
              ],
            ),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    GestureDetector(
                      onTap: _showEmojiPicker,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(colors: [KidsTheme.primary, KidsTheme.purpleAccent]),
                          border: Border.all(color: KidsTheme.goldLight, width: 3),
                          boxShadow: [
                            BoxShadow(color: KidsTheme.gold.withOpacity(0.4), blurRadius: 12),
                          ],
                        ),
                        child: Center(
                          child: Text(student.avatarEmoji, style: const TextStyle(fontSize: 42)),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: KidsTheme.gold, shape: BoxShape.circle),
                        child: const Icon(Icons.edit, size: 14, color: Colors.black),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  student.name,
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Öğrenci Kaptan ⭐',
                    style: TextStyle(color: KidsTheme.goldLight, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 16),

                // Seviye ve XP İlerlemesi
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Seviye ${student.level}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                    ),
                    Text(
                      '${student.totalXp} / ${(student.level) * 100} XP',
                      style: const TextStyle(color: KidsTheme.textMuted, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: student.levelProgress,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation<Color>(KidsTheme.goldLight),
                    minHeight: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. Canlı İstatistikler Grid (Kasa, Cüzdan, Kalkan, Seri)
          Row(
            children: [
              Expanded(
                child: _buildStatTile(
                  icon: '🪙',
                  title: 'Cüzdan',
                  value: '${student.pointsBalance} Puan',
                  color: KidsTheme.goldLight,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatTile(
                  icon: '🏺',
                  title: 'Altın Kasa',
                  value: '${student.piggyBankBalance} Puan',
                  color: Colors.cyanAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatTile(
                  icon: '🛡️',
                  title: 'Çelik Kalkan',
                  value: '${student.dailyShields} / 3 Can',
                  color: Colors.greenAccent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatTile(
                  icon: '🔥',
                  title: 'Günlük Seri',
                  value: '${student.streakDays} Gün Streak',
                  color: Colors.deepOrangeAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 3. Kazanılan Başarılar & Rozetler
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: KidsTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text('🏆', style: TextStyle(fontSize: 18)),
                    SizedBox(width: 8),
                    Text(
                      'Kazanılan Rozetler',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildBadgeItem('🌅', 'Erken Kalkan', true),
                    _buildBadgeItem('🛡️', 'Çelik Kalkan', true),
                    _buildBadgeItem('📚', 'Ders Kurdu', true),
                    _buildBadgeItem('💛', 'Altın Kalp', true),
                    _buildBadgeItem('👑', 'Zirve Lideri', false),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 4. İzinli Ders Araçları (Whitelist Özeti)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: KidsTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text('🛡️', style: TextStyle(fontSize: 18)),
                    SizedBox(width: 8),
                    Text(
                      'Çalışma Saatinde İzinli Uygulamalar',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Ders saatinde odağın dağılmasın diye aşağıdaki uygulamalar serbesttir:',
                  style: TextStyle(color: KidsTheme.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildWhiteTag('📚 MEB & EBA Portalı'),
                    _buildWhiteTag('📝 Kunduz Soru Çözüm'),
                    _buildWhiteTag('💻 Scratch Kodlama'),
                    _buildWhiteTag('🇬🇧 Duolingo İngilizce'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 5. Çıkış Yap Butonu
          OutlinedButton.icon(
            onPressed: _handleLogout,
            icon: const Icon(Icons.logout_rounded, color: KidsTheme.rose),
            label: const Text('Oturumu Kapat', style: TextStyle(color: KidsTheme.rose, fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: KidsTheme.rose.withOpacity(0.5)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildStatTile({
    required String icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: KidsTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Text(title, style: const TextStyle(color: KidsTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeItem(String emoji, String title, bool unlocked) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: unlocked ? KidsTheme.primary.withOpacity(0.2) : Colors.white.withOpacity(0.04),
            shape: BoxShape.circle,
            border: Border.all(color: unlocked ? KidsTheme.goldLight : Colors.white12),
          ),
          child: Center(
            child: Text(
              emoji,
              style: TextStyle(fontSize: 22, color: unlocked ? null : Colors.white24),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            color: unlocked ? Colors.white : Colors.white38,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildWhiteTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
