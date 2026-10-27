import 'package:flutter/material.dart';
import '../../../theme/kids_theme.dart';
import '../../../models/schedule_model.dart';
import '../../../models/user_model.dart';
import '../../../services/supabase_service.dart';
import '../../../services/tts_service.dart';

class ScheduleBagTab extends StatefulWidget {
  final UserModel student;
  const ScheduleBagTab({super.key, required this.student});

  @override
  State<ScheduleBagTab> createState() => _ScheduleBagTabState();
}

class _ScheduleBagTabState extends State<ScheduleBagTab> {
  int _selectedDay = 1;
  DayScheduleModel? _daySchedule;
  bool _isLoading = true;
  final Set<String> _packedItems = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final currentHour = now.hour;

    // Saat 15:00'ten sonra otomatik yarının dersini aç
    if (currentHour >= 15) {
      _selectedDay = (now.weekday % 7) + 1;
    } else {
      _selectedDay = now.weekday;
    }

    _loadDaySchedule();
  }

  Future<void> _loadDaySchedule() async {
    setState(() => _isLoading = true);
    final sched = await SupabaseService.fetchDaySchedule(
      userId: widget.student.id,
      dayOfWeek: _selectedDay,
    );
    if (mounted) {
      setState(() {
        _daySchedule = sched;
        _isLoading = false;
      });
    }
  }

  void _announceSchedule() {
    if (_daySchedule == null) return;

    final lessons = _daySchedule!.lessons.map((l) => l.name).where((n) => n.isNotEmpty).toList();
    final materials = _daySchedule!.extraMaterials;

    TTSService.announceTomorrowBag(
      studentName: widget.student.name,
      dayName: DayScheduleModel.getDayName(_selectedDay),
      lessons: lessons,
      materials: materials,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🎒 Sesli Çanta Asistanı seslendiriliyor...'),
        backgroundColor: KidsTheme.cyan,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _togglePacked(String item) {
    setState(() {
      if (_packedItems.contains(item)) {
        _packedItems.remove(item);
      } else {
        _packedItems.add(item);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final tomorrowDay = (now.weekday % 7) + 1;
    final isTomorrow = _selectedDay == tomorrowDay;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // Gün Seçici Haplar (Pzt - Cuma - Hafta Sonu)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(7, (idx) {
              final dayIndex = idx + 1;
              final isSelected = _selectedDay == dayIndex;
              final dayName = DayScheduleModel.getDayName(dayIndex);
              final isTargetTomorrow = dayIndex == tomorrowDay;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () {
                    setState(() => _selectedDay = dayIndex);
                    _loadDaySchedule();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? KidsTheme.cyan : KidsTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? Colors.cyanAccent
                            : isTargetTomorrow
                                ? KidsTheme.gold
                                : KidsTheme.surfaceElevated,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        if (isTargetTomorrow) ...[
                          const Text('⭐', style: TextStyle(fontSize: 12)),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          dayName,
                          style: TextStyle(
                            color: isSelected ? KidsTheme.surfaceDarker : KidsTheme.textWhite,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 16),

        // Sesli Çanta Asistanı Aksiyon Kartı
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F766E), Color(0xFF115E59)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.tealAccent.withOpacity(0.4), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.teal.withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('🎒', style: TextStyle(fontSize: 26)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isTomorrow ? 'YARININ ÇANTASINI HAZIRLA' : 'DERS VE ÇANTA ASİSTANI',
                          style: const TextStyle(
                            color: Colors.tealAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                          ),
                        ),
                        Text(
                          '${DayScheduleModel.getDayName(_selectedDay)} Programı',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Çantanı hazırlarken kitap ve defterlerini çantana attıkça üzerine dokunup işaretle!',
                style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: _announceSchedule,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.tealAccent,
                    foregroundColor: const Color(0xFF0F172A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.volume_up_rounded, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Çantamı Hazırlıyorum (Sesli Oku)',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        if (_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(color: KidsTheme.cyan),
            ),
          )
        else if (_daySchedule == null || _daySchedule!.lessons.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: KidsTheme.cardDecoration(),
            child: Column(
              children: [
                const Text('🏖️', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                Text(
                  '${DayScheduleModel.getDayName(_selectedDay)} Günü Ders Yok',
                  style: const TextStyle(
                    color: KidsTheme.textWhite,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Hafta sonu veya serbest tatil! Dinlenebilir ve kitap okuyabilirsin.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: KidsTheme.textMuted, fontSize: 13),
                ),
              ],
            ),
          )
        else ...[
          // Özel Malzemeler Kontrol Listesi
          if (_daySchedule!.extraMaterials.isNotEmpty) ...[
            const Text(
              '🎒 Çantaya Konulacak Özel Malzemeler:',
              style: TextStyle(
                color: KidsTheme.goldLight,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            ..._daySchedule!.extraMaterials.map((mat) {
              final isPacked = _packedItems.contains(mat);
              return GestureDetector(
                onTap: () => _togglePacked(mat),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: KidsTheme.cardDecoration(
                    borderColor: isPacked ? KidsTheme.emerald : KidsTheme.gold.withOpacity(0.3),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isPacked ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        color: isPacked ? KidsTheme.emerald : KidsTheme.gold,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          mat,
                          style: TextStyle(
                            color: isPacked ? KidsTheme.emerald : KidsTheme.textWhite,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            decoration: isPacked ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 14),
          ],

          // 1'den 8'e Ders Çizelgesi ve Kitap/Defter Kontrol Listesi
          const Text(
            '📚 Günlük Ders Programı & Çanta Kontrol Listesi:',
            style: TextStyle(
              color: KidsTheme.textWhite,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          ..._daySchedule!.lessons.map((lesson) {
            final bookKey = 'Ders Kitabı: ${lesson.name}';
            final isPacked = _packedItems.contains(bookKey);

            return GestureDetector(
              onTap: () => _togglePacked(bookKey),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: KidsTheme.cardDecoration(
                  borderColor: isPacked ? KidsTheme.emerald.withOpacity(0.6) : KidsTheme.cyan.withOpacity(0.25),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isPacked ? KidsTheme.emerald.withOpacity(0.2) : KidsTheme.cyan.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          '${lesson.period}',
                          style: TextStyle(
                            color: isPacked ? KidsTheme.emerald : KidsTheme.cyan,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lesson.name.isNotEmpty ? lesson.name : 'Ders Belirtilmemiş',
                            style: TextStyle(
                              color: isPacked ? KidsTheme.textMuted : KidsTheme.textWhite,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              decoration: isPacked ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          Text(
                            isPacked ? 'Çantaya koyuldu ✓' : 'Ders kitabı & defterini çantaya koy',
                            style: TextStyle(
                              color: isPacked ? KidsTheme.emerald : KidsTheme.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      isPacked ? Icons.check_circle_rounded : Icons.check_circle_outline_rounded,
                      color: isPacked ? KidsTheme.emerald : Colors.white24,
                      size: 22,
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ],
    );
  }
}
