import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../theme/kids_theme.dart';
import '../../../models/task_model.dart';
import '../../../models/user_model.dart';
import '../../../services/supabase_service.dart';
import '../../../services/tts_service.dart';
import '../widgets/active_break_widget.dart';
import '../modals/appeal_modal.dart';
import '../modals/companion_modal.dart';
import '../modals/grace_period_modal.dart';
import '../modals/success_album_modal.dart';
import '../modals/weekly_interview_modal.dart';
import '../modals/propose_task_modal.dart';

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
  String _currentMood = 'happy';
  final ImagePicker _picker = ImagePicker();

  final List<Map<String, String>> _moods = [
    {'id': 'happy', 'emoji': '😊', 'label': 'Mutlu'},
    {'id': 'excited', 'emoji': '🤩', 'label': 'Enerjik'},
    {'id': 'tired', 'emoji': '🥱', 'label': 'Yorgun'},
    {'id': 'angry', 'emoji': '😤', 'label': 'Stresli'},
  ];

  @override
  void initState() {
    super.initState();
    _loadTasks();

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

  Future<void> _handleMoodSelect(String moodId, String emoji, String label) async {
    setState(() => _currentMood = moodId);
    final ok = await SupabaseService.updateStudentMood(widget.student.id, moodId);
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$emoji Duygu durumun "$label" olarak güncellendi! Anne & Babana iletildi.'),
          backgroundColor: KidsTheme.emerald,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
    }
  }

  Future<void> _handleCompleteTask(TaskModel task) async {
    if (task.requiresPhoto) {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 75,
      );
      if (photo == null) return;

      final bytes = await photo.readAsBytes();
      final fileName = 'proof_${widget.student.id}_${task.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      try {
        await SupabaseService.client.storage
            .from('proofs')
            .uploadBinary(fileName, bytes);
        final publicUrl = SupabaseService.client.storage
            .from('proofs')
            .getPublicUrl(fileName);

        await SupabaseService.submitTask(
          taskId: task.id,
          studentId: widget.student.id,
          familyId: widget.student.familyId,
          photoUrl: publicUrl,
        );
      } catch (e) {
        // Fallback directly
        await SupabaseService.submitTask(
          taskId: task.id,
          studentId: widget.student.id,
          familyId: widget.student.familyId,
        );
      }
    } else {
      // Doğrudan tamamlanan görevler: hemen onaylanır ve puan kazanılır!
      setState(() {
        final idx = _tasks.indexWhere((t) => t.id == task.id);
        if (idx != -1) {
          _tasks[idx] = task.copyWith(status: 'approved');
        }
      });

      await SupabaseService.submitTask(
        taskId: task.id,
        studentId: widget.student.id,
        familyId: widget.student.familyId,
        points: task.points,
        autoApprove: true,
      );
    }

    if (mounted) {
      _showFeedbackDialog('🌟 Harika! Görevin tamamlandı ve +${task.points} Puan kazandın! 🎉');
      _loadTasks();
      widget.onRefreshUser?.call();
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
    if (_isLoading && _tasks.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: KidsTheme.primary),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTasks,
      color: KidsTheme.primary,
      backgroundColor: KidsTheme.surface,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // 1. DUYGU DURUMU SEÇİCİ (MOOD SELECTOR)
          _buildMoodSelector(),
          const SizedBox(height: 12),

          // 2. ODAKLANMA UÇUŞU & DERS KRONOMETRESİ BAŞLATICI
          _buildFocusFlightLauncher(),

          // 3. BİLİŞSEL ENERJİ MOLASI & RUŞETİ (SU İÇ, CAMI AÇ, ESNE, YÜRÜ)
          ActiveBreakWidget(
            student: widget.student,
            onRefreshUser: () => widget.onRefreshUser?.call(),
          ),
          const SizedBox(height: 12),

          // 4. HIZLI ERİŞİM MERKEZİ (MODALLAR: İTİRAZ, YOLDAŞ, MERHAMET, ALBÜM, RÖPORTAJ, GÖREV ÖNER)
          _buildQuickActionHub(),
          const SizedBox(height: 16),

          // 5. KATEGORİ FİLTRE BARIK
          _buildCategoryFilters(),
          const SizedBox(height: 14),

          // 6. İLK KAPAR GÖREV YARIŞLARI
          ..._tasks.where((t) => t.isFirstComeRace && t.claimedBy == null).map(
                (raceTask) => _buildRaceCard(raceTask),
              ),

          // 5. GÖREV LİSTESİ
          if (_filteredTasks.isEmpty)
            _buildEmptyState()
          else
            ..._filteredTasks.map((task) => _buildTaskCard(task)),
        ],
      ),
    );
  }

  Widget _buildMoodSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: KidsTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          const Text(
            'Bugün Nasıl Hissediyorsun?',
            style: TextStyle(
              color: KidsTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          ..._moods.map((m) {
            final isSelected = _currentMood == m['id'];
            return GestureDetector(
              onTap: () => _handleMoodSelect(m['id']!, m['emoji']!, m['label']!),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isSelected ? KidsTheme.primary.withOpacity(0.3) : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? KidsTheme.goldLight : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Text(
                  m['emoji']!,
                  style: TextStyle(fontSize: isSelected ? 22 : 18),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFocusFlightLauncher() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1B4B), Color(0xFF312E81), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.indigoAccent.withOpacity(0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🚀', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ODAKLANMA UÇUŞU & DERS KRONOMETRESİ',
                      style: TextStyle(
                        color: Colors.indigoAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                    Text(
                      'Kalkan koruması ve ders sayacını başlat',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    TTSService.speak('Dikkat dikkat! ${widget.student.name} için 40 dakikalık odaklanma uçuşu başlıyor, başarılar kaptan!');
                    await SupabaseService.setStudentState(
                      studentId: widget.student.id,
                      newState: 'STUDY_TIME',
                      durationMinutes: 40,
                    );
                    widget.onRefreshUser?.call();
                  },
                  icon: const Icon(Icons.flight_takeoff_rounded, color: Colors.white, size: 16),
                  label: const Text('40 Dk Ders 🚀', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: KidsTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    TTSService.speak('Dikkat dikkat! 25 dakikalık Pomodoro odaklanması başlıyor!');
                    await SupabaseService.setStudentState(
                      studentId: widget.student.id,
                      newState: 'STUDY_TIME',
                      durationMinutes: 25,
                    );
                    widget.onRefreshUser?.call();
                  },
                  icon: const Icon(Icons.timer_rounded, color: Colors.white, size: 16),
                  label: const Text('25 Dk Pomodoro ⏱️', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              OutlinedButton(
                onPressed: () async {
                  TTSService.speak('Teneffüs zili çaldı! 10 dakika mola başladı.');
                  await SupabaseService.setStudentState(
                    studentId: widget.student.id,
                    newState: 'BREAK_TIME',
                    durationMinutes: 10,
                  );
                  widget.onRefreshUser?.call();
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.emeraldAccent.withOpacity(0.5)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('10 Dk Mola 🔔', style: TextStyle(color: Colors.emeraldAccent, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionHub() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildActionPill(
            icon: '💡',
            label: 'Görev Öner',
            color: KidsTheme.primary,
            onTap: () => ProposeTaskModal.show(context, widget.student, onSuccess: _loadTasks),
          ),
          _buildActionPill(
            icon: '🐉',
            label: 'Yoldaşım',
            color: const Color(0xFFF59E0B),
            onTap: () => CompanionModal.show(context, widget.student),
          ),
          _buildActionPill(
            icon: '⚖️',
            label: 'Adalet Divanı',
            color: KidsTheme.rose,
            onTap: () => AppealModal.show(context, widget.student, onSuccess: widget.onRefreshUser),
          ),
          _buildActionPill(
            icon: '🕊️',
            label: 'Merhamet (+5 Dk)',
            color: KidsTheme.cyan,
            onTap: () => GracePeriodModal.show(context, widget.student),
          ),
          _buildActionPill(
            icon: '🏆',
            label: 'Kupalarım',
            color: KidsTheme.gold,
            onTap: () => SuccessAlbumModal.show(context, widget.student),
          ),
          _buildActionPill(
            icon: '🎙️',
            label: 'Pazar Röportajı',
            color: KidsTheme.purpleAccent,
            onTap: () => WeeklyInterviewModal.show(context, widget.student, onSuccess: widget.onRefreshUser),
          ),
        ],
      ),
    );
  }

  Widget _buildActionPill({
    required String icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.35)),
          ),
          child: Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip('all', '🌟 Tümü'),
          _buildFilterChip('study', '📚 Ders & Ödev'),
          _buildFilterChip('routine_evening', '🎒 Rutin & Çanta'),
          _buildFilterChip('health_sport', '🏃 Spor & Sağlık'),
          _buildFilterChip('kindness_help', '🤝 Ev & Nezaket'),
          _buildFilterChip('flash_quest', '⚡ Flaş Görevler'),
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
                  Text('Görevi İlk Ben Kapıyorum! ⚡', style: TextStyle(fontWeight: FontWeight.w900)),
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
      statusLabel = 'Onaylandı ✅';
      statusIcon = Icons.check_circle_rounded;
    } else if (task.isPending) {
      statusColor = KidsTheme.gold;
      statusLabel = 'Veli Onayı Bekliyor ⏳';
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
                    style: const TextStyle(
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
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                            task.requiresPhoto ? 'Fotoğraf Çek & Bitir' : 'Görevi Yaptım ✅',
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
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

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: KidsTheme.cardDecoration(),
      child: const Column(
        children: [
          Text('🎉', style: TextStyle(fontSize: 48)),
          SizedBox(height: 12),
          Text(
            'Bugünün Tüm Görevleri Bitti!',
            style: TextStyle(
              color: KidsTheme.textWhite,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Dinlenebilir veya serbest oyun zamanının tadını çıkarabilirsin.',
            textAlign: TextAlign.center,
            style: TextStyle(color: KidsTheme.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
