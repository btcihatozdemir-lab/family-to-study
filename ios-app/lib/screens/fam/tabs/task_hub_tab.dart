import 'package:flutter/material.dart';
import '../../../models/task_model.dart';
import '../../../models/user_model.dart';
import '../../../services/supabase_service.dart';
import '../../../theme/fam_theme.dart';

class TaskHubTab extends StatefulWidget {
  final String familyId;
  final VoidCallback onRefreshAll;

  const TaskHubTab({
    super.key,
    required this.familyId,
    required this.onRefreshAll,
  });

  @override
  State<TaskHubTab> createState() => _TaskHubTabState();
}

class _TaskHubTabState extends State<TaskHubTab> {
  List<TaskModel> _tasks = [];
  List<UserModel> _children = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final kids = await SupabaseService.fetchFamilyChildren(widget.familyId);
    final tasks = await SupabaseService.fetchTasks(widget.familyId, '');
    if (mounted) {
      setState(() {
        _children = kids;
        _tasks = tasks;
        _isLoading = false;
      });
    }
  }

  void _openFlashQuestModal() {
    final titleController = TextEditingController(text: '⚡ Acil Görev: Odanı 15 dakikada topla!');
    int points = 30;
    int duration = 15;
    bool isRace = true;
    bool requiresPhoto = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: FamTheme.surface,
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
              child: SingleChildScrollView(
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
                    const SizedBox(height: 16),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('🔥', style: TextStyle(fontSize: 22)),
                        SizedBox(width: 8),
                        Text(
                          'Acil Flaş Görev (Flash Quest)',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Süreli ve yüksek puanlı görev başlatın. İlk bitiren çocuk puanı kapar!',
                      style: TextStyle(color: FamTheme.textMuted, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),

                    TextField(
                      controller: titleController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Flaş Görev Başlığı',
                        labelStyle: const TextStyle(color: FamTheme.textMuted),
                        filled: true,
                        fillColor: Colors.black26,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Puan Ödülü:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        Text('$points 🪙 (2 Kat Bonus)', style: const TextStyle(color: FamTheme.gold, fontWeight: FontWeight.w900, fontSize: 15)),
                      ],
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: FamTheme.gold,
                        thumbColor: FamTheme.gold,
                      ),
                      child: Slider(
                        min: 10,
                        max: 100,
                        divisions: 18,
                        value: points.toDouble(),
                        onChanged: (val) => setModalState(() => points = val.round()),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Süre Limiti:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        Text('$duration Dakika', style: const TextStyle(color: FamTheme.primaryLight, fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [10, 15, 20, 30, 45].map((d) {
                        final isSel = duration == d;
                        return ChoiceChip(
                          label: Text('$d dk'),
                          selected: isSel,
                          selectedColor: FamTheme.primary,
                          labelStyle: TextStyle(
                            color: isSel ? Colors.white : FamTheme.textMuted,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (_) => setModalState(() => duration = d),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // İlk-Kapar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Text('🏁', style: TextStyle(fontSize: 20)),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'İlk-Kapar Yarış Modu (İlk bitiren kazanır)',
                              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                          Switch(
                            value: isRace,
                            activeColor: FamTheme.primaryLight,
                            onChanged: (v) => setModalState(() => isRace = v),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Fotoğraf
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Text('📸', style: TextStyle(fontSize: 20)),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Fotoğraf Kanıtı Zorunlu',
                              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                          Switch(
                            value: requiresPhoto,
                            activeColor: FamTheme.emerald,
                            onChanged: (v) => setModalState(() => requiresPhoto = v),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    ElevatedButton(
                      onPressed: () async {
                        if (titleController.text.trim().isEmpty) return;
                        Navigator.pop(ctx);
                        final ok = await SupabaseService.createFlashQuest(
                          familyId: widget.familyId,
                          title: titleController.text.trim(),
                          points: points,
                          durationMinutes: duration,
                          isRace: isRace,
                          requiresPhoto: requiresPhoto,
                        );
                        if (ok) {
                          _loadData();
                          widget.onRefreshAll();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF97316),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('🔥 Flaş Görevi Şimdi Başlat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openCreateRewardModal() {
    final titleController = TextEditingController();
    int cost = 50;
    String tier = 'micro';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: FamTheme.surface,
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
              child: SingleChildScrollView(
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
                    const SizedBox(height: 16),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('🎁', style: TextStyle(fontSize: 22)),
                        SizedBox(width: 8),
                        Text(
                          'Yeni Ödül Tanımla',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    TextField(
                      controller: titleController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Ödül Adı',
                        labelStyle: const TextStyle(color: FamTheme.textMuted),
                        hintText: 'Örn: 30 Dk Ekran Süresi, Sinema Bileti',
                        hintStyle: const TextStyle(color: Colors.white24),
                        filled: true,
                        fillColor: Colors.black26,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Puan Maliyeti:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        Text('$cost 🪙', style: const TextStyle(color: FamTheme.gold, fontWeight: FontWeight.w900, fontSize: 16)),
                      ],
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: FamTheme.gold,
                        thumbColor: FamTheme.gold,
                      ),
                      child: Slider(
                        min: 20,
                        max: 500,
                        divisions: 24,
                        value: cost.toDouble(),
                        onChanged: (val) => setModalState(() => cost = val.round()),
                      ),
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      value: tier,
                      dropdownColor: FamTheme.surfaceElevated,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Ödül Seviyesi (Tier)',
                        labelStyle: const TextStyle(color: FamTheme.textMuted),
                        filled: true,
                        fillColor: Colors.black26,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'micro', child: Text('🟢 Küçük Ödül (20-100 Puan)')),
                        DropdownMenuItem(value: 'medium', child: Text('🟡 Orta Ödül (100-250 Puan)')),
                        DropdownMenuItem(value: 'large', child: Text('🟣 Büyük Ödül (250+ Puan)')),
                        DropdownMenuItem(value: 'parent_challenge', child: Text('🏆 Veli Meydan Okuması')),
                      ],
                      onChanged: (val) {
                        if (val != null) setModalState(() => tier = val);
                      },
                    ),
                    const SizedBox(height: 24),

                    ElevatedButton(
                      onPressed: () async {
                        if (titleController.text.trim().isEmpty) return;
                        Navigator.pop(ctx);
                        final ok = await SupabaseService.createReward(
                          familyId: widget.familyId,
                          title: titleController.text.trim(),
                          costPoints: cost,
                          tier: tier,
                        );
                        if (ok && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Yeni ödül pazara eklendi! ✨')),
                          );
                          widget.onRefreshAll();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FamTheme.gold,
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Ödülü Pazara Ekle', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openHappyHourModal() {
    int discount = 30;
    int duration = 60;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: FamTheme.surface,
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
              child: SingleChildScrollView(
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
                    const SizedBox(height: 16),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('🏷️', style: TextStyle(fontSize: 22)),
                        SizedBox(width: 8),
                        Text(
                          'Sürpriz Happy Hour İndirimi',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Ödül pazarında sınırlı süreli indirim başlatın, çocukları motive edin!',
                      style: TextStyle(color: FamTheme.textMuted, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),

                    const Text('İndirim Oranı:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [20, 30, 50].map((d) {
                        final isSel = discount == d;
                        return ChoiceChip(
                          label: Text('%$d İndirim'),
                          selected: isSel,
                          selectedColor: FamTheme.primary,
                          labelStyle: TextStyle(
                            color: isSel ? Colors.white : FamTheme.textMuted,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (_) => setModalState(() => discount = d),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    const Text('Süre:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [30, 60, 120].map((m) {
                        final isSel = duration == m;
                        return ChoiceChip(
                          label: Text('$m Dakika'),
                          selected: isSel,
                          selectedColor: FamTheme.emerald,
                          labelStyle: TextStyle(
                            color: isSel ? Colors.white : FamTheme.textMuted,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (_) => setModalState(() => duration = m),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final ok = await SupabaseService.startHappyHour(
                          familyId: widget.familyId,
                          discountPercent: discount,
                          durationMinutes: duration,
                        );
                        if (ok && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('🎉 %$discount indirim $duration dakika boyunca devrede!')),
                          );
                          widget.onRefreshAll();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FamTheme.primaryLight,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('İndirimi Hemen Başlat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openCreateTaskModal() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    int points = 15;
    String category = 'routine';
    String assignedTo = 'both';
    bool isRace = false;
    bool requiresPhoto = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: FamTheme.surface,
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
              child: SingleChildScrollView(
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
                    const SizedBox(height: 16),
                    const Text(
                      'Yeni Görev / Yarış Tanımla',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),

                    // Görev Başlığı
                    TextField(
                      controller: titleController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Görev Başlığı',
                        labelStyle: const TextStyle(color: FamTheme.textMuted),
                        hintText: 'Örn: Matematik Testi 10 Soru',
                        hintStyle: const TextStyle(color: Colors.white24),
                        filled: true,
                        fillColor: Colors.black26,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Açıklama
                    TextField(
                      controller: descController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Açıklama (İsteğe Bağlı)',
                        labelStyle: const TextStyle(color: FamTheme.textMuted),
                        hintText: 'Örn: Sayfa 42-45 arası çözülecek',
                        hintStyle: const TextStyle(color: Colors.white24),
                        filled: true,
                        fillColor: Colors.black26,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Puan Seçimi
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Puan Ödülü:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        Text('$points 🪙', style: const TextStyle(color: FamTheme.gold, fontWeight: FontWeight.w900, fontSize: 16)),
                      ],
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: FamTheme.gold,
                        thumbColor: FamTheme.gold,
                      ),
                      child: Slider(
                        min: 5,
                        max: 100,
                        divisions: 19,
                        value: points.toDouble(),
                        onChanged: (val) {
                          setModalState(() => points = val.round());
                        },
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Kategori Seçimi
                    DropdownButtonFormField<String>(
                      value: category,
                      dropdownColor: FamTheme.surfaceElevated,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Kategori',
                        labelStyle: const TextStyle(color: FamTheme.textMuted),
                        filled: true,
                        fillColor: Colors.black26,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'routine', child: Text('📋 Günlük Rutin')),
                        DropdownMenuItem(value: 'study', child: Text('🎯 Ders & Ödev')),
                        DropdownMenuItem(value: 'book', child: Text('📚 Kitap Okuma')),
                        DropdownMenuItem(value: 'home', child: Text('🏠 Ev Düzeni')),
                        DropdownMenuItem(value: 'sport', child: Text('⚽ Spor & Sağlık')),
                      ],
                      onChanged: (val) {
                        if (val != null) setModalState(() => category = val);
                      },
                    ),
                    const SizedBox(height: 16),

                    // İlk-Kapar Yarışı Toggle
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isRace ? FamTheme.primaryLight.withOpacity(0.5) : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Text('⚡', style: TextStyle(fontSize: 22)),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('İlk Kapar Yarış Görevi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                Text('Tüm çocuklar arasında ilk tamamlayan veya kapan puanı alır', style: TextStyle(color: FamTheme.textMuted, fontSize: 11)),
                              ],
                            ),
                          ),
                          Switch(
                            value: isRace,
                            activeColor: FamTheme.primaryLight,
                            onChanged: (val) => setModalState(() => isRace = val),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Fotoğraf Kanıtı Toggle
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Text('📸', style: TextStyle(fontSize: 22)),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Fotoğraf Kanıtı Zorunlu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                Text('Öğrenci görevi bitirince kamera ile fotoğraf çekmek zorunda olur', style: TextStyle(color: FamTheme.textMuted, fontSize: 11)),
                              ],
                            ),
                          ),
                          Switch(
                            value: requiresPhoto,
                            activeColor: FamTheme.emerald,
                            onChanged: (val) => setModalState(() => requiresPhoto = val),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    ElevatedButton(
                      onPressed: () async {
                        if (titleController.text.trim().isEmpty) return;
                        Navigator.pop(ctx);
                        final ok = await SupabaseService.createNewTask(
                          familyId: widget.familyId,
                          title: titleController.text.trim(),
                          description: descController.text.trim(),
                          points: points,
                          category: category,
                          assignedTo: assignedTo,
                          isRace: isRace,
                          requiresPhoto: requiresPhoto,
                        );
                        if (ok) {
                          _loadData();
                          widget.onRefreshAll();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FamTheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Görevi Yayınla', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadData();
        widget.onRefreshAll();
      },
      color: FamTheme.primaryLight,
      backgroundColor: FamTheme.surfaceElevated,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // Create Task Big Action Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [FamTheme.primary, Color(0xFF3F37C9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: FamTheme.primary.withOpacity(0.3),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Text('⚡', style: TextStyle(fontSize: 26)),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hızlı Görev veya Yarış Oluştur',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Ders, kitap, ev işi veya İlk-Kapar yarışı tanımlayın.',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: _openCreateTaskModal,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: FamTheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    elevation: 0,
                  ),
                  child: const Text('Oluştur', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Flash Quest Big Action Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEA580C), Color(0xFFC2410C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFEA580C).withOpacity(0.3),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Text('🔥', style: TextStyle(fontSize: 26)),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Acil Flaş Görev (Flash Quest)',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Süreli, 2 kat puanlı ani ilk-kapar görevi başlat.',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: _openFlashQuestModal,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFFEA580C),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    elevation: 0,
                  ),
                  child: const Text('Başlat', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Quick Tactical Tools: Reward and Happy Hour
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _openCreateRewardModal,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: FamTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: FamTheme.gold.withOpacity(0.3)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('🎁', style: TextStyle(fontSize: 18)),
                        SizedBox(width: 8),
                        Text(
                          'Ödül Tanımla',
                          style: TextStyle(color: FamTheme.gold, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: _openHappyHourModal,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: FamTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: FamTheme.primaryLight.withOpacity(0.3)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('🏷️', style: TextStyle(fontSize: 18)),
                        SizedBox(width: 8),
                        Text(
                          'Happy Hour',
                          style: TextStyle(color: FamTheme.primaryLight, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Active Tasks List Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Text('📌', style: TextStyle(fontSize: 18)),
                  SizedBox(width: 8),
                  Text(
                    'Aktif Aile Görevleri',
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
                  '${_tasks.length}',
                  style: const TextStyle(color: FamTheme.textMuted, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_isLoading && _tasks.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(color: FamTheme.primaryLight),
              ),
            )
          else if (_tasks.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: FamTheme.cardDecoration(),
              child: const Center(
                child: Text(
                  'Şu anda aktif görev bulunmuyor. Yukarıdaki butona tıklayarak ekleyebilirsiniz.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: FamTheme.textMuted, fontSize: 13),
                ),
              ),
            )
          else
            ..._tasks.map((t) => _buildTaskCard(t)),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildTaskCard(TaskModel task) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: FamTheme.cardDecoration(
        borderColor: task.isRace ? FamTheme.primaryLight.withOpacity(0.4) : null,
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: task.isRace
                  ? FamTheme.primaryLight.withOpacity(0.18)
                  : FamTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                task.isRace ? '⚡' : _getCategoryEmoji(task.category),
                style: const TextStyle(fontSize: 22),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        task.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (task.requiresPhoto) ...[
                      const SizedBox(width: 6),
                      const Text('📸', style: TextStyle(fontSize: 12)),
                    ],
                  ],
                ),
                if (task.description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    task.description,
                    style: const TextStyle(color: FamTheme.textMuted, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (task.isRace)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: FamTheme.primaryLight.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'YARIŞ',
                          style: TextStyle(
                            color: FamTheme.primaryLight,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    Text(
                      'Kategori: ${_getCategoryLabel(task.category)}',
                      style: const TextStyle(color: FamTheme.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: FamTheme.gold.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: FamTheme.gold.withOpacity(0.3)),
            ),
            child: Text(
              '${task.points} 🪙',
              style: const TextStyle(
                color: FamTheme.gold,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getCategoryEmoji(String cat) {
    switch (cat.toLowerCase()) {
      case 'study':
        return '🎯';
      case 'book':
        return '📚';
      case 'home':
        return '🏠';
      case 'sport':
        return '⚽';
      case 'routine':
      default:
        return '📋';
    }
  }

  String _getCategoryLabel(String cat) {
    switch (cat.toLowerCase()) {
      case 'study':
        return 'Ders';
      case 'book':
        return 'Kitap';
      case 'home':
        return 'Ev Düzeni';
      case 'sport':
        return 'Spor';
      case 'routine':
      default:
        return 'Rutin';
    }
  }
}
