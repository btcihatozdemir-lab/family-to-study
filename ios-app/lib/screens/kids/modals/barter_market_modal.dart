import 'package:flutter/material.dart';
import '../../../theme/kids_theme.dart';
import '../../../models/user_model.dart';
import '../../../models/barter_model.dart';
import '../../../services/supabase_service.dart';

class BarterMarketModal extends StatefulWidget {
  final UserModel student;
  final VoidCallback? onPointsChanged;

  const BarterMarketModal({
    super.key,
    required this.student,
    this.onPointsChanged,
  });

  static void show(BuildContext context, UserModel student, {VoidCallback? onPointsChanged}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BarterMarketModal(student: student, onPointsChanged: onPointsChanged),
    );
  }

  @override
  State<BarterMarketModal> createState() => _BarterMarketModalState();
}

class _BarterMarketModalState extends State<BarterMarketModal> {
  List<BarterItemModel> _items = [];
  bool _isLoading = true;
  int _currentPoints = 0;

  @override
  void initState() {
    super.initState();
    _currentPoints = widget.student.pointsBalance;
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    final list = await SupabaseService.fetchBarterItems(widget.student.familyId);
    if (mounted) {
      setState(() {
        _items = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleRedeem(BarterItemModel item) async {
    if (_currentPoints < item.costPoints) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: KidsTheme.rose,
          content: Text('Yetersiz puan! Bu takas için ${item.costPoints} puan gerekiyor. (Mevcut: $_currentPoints)'),
        ),
      );
      return;
    }

    final res = await SupabaseService.redeemBarterItem(
      familyId: widget.student.familyId,
      studentId: widget.student.id,
      itemId: item.id,
    );

    if (mounted) {
      if (res['success'] == true) {
        setState(() {
          _currentPoints = (res['remaining_points'] as num?)?.toInt() ?? (_currentPoints - item.costPoints);
        });
        widget.onPointsChanged?.call();

        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: KidsTheme.surfaceElevated,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.handshake_rounded, color: KidsTheme.emerald),
                SizedBox(width: 8),
                Text('Takas Talebi Gönderildi! 🎉', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Text(
              res['message'] ?? '${item.title} talebiniz anne/babanıza iletildi.',
              style: const TextStyle(color: KidsTheme.textMuted, fontSize: 13, height: 1.4),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(backgroundColor: KidsTheme.emerald),
                child: const Text('Harika', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: KidsTheme.rose, content: Text(res['message'] ?? 'İşlem gerçekleştirilemedi.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: KidsTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Text('🤝', style: TextStyle(fontSize: 26)),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Anlamlı Takas Pazarı',
                        style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
                      ),
                      Text(
                        'Puanlarını ev içi haklara ve aile içi ödüllere dönüştür!',
                        style: TextStyle(color: KidsTheme.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: KidsTheme.gold.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: KidsTheme.gold.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      const Text('🪙', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 4),
                      Text(
                        '$_currentPoints',
                        style: const TextStyle(color: KidsTheme.gold, fontWeight: FontWeight.w900, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: KidsTheme.primary))
                : _items.isEmpty
                    ? const Center(child: Text('Takas ödülü bulunamadı.', style: TextStyle(color: KidsTheme.textMuted)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _items.length,
                        itemBuilder: (ctx, i) {
                          final item = _items[i];
                          return _buildBarterCard(item);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarterCard(BarterItemModel item) {
    final canAfford = _currentPoints >= item.costPoints;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KidsTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: canAfford ? KidsTheme.primary.withOpacity(0.3) : Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: KidsTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(child: Text(item.icon, style: const TextStyle(fontSize: 24))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                if ((item.description ?? '').isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(item.description!, style: const TextStyle(color: KidsTheme.textMuted, fontSize: 11)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => _handleRedeem(item),
            style: ElevatedButton.styleFrom(
              backgroundColor: canAfford ? KidsTheme.primary : Colors.white12,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🪙', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 4),
                Text(
                  '${item.costPoints}',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
