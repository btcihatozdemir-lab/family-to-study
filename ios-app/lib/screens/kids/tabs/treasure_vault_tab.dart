import 'package:flutter/material.dart';
import '../../../models/user_model.dart';
import '../../../models/reward_model.dart';
import '../../../services/supabase_service.dart';
import '../../../theme/kids_theme.dart';

class TreasureVaultTab extends StatefulWidget {
  final UserModel student;
  final VoidCallback onRefreshUser;

  const TreasureVaultTab({
    super.key,
    required this.student,
    required this.onRefreshUser,
  });

  @override
  State<TreasureVaultTab> createState() => _TreasureVaultTabState();
}

class _TreasureVaultTabState extends State<TreasureVaultTab> {
  bool _isLoading = false;
  List<RewardModel> _rewards = [];

  @override
  void initState() {
    super.initState();
    _loadRewards();
  }

  Future<void> _loadRewards() async {
    setState(() => _isLoading = true);
    final list = await SupabaseService.getRewards(widget.student.familyId);
    if (mounted) {
      setState(() {
        _rewards = list;
        _isLoading = false;
      });
    }
  }

  void _openTransferModal(bool toPiggyBank) {
    int maxAmount = toPiggyBank ? widget.student.pointsBalance : widget.student.piggyBankBalance;
    if (maxAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            toPiggyBank
                ? 'Kasaya aktarılacak harcanabilir puanın bulunmuyor.'
                : 'Kasanda çekilebilecek birikim bulunmuyor.',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: KidsTheme.roseLight,
        ),
      );
      return;
    }

    int selectedAmount = (maxAmount / 2).round().clamp(1, maxAmount);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: KidsTheme.cardSlate,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 32,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: KidsTheme.goldAmber.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          toPiggyBank ? '🏺' : '🪙',
                          style: const TextStyle(fontSize: 26),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              toPiggyBank ? 'Kasaya Altın Aktar' : 'Kasadan Cüzdana Çek',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              toPiggyBank
                                  ? 'Pazar günü +%20 haftalık kâr kazanırsın!'
                                  : 'Cüzdana çekilen puanlar faiz kazandırmaz.',
                              style: const TextStyle(
                                fontSize: 12,
                                color: KidsTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      '$selectedAmount 🪙',
                      style: const TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        color: KidsTheme.goldAmber,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: KidsTheme.goldAmber,
                      inactiveTrackColor: Colors.white12,
                      thumbColor: KidsTheme.goldAmber,
                      overlayColor: KidsTheme.goldAmber.withOpacity(0.2),
                    ),
                    child: Slider(
                      min: 1,
                      max: maxAmount.toDouble(),
                      value: selectedAmount.toDouble().clamp(1.0, maxAmount.toDouble()),
                      divisions: maxAmount > 1 ? maxAmount - 1 : 1,
                      onChanged: (val) {
                        setModalState(() {
                          selectedAmount = val.round();
                        });
                      },
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '1 🪙',
                        style: TextStyle(fontSize: 12, color: KidsTheme.textMuted),
                      ),
                      Text(
                        'En Fazla: $maxAmount 🪙',
                        style: const TextStyle(
                          fontSize: 12,
                          color: KidsTheme.goldAmber,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      setState(() => _isLoading = true);
                      final ok = await SupabaseService.transferToPiggyBank(
                        widget.student.id,
                        toPiggyBank ? selectedAmount : -selectedAmount,
                      );
                      setState(() => _isLoading = false);
                      if (ok) {
                        widget.onRefreshUser();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              toPiggyBank
                                  ? '$selectedAmount altın kasana aktarıldı! 🏺'
                                  : '$selectedAmount altın cüzdanına çekildi! 🪙',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            backgroundColor: KidsTheme.emeraldGreen,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: toPiggyBank ? KidsTheme.goldAmber : KidsTheme.indigoPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      toPiggyBank ? 'Kasaya Kilitle (+%20 Kâr)' : 'Cüzdana Aktar',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _confirmRedeem(RewardModel reward) {
    if (widget.student.pointsBalance < reward.pointsCost) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: KidsTheme.cardSlate,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Text('💎 ', style: TextStyle(fontSize: 24)),
              Text('Yetersiz Bakiye', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: Text(
            'Bu ödülü almak için ${reward.pointsCost} puana ihtiyacın var.\nŞu an cüzdanında ${widget.student.pointsBalance} puan bulunuyor. Görevleri tamamlayarak puan biriktirebilirsin!',
            style: const TextStyle(color: KidsTheme.textMuted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Anladım', style: TextStyle(color: KidsTheme.goldAmber)),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KidsTheme.cardSlate,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Text('🎁 ', style: TextStyle(fontSize: 24)),
            Expanded(
              child: Text(
                reward.title,
                style: const TextStyle(color: Colors.white, fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              reward.description.isNotEmpty
                  ? reward.description
                  : 'Bu ödülü almak için ailenize talep iletilecektir.',
              style: const TextStyle(color: KidsTheme.textMuted, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Ödül Bedeli:', style: TextStyle(color: KidsTheme.textMuted)),
                  Text(
                    '${reward.pointsCost} Puan 🪙',
                    style: const TextStyle(
                      color: KidsTheme.goldAmber,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
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
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              final ok = await SupabaseService.redeemReward(
                studentId: widget.student.id,
                rewardId: reward.id,
                cost: reward.pointsCost,
              );
              setState(() => _isLoading = false);
              if (ok) {
                widget.onRefreshUser();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Tebrikler! "${reward.title}" ödül talebin iletildi. 🎉'),
                    backgroundColor: KidsTheme.emeraldGreen,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: KidsTheme.emeraldGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Satın Al', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        widget.onRefreshUser();
        await _loadRewards();
      },
      color: KidsTheme.goldAmber,
      backgroundColor: KidsTheme.surfaceElevated,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // 1. Vault & Wallet Dual Card
          _buildVaultBalanceCard(),
          const SizedBox(height: 16),

          // 2. Sunday Bonus Banner
          _buildSundayBonusBanner(),
          const SizedBox(height: 24),

          // 3. Rewards Market Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Text('🎁', style: TextStyle(fontSize: 22)),
                  SizedBox(width: 8),
                  Text(
                    'Ödül Pazarı',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_rewards.length} Ödül',
                  style: const TextStyle(fontSize: 12, color: KidsTheme.textMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 4. Rewards List
          if (_isLoading && _rewards.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(color: KidsTheme.goldAmber),
              ),
            )
          else if (_rewards.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: KidsTheme.cardSlate,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white10),
              ),
              child: const Column(
                children: [
                  Text('🏺', style: TextStyle(fontSize: 40)),
                  SizedBox(height: 8),
                  Text(
                    'Henüz ödül eklenmemiş',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Aileniz ödül eklediğinde burada görebilir ve puanlarınla alabilirsin.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: KidsTheme.textMuted, fontSize: 13),
                  ),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _rewards.length,
              itemBuilder: (context, index) {
                final r = _rewards[index];
                return _buildRewardCard(r);
              },
            ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildVaultBalanceCard() {
    return Container(
      decoration: BoxDecoration(
        color: KidsTheme.cardSlate,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: KidsTheme.goldAmber.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Harcanabilir Cüzdan
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Text('🪙', style: TextStyle(fontSize: 18)),
                            SizedBox(width: 6),
                            Text(
                              'Cüzdan',
                              style: TextStyle(
                                fontSize: 13,
                                color: KidsTheme.textMuted,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${widget.student.pointsBalance}',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: KidsTheme.goldAmber,
                          ),
                        ),
                        const Text(
                          'Harcanabilir Altın',
                          style: TextStyle(fontSize: 11, color: KidsTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Birikim Kasası
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          KidsTheme.indigoPrimary.withOpacity(0.35),
                          KidsTheme.purpleAccent.withOpacity(0.25),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: KidsTheme.indigoPrimary.withOpacity(0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Text('🏺', style: TextStyle(fontSize: 18)),
                            SizedBox(width: 6),
                            Text(
                              'Altın Kasa',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white70,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${widget.student.piggyBankBalance}',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const Text(
                          'Haftalık Kârda',
                          style: TextStyle(fontSize: 11, color: KidsTheme.emeraldGreen, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(color: Colors.white.withOpacity(0.08), height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openTransferModal(true),
                    icon: const Text('📥', style: TextStyle(fontSize: 16)),
                    label: const Text('Kasaya At', style: TextStyle(color: Colors.white)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openTransferModal(false),
                    icon: const Text('📤', style: TextStyle(fontSize: 16)),
                    label: const Text('Kasadan Çek', style: TextStyle(color: KidsTheme.textMuted)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.white.withOpacity(0.1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSundayBonusBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KidsTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: KidsTheme.emeraldGreen.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: KidsTheme.emeraldGreen.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Text('💎', style: TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pazar Günü +%20 Bonus',
                  style: TextStyle(
                    color: KidsTheme.emeraldGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Kasada bekleyen her 100 altına Pazar gecesi 20 altın faiz hediyesi eklenir!',
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
    );
  }

  Widget _buildRewardCard(RewardModel reward) {
    final bool canAfford = widget.student.pointsBalance >= reward.pointsCost;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KidsTheme.cardSlate,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: canAfford ? KidsTheme.goldAmber.withOpacity(0.3) : Colors.white.withOpacity(0.06),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: canAfford
                  ? KidsTheme.goldAmber.withOpacity(0.15)
                  : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                _getRewardIcon(reward.iconName),
                style: const TextStyle(fontSize: 26),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reward.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                if (reward.description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    reward.description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: KidsTheme.textMuted,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      '${reward.pointsCost} 🪙',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: KidsTheme.goldAmber,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        reward.tier.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: KidsTheme.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: reward.isAvailable ? () => _confirmRedeem(reward) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: canAfford ? KidsTheme.emeraldGreen : Colors.white12,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            child: Text(
              canAfford ? 'Al' : 'Eksik',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: canAfford ? Colors.white : Colors.white38,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getRewardIcon(String icon) {
    switch (icon.toLowerCase()) {
      case 'game':
      case 'gamepad':
        return '🎮';
      case 'book':
        return '📚';
      case 'pizza':
      case 'food':
        return '🍕';
      case 'film':
      case 'movie':
        return '🎬';
      case 'park':
        return '🎡';
      case 'bike':
        return '🚲';
      case 'star':
        return '⭐';
      default:
        return '🎁';
    }
  }
}
