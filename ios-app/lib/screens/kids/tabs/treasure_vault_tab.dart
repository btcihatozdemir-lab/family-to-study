import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../models/user_model.dart';
import '../../../models/reward_model.dart';
import '../../../models/lingua_model.dart';
import '../../../services/supabase_service.dart';
import '../../../services/time_vault_service.dart';
import '../../../theme/kids_theme.dart';
import '../modals/gift_points_modal.dart';

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

class _TreasureVaultTabState extends State<TreasureVaultTab> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  List<RewardModel> _rewards = [];
  String _selectedTier = 'all';
  int _todayCompletedTasks = 0;
  LinguaModel? _linguaWord;
  int _savedVaultMinutes = 30;
  bool _graceBreakRequested = false;

  // Şans Çarkı Animasyon State
  late AnimationController _wheelAnimCtrl;
  bool _isSpinning = false;
  double _wheelRotationAngle = 0.0;

  @override
  void initState() {
    super.initState();
    _loadRewards();
    _loadExtraFeatures();

    _wheelAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );
  }

  @override
  void dispose() {
    _wheelAnimCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRewards() async {
    setState(() => _isLoading = true);
    final list = await SupabaseService.fetchRewards(widget.student.familyId);
    final count = await SupabaseService.fetchTodayCompletedTasksCount(widget.student.id);
    if (mounted) {
      setState(() {
        _rewards = list;
        _todayCompletedTasks = count;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadExtraFeatures() async {
    final vault = await TimeVaultService.fetchTimeVault(widget.student.id);
    final word = await TimeVaultService.fetchWordOfTheDay();
    if (mounted) {
      setState(() {
        if (vault != null) _savedVaultMinutes = vault.savedMinutes;
        _linguaWord = word;
      });
    }
  }

  Future<void> _handleSpinWheel() async {
    if (_isSpinning) return;

    setState(() => _isSpinning = true);

    // Çarkı rastgele 5-8 tam tur + rastgele açı ile döndür
    final randomTurns = 5 + math.Random().nextInt(3);
    final randomExtra = math.Random().nextDouble() * 2 * math.pi;
    final targetAngle = _wheelRotationAngle + (randomTurns * 2 * math.pi) + randomExtra;

    final animation = Tween<double>(
      begin: _wheelRotationAngle,
      end: targetAngle,
    ).animate(CurvedAnimation(parent: _wheelAnimCtrl, curve: Curves.easeOutCubic));

    animation.addListener(() {
      setState(() {
        _wheelRotationAngle = animation.value;
      });
    });

    _wheelAnimCtrl.forward(from: 0.0);

    // Supabase backend'den ödülü al
    final prize = await SupabaseService.spinLuckyWheel(widget.student.id);

    await Future.delayed(const Duration(milliseconds: 3300));
    if (!mounted) return;

    setState(() => _isSpinning = false);

    final wonPrize = prize ?? 25;
    widget.onRefreshUser();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KidsTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Center(child: Text('🎡 TEBRİKLER! 🎉', style: TextStyle(color: KidsTheme.goldLight, fontWeight: FontWeight.w900))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: KidsTheme.gold.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Text('🪙', style: TextStyle(fontSize: 48)),
            ),
            const SizedBox(height: 16),
            Text(
              '+$wonPrize Altın Puan!',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Günün şans çarkından altın puan kazandın ve cüzdanına eklendi!',
              textAlign: TextAlign.center,
              style: TextStyle(color: KidsTheme.textMuted, fontSize: 13),
            ),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: KidsTheme.gold,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: const Text('Harika!', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
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
          backgroundColor: KidsTheme.rose,
        ),
      );
      return;
    }

    int selectedAmount = (maxAmount / 2).round().clamp(1, maxAmount);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: KidsTheme.surface,
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
                          color: KidsTheme.gold.withOpacity(0.15),
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
                                  ? 'Kasada duran altına her Pazar +%20 faiz eklenir'
                                  : 'İstediğin zaman ödül almak için cüzdanına çekebilirsin',
                              style: const TextStyle(fontSize: 12, color: KidsTheme.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Miktar Seçin:',
                        style: TextStyle(color: KidsTheme.textMuted, fontSize: 14),
                      ),
                      Text(
                        '$selectedAmount 🪙',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: KidsTheme.goldLight,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: selectedAmount.toDouble(),
                    min: 1,
                    max: maxAmount.toDouble(),
                    divisions: maxAmount > 1 ? maxAmount - 1 : 1,
                    activeColor: KidsTheme.gold,
                    inactiveColor: Colors.white12,
                    onChanged: (val) {
                      setModalState(() {
                        selectedAmount = val.round();
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final transferValue = toPiggyBank ? selectedAmount : -selectedAmount;
                      final ok = await SupabaseService.transferToPiggyBank(
                        widget.student.id,
                        transferValue,
                      );
                      if (ok) {
                        widget.onRefreshUser();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              toPiggyBank
                                  ? '$selectedAmount altın kasaya kilitlendi! (+%20 kâr işliyor) 🏺'
                                  : '$selectedAmount altın cüzdanına çekildi. 🪙',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            backgroundColor: KidsTheme.emerald,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: toPiggyBank ? KidsTheme.gold : KidsTheme.primary,
                      foregroundColor: toPiggyBank ? Colors.black : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      toPiggyBank ? 'Kasaya Kilitle (+%20 Kâr) 🏺' : 'Cüzdana Aktar 🪙',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
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
          backgroundColor: KidsTheme.surface,
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
              child: const Text('Anladım', style: TextStyle(color: KidsTheme.goldLight)),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KidsTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Text('🎁 ', style: TextStyle(fontSize: 24)),
            Expanded(
              child: Text(
                reward.title,
                style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
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
                      color: KidsTheme.goldLight,
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
                familyId: widget.student.familyId,
                studentId: widget.student.id,
                rewardId: reward.id,
                cost: reward.pointsCost,
              );
              setState(() => _isLoading = false);
              if (ok) {
                widget.onRefreshUser();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Tebrikler! "${reward.title}" ödül talebin veline iletildi. 🎉'),
                    backgroundColor: KidsTheme.emerald,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: KidsTheme.emerald,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Satın Al', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  List<RewardModel> get _filteredRewards {
    if (_selectedTier == 'all') return _rewards;
    return _rewards.where((r) => r.tier.toLowerCase() == _selectedTier).toList();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        widget.onRefreshUser();
        await _loadRewards();
      },
      color: KidsTheme.goldLight,
      backgroundColor: KidsTheme.surfaceElevated,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          // 1. Kasa & Cüzdan Kartı
          _buildVaultBalanceCard(),
          const SizedBox(height: 14),

          // 2. Zaman Bankası & 5 Dk Mola İste Kartı
          _buildTimeVaultAndGraceCard(),
          const SizedBox(height: 14),

          // 3. Günün Kelimesi & Zihin Açıcı Sır Kartı
          if (_linguaWord != null) ...[
            _buildWordOfTheDayCard(),
            const SizedBox(height: 14),
          ],

          // 4. Şans Çarkı Kartı (Lucky Wheel)
          _buildLuckyWheelCard(),
          const SizedBox(height: 14),

          // 5. Kardeşe Puan Gönder & Dayanışma Kartı
          _buildSiblingGiftCard(),
          const SizedBox(height: 18),

          // 6. Ödül Marketi Başlığı & Filtre Hapları
          _buildMarketHeader(),
          const SizedBox(height: 12),

          // 5. Ödül Kartları
          if (_isLoading && _rewards.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(color: KidsTheme.goldLight),
              ),
            )
          else if (_filteredRewards.isEmpty)
            _buildEmptyMarket()
          else
            ..._filteredRewards.map((r) => _buildRewardCard(r)),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildTimeVaultAndGraceCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KidsTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🏦', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Zaman Bankası & Esneklik', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
                    Text('Hafta içi biriktirdiğin süre hafta sonu açılır', style: TextStyle(color: KidsTheme.textMuted, fontSize: 11)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF06B6D4).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$_savedVaultMinutes dk Birikti',
                  style: const TextStyle(color: Color(0xFF06B6D4), fontWeight: FontWeight.w900, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _graceBreakRequested
                  ? null
                  : () async {
                      setState(() => _graceBreakRequested = true);
                      final res = await TimeVaultService.requestGraceBreak();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: res['success'] == true ? Colors.teal : Colors.orange,
                            content: Text(res['message']?.toString() ?? 'Mola isteği iletildi.'),
                          ),
                        );
                      }
                    },
              icon: const Text('☕', style: TextStyle(fontSize: 16)),
              label: Text(
                _graceBreakRequested ? '5 Dk Mola Aktif Edildi' : '5 Dakika Acil Mola İste (Günde 1 Hak)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF06B6D4),
                side: BorderSide(color: const Color(0xFF06B6D4).withOpacity(0.5)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWordOfTheDayCard() {
    final w = _linguaWord!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KidsTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: KidsTheme.gold.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📖', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Günün Kelimesi: ${w.word}', style: const TextStyle(color: KidsTheme.goldLight, fontWeight: FontWeight.w900, fontSize: 15)),
                    Text(w.meaning, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          if (w.etymology != null && w.etymology!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '💡 Kökeni: ${w.etymology}',
                style: const TextStyle(color: KidsTheme.textMuted, fontSize: 11, fontStyle: FontStyle.italic),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            'Örnek: "${w.sampleSentence}"',
            style: const TextStyle(color: Colors.white60, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildVaultBalanceCard() {
    return Container(
      decoration: BoxDecoration(
        color: KidsTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: KidsTheme.gold.withOpacity(0.2)),
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
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                // Harcanabilir Cüzdan
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
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
                            Text('🪙', style: TextStyle(fontSize: 16)),
                            SizedBox(width: 6),
                            Text(
                              'Cüzdan',
                              style: TextStyle(
                                fontSize: 12,
                                color: KidsTheme.textMuted,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${widget.student.pointsBalance}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: KidsTheme.goldLight,
                          ),
                        ),
                        const Text(
                          'Harcanabilir Altın',
                          style: TextStyle(fontSize: 10, color: KidsTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Birikim Kasası
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          KidsTheme.primary.withOpacity(0.35),
                          KidsTheme.purpleAccent.withOpacity(0.25),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: KidsTheme.primary.withOpacity(0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Text('🏺', style: TextStyle(fontSize: 16)),
                            SizedBox(width: 6),
                            Text(
                              'Altın Kasa',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${widget.student.piggyBankBalance}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const Text(
                          'Pazar +%20 Kârda',
                          style: TextStyle(fontSize: 10, color: KidsTheme.emerald, fontWeight: FontWeight.bold),
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
                    label: const Text('Kasaya At', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openTransferModal(false),
                    icon: const Text('📤', style: TextStyle(fontSize: 16)),
                    label: const Text('Kasadan Çek', style: TextStyle(color: KidsTheme.textMuted, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.white.withOpacity(0.1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
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

  Widget _buildLuckyWheelCard() {
    final bool hasTasksToday = _todayCompletedTasks > 0;
    final bool hasSpinAvailable = widget.student.wheelSpinsAvailable > 0;
    final bool canSpin = hasTasksToday && hasSpinAvailable;

    String descText = 'Her gün 1 defa çarkı çevirerek 20-75 ekstra puan kazan!';
    String btnText = 'Çevir 🎡';
    Color btnColor = KidsTheme.gold;
    Color btnTextColor = Colors.black;

    if (!hasTasksToday) {
      descText = '🔒 Günlük Kilit: Çarkı açabilmek için bugün en az 1 görev tamamlamalısın!';
      btnText = 'Görev Yap 🔒';
      btnColor = Colors.white12;
      btnTextColor = Colors.white38;
    } else if (!hasSpinAvailable) {
      descText = '✅ Günlük Hakkın Bitti: Bugünün çarkını çevirdin. Yarın yeni hakkın açılacak!';
      btnText = 'Yarın Gel 🌙';
      btnColor = Colors.white12;
      btnTextColor = Colors.white38;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            canSpin ? const Color(0xFF312E81) : const Color(0xFF1E293B),
            canSpin ? const Color(0xFF1E1B4B) : const Color(0xFF0F172A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: canSpin ? KidsTheme.primaryLight.withOpacity(0.5) : Colors.white12,
        ),
      ),
      child: Row(
        children: [
          Transform.rotate(
            angle: _wheelRotationAngle,
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: canSpin
                    ? const RadialGradient(colors: [KidsTheme.goldLight, Colors.deepOrange])
                    : const RadialGradient(colors: [Colors.white24, Colors.white10]),
                boxShadow: canSpin
                    ? [BoxShadow(color: KidsTheme.gold.withOpacity(0.4), blurRadius: 10)]
                    : null,
              ),
              child: const Center(
                child: Text('🎡', style: TextStyle(fontSize: 30)),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Günün Şans Çarkı',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    if (!canSpin) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.lock_rounded, size: 14, color: Colors.amber.shade200),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  descText,
                  style: TextStyle(
                    color: canSpin ? Colors.white.withOpacity(0.8) : KidsTheme.goldLight.withOpacity(0.8),
                    fontSize: 11,
                    fontWeight: canSpin ? FontWeight.normal : FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: (_isSpinning || !canSpin) ? null : _handleSpinWheel,
            style: ElevatedButton.styleFrom(
              backgroundColor: btnColor,
              foregroundColor: btnTextColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            child: _isSpinning
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                : Text(btnText, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildSiblingGiftCard() {
    return InkWell(
      onTap: () => GiftPointsModal.show(context, widget.student, onSuccess: widget.onRefreshUser),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: KidsTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.pinkAccent.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.pinkAccent.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Text('💛', style: TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kardeşine Puan Gönder (Altın Kalp)',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                  Text(
                    'Kardeşine moral ve dayanışma puanı hediye et',
                    style: TextStyle(color: KidsTheme.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white38, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildMarketHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Text('🎁', style: TextStyle(fontSize: 20)),
                SizedBox(width: 8),
                Text(
                  'Ödül Pazarı',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
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
                '${_filteredRewards.length} Ödül',
                style: const TextStyle(fontSize: 11, color: KidsTheme.textMuted, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildTierFilter('all', '🌟 Tümü'),
              _buildTierFilter('micro', '⚡ Hızlı Ödüller'),
              _buildTierFilter('medium', '🍨 Orta Ödüller'),
              _buildTierFilter('large', '🎬 Büyük Ödüller'),
              _buildTierFilter('parent_challenge', '👑 Efsanevi'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTierFilter(String tier, String label) {
    final isSelected = _selectedTier == tier;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _selectedTier = tier),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? KidsTheme.gold : KidsTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? KidsTheme.goldLight : Colors.white12,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.black : KidsTheme.textSecondary,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRewardCard(RewardModel reward) {
    final bool canAfford = widget.student.pointsBalance >= reward.pointsCost;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: KidsTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: canAfford ? KidsTheme.gold.withOpacity(0.3) : Colors.white.withOpacity(0.06),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: canAfford
                  ? KidsTheme.gold.withOpacity(0.15)
                  : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                _getRewardIcon(reward.iconName),
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reward.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                if (reward.description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    reward.description,
                    style: const TextStyle(
                      fontSize: 11,
                      color: KidsTheme.textMuted,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '${reward.pointsCost} 🪙',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: KidsTheme.goldLight,
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
            onPressed: () => _confirmRedeem(reward),
            style: ElevatedButton.styleFrom(
              backgroundColor: canAfford ? KidsTheme.emerald : Colors.white12,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            child: Text(
              canAfford ? 'Talep Et' : 'Eksik',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: canAfford ? Colors.white : Colors.white38,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyMarket() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: KidsTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: const Column(
        children: [
          Text('🏺', style: TextStyle(fontSize: 40)),
          SizedBox(height: 8),
          Text(
            'Bu kategoride ödül bulunamadı',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Diğer kategorilere göz atabilirsin.',
            textAlign: TextAlign.center,
            style: TextStyle(color: KidsTheme.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  String _getRewardIcon(String icon) {
    switch (icon.toLowerCase()) {
      case 'game':
      case 'gamepad':
      case 'gamepad2':
        return '🎮';
      case 'sparkles':
        return '✨';
      case 'book':
        return '📚';
      case 'pizza':
        return '🍕';
      case 'tv':
      case 'film':
      case 'movie':
        return '🎬';
      case 'award':
        return '🧱';
      case 'star':
        return '⭐';
      default:
        return '🎁';
    }
  }
}
