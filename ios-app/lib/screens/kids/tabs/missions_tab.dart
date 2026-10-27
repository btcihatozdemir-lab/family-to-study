import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../theme/kids_theme.dart';
import '../../../models/task_model.dart';
import '../../../models/user_model.dart';
import '../../../services/supabase_service.dart';

class MissionsTab extends StatefulWidget {
  final UserModel student;
  final VoidCallback? onRefreshUser;

  const MissionsTab({
    super.key,
    required this.student,
    this.onRefreshUser,
  });

  @override
  State<MissionsTab> createState() => _MissionsTabState();
}

class _MissionsTabState extends State<MissionsTab> {
  List<TaskModel> _tasks = [];
  bool _isLoading = true;
  String _selectedCategory = 'all';
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadTasks();

    // Canlı görev güncelleme dinleyicisi
    SupabaseService.tasksUpdateController.stream.listen((_) {
      if (mounted) _loadTasks();
    });
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    final tasks = await SupabaseService.fetchTasks(widget.student.familyId, widget.student.id);
    if (mounted) {
      setState(() {
        _tasks = tasks;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleCompleteTask(TaskModel task) async {
    if (task.requiresPhoto) {
      // Fotoğraf Kanıtı Al
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 75,
      );
      if (photo == null) return;

      // Supabase Storage'a yükle
      final bytes = await photo.readAsBytes();
      final fileName = 'proof_${widget.student.id}_${task.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      try {
        await SupabaseService.client.storage
            .from('proofs')
            .uploadBinary(fileName, bytes);
        final publicUrl = SupabaseService.client.storage
            .from('proofs')
            .getPublicUrl(fileName);

        final ok = await SupabaseService.submitTask(
          taskId: task.id,
          studentId: widget.student.id,
          familyId: widget.student.familyId,
          photoUrl: publicUrl,
        );

        if (ok && mounted) {
          _showFeedbackDialog('📸 Fotoğraf yüklendi! Ebeveyn onayına gönderildi.');
          _loadTasks();
          widget.onRefreshUser?.call();
        }
      } catch (e) {
        print('[Storage] Fotoğraf yükleme hatası: $e');
        // Offline / fallback submit
        await SupabaseService.submitTask(
          taskId: task.id,
          studentId: widget.student.id,
          familyId: widget.student.familyId,
        );
        _loadTasks();
        widget.onRefreshUser?.call();
      }
    } else {
      // Doğrudan tamamla
      final ok = await SupabaseService.submitTask(
        taskId: task.id,
        studentId: widget.student.id,
        familyId: widget.student.familyId,
      );
      if (ok && mounted) {
        _showFeedbackDialog('🌟 Harika! Görevin ebeveyn onayına gönderildi.');
        _loadTasks();
        widget.onRefreshUser?.call();
      }
    }
  }

  Future<void> _handleClaimRace(TaskModel task) async {
    final ok = await SupabaseService.claimRaceTask(task.id, widget.student.id);
    if (ok && mounted) {
      _showFeedbackDialog('⚡ Tebrikler! Yarış görevini ilk sen kaptın!');
      _loadTasks();
      widget.onRefreshUser?.call();
    }
  }

  void _showFeedbackDialog(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: KidsTheme.emerald,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  List<TaskModel> get _filteredTasks {
    if (_selectedCategory == 'all') return _tasks;
    return _tasks.where((t) => t.category == _selectedCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: KidsTheme.primary),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTasks,
      color: KidsTheme.primary,
      backgroundColor: KidsTheme.surface,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        children: [
          // Kategori Seçici Filtre Barı
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('all', '🌟 Tümü'),
                _buildFilterChip('study', '📚 Ders & Ödev'),
                _buildFilterChip('routine_evening', '🎒 Rutin & Çanta'),
                _buildFilterChip('health_sport', '🏃 Spor & Sağlık'),
                _buildFilterChip('kindness_help', '🤝 Ev & Nezaket'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // İlk Kapar Yarış Görevleri (Varsa En Üste Sabitlenir)
          ..._tasks.where((t) => t.isFirstComeRace && t.claimedBy == null).map(
                (raceTask) => _buildRaceCard(raceTask),
              ),

          // Görev Listesi
          if (_filteredTasks.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: KidsTheme.cardDecoration(),
              child: Column(
                children: [
                  const Text('🎉', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  const Text(
                    'Bugünün Tüm Görevleri Bitti!',
                    style: TextStyle(
                      color: KidsTheme.textWhite,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Dinlenebilir veya serbest oyun zamanının tadını çıkarabilirsin.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: KidsTheme.textMuted, fontSize: 13),
                  ),
                ],
              ),
            )
          else
            ..._filteredTasks.map((task) => _buildTaskCard(task)),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String catId, String label) {
    final isSelected = _selectedCategory == catId;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _selectedCategory = catId),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? KidsTheme.primary : KidsTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? KidsTheme.primaryLight : KidsTheme.surfaceElevated,
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : KidsTheme.textSecondary,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRaceCard(TaskModel task) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF831843), Color(0xFF4C0519)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: KidsTheme.rose, width: 2),
        boxShadow: [
          BoxShadow(
            color: KidsTheme.rose.withOpacity(0.3),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: KidsTheme.rose.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Text('⚡', style: TextStyle(fontSize: 14)),
                    SizedBox(width: 4),
                    Text(
                      'İLK KAPAR GÖREV YARIŞI!',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: KidsTheme.gold.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '+${task.points} Puan',
                  style: const TextStyle(
                    color: KidsTheme.goldLight,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            task.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (task.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              task.description,
              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: () => _handleClaimRace(task),
              style: ElevatedButton.styleFrom(
                backgroundColor: KidsTheme.rose,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.flash_on_rounded, size: 20),
                  SizedBox(width: 6),
                  Text('Görevi İlk Ben Kapıyorum!', style: TextStyle(fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(TaskModel task) {
    Color statusColor = KidsTheme.surfaceElevated;
    String statusLabel = 'Tamamla';
    IconData statusIcon = Icons.check_circle_outline_rounded;

    if (task.isCompleted) {
      statusColor = KidsTheme.emerald;
      statusLabel = 'Onaylandı';
      statusIcon = Icons.check_circle_rounded;
    } else if (task.isPending) {
      statusColor = KidsTheme.gold;
      statusLabel = 'Veli Onayı Bekliyor';
      statusIcon = Icons.hourglass_top_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: KidsTheme.cardDecoration(
        borderColor: task.isCompleted
            ? KidsTheme.emerald.withOpacity(0.5)
            : task.isPending
                ? KidsTheme.gold.withOpacity(0.5)
                : null,
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Puan & Kategori Rozeti
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: task.isCompleted ? KidsTheme.cardGradient : KidsTheme.heroGradient,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: task.isCompleted ? KidsTheme.emerald : KidsTheme.primary.withOpacity(0.4),
              ),
            ),
            child: Center(
              child: Text(
                '+${task.points}',
                style: TextStyle(
                  color: task.isCompleted ? KidsTheme.emerald : KidsTheme.gold,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Başlık & Açıklama
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    color: task.isCompleted ? KidsTheme.textMuted : KidsTheme.textWhite,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (task.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    task.description,
                    style: TextStyle(
                      color: KidsTheme.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 10),

                // Aksiyon Butonu
                if (!task.isCompleted && !task.isPending)
                  GestureDetector(
                    onTap: () => _handleCompleteTask(task),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        gradient: KidsTheme.goldGradient,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: KidsTheme.gold.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            task.requiresPhoto
                                ? Icons.camera_alt_rounded
                                : Icons.check_circle_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            task.requiresPhoto ? 'Fotoğraf Çek & Bitir' : 'Görevi Yaptım',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, color: statusColor, size: 14),
                        const SizedBox(width: 5),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
