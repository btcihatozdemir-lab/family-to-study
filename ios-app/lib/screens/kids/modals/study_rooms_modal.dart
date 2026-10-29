import 'package:flutter/material.dart';
import '../../../theme/kids_theme.dart';
import '../../../models/user_model.dart';
import '../../../services/supabase_service.dart';

class StudyRoomsModal extends StatefulWidget {
  final UserModel student;

  const StudyRoomsModal({
    super.key,
    required this.student,
  });

  static void show(BuildContext context, UserModel student) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StudyRoomsModal(student: student),
    );
  }

  @override
  State<StudyRoomsModal> createState() => _StudyRoomsModalState();
}

class _StudyRoomsModalState extends State<StudyRoomsModal> {
  bool _inRoom = false;
  int _minutesStudied = 0;

  final List<Map<String, dynamic>> _rooms = [
    {
      'id': 'room-1',
      'title': '7. Sınıf Sessiz LGS Odak Odası',
      'subject': 'Matematik & Fen',
      'participants': 14,
      'avatars': ['🦁', '🦊', '🐼', '🚀', '⭐'],
    },
    {
      'id': 'room-2',
      'title': 'Kitap Kurdu & Paragraf Kulübü',
      'subject': 'Türkçe & Edebiyat',
      'participants': 9,
      'avatars': ['📚', '🦉', '🐉', '🐯'],
    },
    {
      'id': 'room-3',
      'title': 'İngilizce Vocab & Kelime Laboratuvarı',
      'subject': 'İngilizce',
      'participants': 6,
      'avatars': ['🌍', '🎓', '🐬'],
    },
  ];

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

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Text('🤫', style: TextStyle(fontSize: 26)),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Akran Sessiz Çalışma Odaları',
                        style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
                      ),
                      Text(
                        'Mesajlaşma yok, dikkat dağıtma yok! Sadece odaklanan arkadaşlar.',
                        style: TextStyle(color: KidsTheme.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12),

          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _rooms.length,
              itemBuilder: (ctx, i) {
                final room = _rooms[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: KidsTheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              room['title'],
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: KidsTheme.emerald.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.circle, color: KidsTheme.emerald, size: 8),
                                const SizedBox(width: 6),
                                Text(
                                  '${room['participants']} Odaklanan',
                                  style: const TextStyle(color: KidsTheme.emerald, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('Branş: ${room['subject']}', style: const TextStyle(color: KidsTheme.textMuted, fontSize: 12)),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Row(
                            children: (room['avatars'] as List<String>).map((av) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: CircleAvatar(
                                  radius: 14,
                                  backgroundColor: KidsTheme.surfaceElevated,
                                  child: Text(av, style: const TextStyle(fontSize: 14)),
                                ),
                              );
                            }).toList(),
                          ),
                          const Spacer(),
                          ElevatedButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: KidsTheme.emerald,
                                  content: Text('🎧 "${room['title']}" odasına katıldın! Kronometre başladı.'),
                                ),
                              );
                            },
                            icon: const Icon(Icons.headphones_rounded, size: 16),
                            label: const Text('Odaya Gir', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: KidsTheme.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
