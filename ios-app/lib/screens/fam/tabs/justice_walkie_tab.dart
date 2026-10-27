import 'dart:async';
import 'package:flutter/material.dart';
import '../../../models/appeal_model.dart';
import '../../../models/message_model.dart';
import '../../../services/supabase_service.dart';
import '../../../services/session_manager.dart';
import '../../../theme/fam_theme.dart';

class JusticeWalkieTab extends StatefulWidget {
  final String familyId;
  final VoidCallback onRefreshAll;

  const JusticeWalkieTab({
    super.key,
    required this.familyId,
    required this.onRefreshAll,
  });

  @override
  State<JusticeWalkieTab> createState() => _JusticeWalkieTabState();
}

class _JusticeWalkieTabState extends State<JusticeWalkieTab> {
  List<AppealModel> _appeals = [];
  List<MessageModel> _messages = [];
  bool _isLoading = true;
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<MessageModel>? _msgSub;

  final List<String> _quickBroadcasts = [
    '🍲 Akşam yemeği hazır, masaya gelin!',
    '📚 Ders ve odaklanma saati başlıyor.',
    '🌟 Harika gidiyorsunuz, tebrikler!',
    '🛏️ Uyku saati yaklaşıyor, hazırlanın.',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
    _msgSub = SupabaseService.messageStreamController.stream.listen((msg) {
      if (mounted) {
        setState(() => _messages.add(msg));
        _scrollToBottom();
      }
    });
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final appeals = await SupabaseService.fetchPendingAppeals(widget.familyId);
    final msgs = await SupabaseService.fetchMessages(widget.familyId);
    if (mounted) {
      setState(() {
        _appeals = appeals;
        _messages = msgs;
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendBroadcast(String text) async {
    final clean = text.trim();
    if (clean.isEmpty) return;

    _msgController.clear();
    final ok = await SupabaseService.sendMessage(
      familyId: widget.familyId,
      senderId: SessionManager.userId,
      senderName: SessionManager.userName.isNotEmpty ? SessionManager.userName : 'Ebeveyn',
      receiverId: 'all',
      content: clean,
    );

    if (ok) {
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top Section: Adalet Divanı Hakem Masası (Collapsible or Card List)
        if (_appeals.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            decoration: BoxDecoration(
              color: FamTheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: FamTheme.secondary.withOpacity(0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('⚖️', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Adalet Divanı (Bekleyen İtirazlar)',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: FamTheme.secondary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_appeals.length} Dosya',
                        style: const TextStyle(
                          color: FamTheme.secondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ..._appeals.map((a) => _buildAppealCard(a)),
              ],
            ),
          ),

        // Live Messages Header
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 4),
          child: Row(
            children: [
              const Text('📻', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              const Text(
                'Aile Bas-Konuş & Telsiz Kanalı',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const Spacer(),
              Text(
                '${_messages.length} Mesaj',
                style: const TextStyle(color: FamTheme.textMuted, fontSize: 11),
              ),
            ],
          ),
        ),

        // Messages Feed
        Expanded(
          child: _isLoading && _messages.isEmpty
              ? const Center(child: CircularProgressIndicator(color: FamTheme.primaryLight))
              : _messages.isEmpty
                  ? Center(
                      child: Text(
                        'Henüz aile telsizinde mesaj yok.',
                        style: TextStyle(color: FamTheme.textMuted.withOpacity(0.7)),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        final isMe = msg.senderId == SessionManager.userId;
                        return _buildMessageBubble(msg, isMe);
                      },
                    ),
        ),

        // Quick Broadcast Chips
        SizedBox(
          height: 38,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: _quickBroadcasts.length,
            itemBuilder: (context, i) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  backgroundColor: FamTheme.surface,
                  side: BorderSide(color: Colors.white.withOpacity(0.08)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  label: Text(
                    _quickBroadcasts[i],
                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                  onPressed: () => _sendBroadcast(_quickBroadcasts[i]),
                ),
              );
            },
          ),
        ),

        // Bottom Input
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          decoration: BoxDecoration(
            color: FamTheme.surfaceElevated,
            border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Tüm aileye seslen veya anons yap...',
                      hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                      filled: true,
                      fillColor: Colors.black26,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: _sendBroadcast,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  decoration: const BoxDecoration(
                    color: FamTheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    onPressed: () => _sendBroadcast(_msgController.text),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppealCard(AppealModel appeal) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                appeal.studentName,
                style: const TextStyle(color: FamTheme.primaryLight, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const Spacer(),
              Text(
                '${appeal.createdAt.hour.toString().padLeft(2, '0')}:${appeal.createdAt.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(color: FamTheme.textMuted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            appeal.reasonText,
            style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.3),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await SupabaseService.reviewAppeal(
                      appealId: appeal.id,
                      studentId: appeal.studentId,
                      approve: true,
                    );
                    _loadData();
                    widget.onRefreshAll();
                  },
                  icon: const Text('🛡️'),
                  label: const Text('Kabul Et (+1 Kalkan)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FamTheme.emerald,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () async {
                  await SupabaseService.reviewAppeal(
                    appealId: appeal.id,
                    studentId: appeal.studentId,
                    approve: false,
                  );
                  _loadData();
                  widget.onRefreshAll();
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: FamTheme.rose),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                ),
                child: const Text('Reddet', style: TextStyle(color: FamTheme.rose, fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(MessageModel msg, bool isMe) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? FamTheme.primary : FamTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Text(
                    msg.senderName,
                    style: TextStyle(
                      color: isMe ? Colors.white70 : FamTheme.cyan,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    msg.content,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
