import 'dart:async';
import 'package:flutter/material.dart';
import '../../../models/user_model.dart';
import '../../../models/message_model.dart';
import '../../../services/supabase_service.dart';
import '../../../theme/kids_theme.dart';

class WalkieTalkieTab extends StatefulWidget {
  final UserModel student;
  final VoidCallback onRefreshUser;

  const WalkieTalkieTab({
    super.key,
    required this.student,
    required this.onRefreshUser,
  });

  @override
  State<WalkieTalkieTab> createState() => _WalkieTalkieTabState();
}

class _WalkieTalkieTabState extends State<WalkieTalkieTab> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<MessageModel> _messages = [];
  bool _isLoading = false;
  StreamSubscription<MessageModel>? _msgSub;

  final List<String> _quickPhrases = [
    '📚 Dersim bitti!',
    '☕ Kısa bir mola alabilir miyim?',
    '🥪 Biraz acıktım.',
    '❓ Bir konuda yardıma ihtiyacım var.',
    '❤️ Sizi seviyorum!',
  ];

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _msgSub = SupabaseService.messageStreamController.stream.listen((msg) {
      if (mounted) {
        setState(() {
          _messages.add(msg);
        });
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

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    final list = await SupabaseService.getMessages(widget.student.familyId);
    if (mounted) {
      setState(() {
        _messages = list;
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

  Future<void> _sendMessage(String text) async {
    final clean = text.trim();
    if (clean.isEmpty) return;

    _msgController.clear();
    final ok = await SupabaseService.sendMessage(
      familyId: widget.student.familyId,
      senderId: widget.student.id,
      senderName: widget.student.name,
      content: clean,
    );

    if (ok) {
      _loadMessages();
    }
  }

  void _openAppealModal() {
    final titleController = TextEditingController();
    final reasonController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: KidsTheme.cardSlate,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
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
                      color: KidsTheme.purpleAccent.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Text('⚖️', style: TextStyle(fontSize: 24)),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Adalet Divanı (Hakem Heyeti)',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Kalkan kaybı veya kural itirazı yap',
                          style: TextStyle(fontSize: 12, color: KidsTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: titleController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'İtiraz Konusu (Örn: Ekran süresi erken bitti)',
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Açıklaman (Neden haklı olduğunu detaylıca anlat)...',
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () async {
                  if (titleController.text.trim().isEmpty || reasonController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Lütfen konu ve açıklama alanlarını doldurun.'),
                        backgroundColor: KidsTheme.roseLight,
                      ),
                    );
                    return;
                  }
                  Navigator.pop(ctx);
                  final ok = await SupabaseService.submitAppeal(
                    familyId: widget.student.familyId,
                    studentId: widget.student.id,
                    title: titleController.text.trim(),
                    reason: reasonController.text.trim(),
                  );
                  if (ok) {
                    widget.onRefreshUser();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('İtirazın Aile Hakem Heyetine iletildi! ⚖️'),
                        backgroundColor: KidsTheme.emeraldGreen,
                      ),
                    );
                  }
                },
                icon: const Text('⚖️'),
                label: const Text(
                  'Divana Sun',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: KidsTheme.purpleAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top banner: Adalet Divanı quick access
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: KidsTheme.cardSlate,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: KidsTheme.purpleAccent.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: KidsTheme.purpleAccent.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Text('⚖️', style: TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Adalet Divanı',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Haksız bir kalkan kaybı mı oldu? İtiraz et.',
                      style: TextStyle(fontSize: 11, color: KidsTheme.textMuted),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: _openAppealModal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: KidsTheme.purpleAccent.withOpacity(0.2),
                  foregroundColor: KidsTheme.purpleAccent,
                  elevation: 0,
                  side: BorderSide(color: KidsTheme.purpleAccent.withOpacity(0.4)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: const Text(
                  'İtiraz Et',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
        ),

        // Message history list
        Expanded(
          child: _isLoading && _messages.isEmpty
              ? const Center(child: CircularProgressIndicator(color: KidsTheme.cyanSoft))
              : _messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: KidsTheme.cardSlate,
                              shape: BoxShape.circle,
                            ),
                            child: const Text('📻', style: TextStyle(fontSize: 36)),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Aile Telsizi Açık',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Aşağıdaki hızlı butonlardan birini seçebilir veya mesaj yazabilirsin.',
                            style: TextStyle(color: KidsTheme.textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        final bool isMe = msg.senderId == widget.student.id;
                        return _buildMessageBubble(msg, isMe);
                      },
                    ),
        ),

        // Quick phrases chips
        Container(
          height: 42,
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _quickPhrases.length,
            itemBuilder: (context, i) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  backgroundColor: KidsTheme.surfaceElevated,
                  side: BorderSide(color: Colors.white.withOpacity(0.08)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  label: Text(
                    _quickPhrases[i],
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                  onPressed: () => _sendMessage(_quickPhrases[i]),
                ),
              );
            },
          ),
        ),

        // Message input bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          decoration: BoxDecoration(
            color: KidsTheme.surfaceElevated,
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
                      hintText: 'Ailene bir mesaj yaz...',
                      hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                      filled: true,
                      fillColor: Colors.black26,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: _sendMessage,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [KidsTheme.indigoPrimary, KidsTheme.cyanSoft],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    onPressed: () => _sendMessage(_msgController.text),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(MessageModel msg, bool isMe) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: KidsTheme.purpleAccent.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('👨‍👩‍👧', style: TextStyle(fontSize: 14)),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? KidsTheme.indigoPrimary : KidsTheme.cardSlate,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
                border: Border.all(
                  color: isMe ? Colors.white24 : Colors.white10,
                ),
              ),
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Text(
                      msg.senderName,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: KidsTheme.cyanSoft,
                      ),
                    ),
                  Text(
                    msg.content,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${msg.createdAt.hour.toString().padLeft(2, '0')}:${msg.createdAt.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withOpacity(0.4),
                    ),
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
