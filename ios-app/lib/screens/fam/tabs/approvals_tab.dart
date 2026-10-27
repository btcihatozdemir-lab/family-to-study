import 'package:flutter/material.dart';
import '../../../models/submission_model.dart';
import '../../../models/redemption_model.dart';
import '../../../services/supabase_service.dart';
import '../../../theme/fam_theme.dart';

class ApprovalsTab extends StatefulWidget {
  final String familyId;
  final VoidCallback onRefreshAll;

  const ApprovalsTab({
    super.key,
    required this.familyId,
    required this.onRefreshAll,
  });

  @override
  State<ApprovalsTab> createState() => _ApprovalsTabState();
}

class _ApprovalsTabState extends State<ApprovalsTab> {
  List<SubmissionModel> _submissions = [];
  List<RedemptionModel> _redemptions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadApprovals();
  }

  Future<void> _loadApprovals() async {
    setState(() => _isLoading = true);
    final subs = await SupabaseService.fetchPendingSubmissions(widget.familyId);
    final reds = await SupabaseService.fetchPendingRedemptions(widget.familyId);
    if (mounted) {
      setState(() {
        _submissions = subs;
        _redemptions = reds;
        _isLoading = false;
      });
    }
  }

  void _showPhotoDialog(String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  color: FamTheme.surface,
                  padding: const EdgeInsets.all(32),
                  child: const Text('Fotoğraf yüklenemedi', style: TextStyle(color: Colors.white)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(backgroundColor: FamTheme.surfaceElevated),
              child: const Text('Kapat', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalCount = _submissions.length + _redemptions.length;

    return RefreshIndicator(
      onRefresh: () async {
        await _loadApprovals();
        widget.onRefreshAll();
      },
      color: FamTheme.primaryLight,
      backgroundColor: FamTheme.surfaceElevated,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // Header Summary
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: FamTheme.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: totalCount > 0 ? FamTheme.gold.withOpacity(0.3) : Colors.white10,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: totalCount > 0
                        ? FamTheme.gold.withOpacity(0.15)
                        : Colors.white.withOpacity(0.06),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    totalCount > 0 ? '🔔' : '✨',
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        totalCount > 0
                            ? '$totalCount Onay Bekleyen İşlem Var'
                            : 'Tüm Görevler ve Talepler Güncel',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        totalCount > 0
                            ? 'Öğrencilerinizin gönderdiği görevleri inceleyip altın puanlarını onaylayın.'
                            : 'Onay bekleyen yeni bir görev veya ödül talebi bulunmuyor.',
                        style: const TextStyle(color: FamTheme.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section 1: Görev Teslimatları
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Text('📸', style: TextStyle(fontSize: 18)),
                  SizedBox(width: 8),
                  Text(
                    'Görev Teslimatları',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: FamTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_submissions.length}',
                  style: const TextStyle(color: FamTheme.primaryLight, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_submissions.isEmpty)
            _buildEmptyState('Bekleyen görev teslimatı yok')
          else
            ..._submissions.map((sub) => _buildSubmissionCard(sub)),

          const SizedBox(height: 24),

          // Section 2: Ödül Talepleri
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Text('🎁', style: TextStyle(fontSize: 18)),
                  SizedBox(width: 8),
                  Text(
                    'Ödül Pazarı Talepleri',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: FamTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_redemptions.length}',
                  style: const TextStyle(color: FamTheme.gold, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_redemptions.isEmpty)
            _buildEmptyState('Bekleyen ödül talebi yok')
          else
            ..._redemptions.map((red) => _buildRedemptionCard(red)),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String msg) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: FamTheme.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Center(
        child: Text(
          msg,
          style: const TextStyle(color: FamTheme.textMuted, fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildSubmissionCard(SubmissionModel sub) {
    final hasPhoto = sub.photoUrls.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: FamTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: FamTheme.primary.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Text('📝', style: TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sub.taskTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Öğrenci: ${sub.studentName}',
                      style: const TextStyle(color: FamTheme.primaryLight, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: FamTheme.gold.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: FamTheme.gold.withOpacity(0.3)),
                ),
                child: Text(
                  '+${sub.points} 🪙',
                  style: const TextStyle(
                    color: FamTheme.gold,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),

          if (hasPhoto) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => _showPhotoDialog(sub.photoUrls.first),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Image.network(
                      sub.photoUrls.first,
                      height: 140,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 60,
                        color: Colors.white10,
                        child: const Center(
                          child: Text('Fotoğraf önizleme', style: TextStyle(color: FamTheme.textMuted)),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.zoom_in, color: Colors.white, size: 16),
                          SizedBox(width: 4),
                          Text(
                            'Fotoğraf Kanıtını İncele',
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await SupabaseService.reviewSubmission(
                      submissionId: sub.id,
                      studentId: sub.studentId,
                      points: sub.points,
                      approve: true,
                    );
                    _loadApprovals();
                    widget.onRefreshAll();
                  },
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: Text('Onayla (+${sub.points} 🪙)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FamTheme.emerald,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: () async {
                  await SupabaseService.reviewSubmission(
                    submissionId: sub.id,
                    studentId: sub.studentId,
                    points: sub.points,
                    approve: false,
                  );
                  _loadApprovals();
                  widget.onRefreshAll();
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: FamTheme.rose),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Reddet', style: TextStyle(color: FamTheme.rose, fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRedemptionCard(RedemptionModel red) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: FamTheme.cardDecoration(),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: FamTheme.gold.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Text('🎁', style: TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  red.rewardTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Öğrenci: ${red.studentName} • ${red.pointsSpent} 🪙 Harcandı',
                  style: const TextStyle(color: FamTheme.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              await SupabaseService.reviewRedemption(
                redemptionId: red.id,
                approve: true,
              );
              _loadApprovals();
              widget.onRefreshAll();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: FamTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            child: const Text('Verildi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
