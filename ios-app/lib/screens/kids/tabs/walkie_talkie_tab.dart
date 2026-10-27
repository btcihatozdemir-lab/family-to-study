import 'dart:async';
import 'package:flutter/material.dart';
import '../../../main.dart';
import '../../../models/user_model.dart';
import '../../../models/message_model.dart';
import '../../../services/supabase_service.dart';
import '../../../services/tts_service.dart';
import '../../../theme/kids_theme.dart';
import '../modals/appeal_modal.dart';

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

class _WalkieTalkieTabState extends State<WalkieTalkieTab> with SingleTickerProviderStateMixin {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _quickPhrasesScrollCtrl = ScrollController();

  List<MessageModel> _messages = [];
  List<UserModel> _otherMembers = [];
  bool _isLoading = false;
  StreamSubscription<MessageModel>? _msgSub;

  // Alıcı Hedefi ('all' veya spesifik user id)
  String _selectedReceiver = 'all';

  // Bas-Konuş Telsiz Canlı Kayıt State
  bool _isRecording = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  late AnimationController _pulseAnimCtrl;

  // Sesli Mesaj Oynatma State
  String? _currentlyPlayingId;

  final List<String> _quickPhrases = [
    '💧 Su / Meyve alabilir miyim?',
    '🙋 Bir soruda takıldım, bakar mısınız?',
    '🚻 3 dakika mola lazım',
    '📸 Testimi bitirdim, kontrole hazır!',
    '📻 Cevap veriyorum: Tamam, anlaşıldı!',
    '🚀 Uçuşa geçtim, ders başlıyor!',
    '🍉 Meyve tabağım gelebilir mi?',
    '⏳ 5 dakika sonra tamamlıyorum!',
    '⭐️ Harika odaklandım, devam ediyorum!',
  ];

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _loadFamilyMembers();

    _pulseAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _msgSub = SupabaseService.messageStreamController.stream.listen((msg) {
      if (mounted) {
        setState(() {
          // Eğer aynı ID yoksa listeye ekle
          if (!_messages.any((m) => m.id == msg.id)) {
            _messages.add(msg);
          }
        });
        _scrollToBottom();
      }
    });
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _recordTimer?.cancel();
    _pulseAnimCtrl.dispose();
    _msgController.dispose();
    _scrollController.dispose();
    _quickPhrasesScrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFamilyMembers() async {
    final members = await SupabaseService.fetchFamilyMembers(widget.student.familyId);
    if (mounted) {
      setState(() {
        _otherMembers = members.where((m) => m.id != widget.student.id).toList();
      });
    }
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (!silent) {
      setState(() => _isLoading = true);
    }
    final list = await SupabaseService.fetchMessages(widget.student.familyId, widget.student.id);
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

  Future<void> _sendMessage(String text, {String messageType = 'text', String? audioUrl}) async {
    final clean = text.trim();
    if (clean.isEmpty) return;

    _msgController.clear();

    // İyimser UI güncellemesi (Optimistic update): Kullanıcı hemen görsün
    final tempId = 'temp-${DateTime.now().millisecondsSinceEpoch}';
    final optimisticMsg = MessageModel(
      id: tempId,
      familyId: widget.student.familyId,
      senderId: widget.student.id,
      senderName: widget.student.name,
      receiverId: _selectedReceiver,
      messageType: messageType,
      content: clean,
      audioUrl: audioUrl,
      isRead: false,
      createdAt: DateTime.now(),
    );

    setState(() {
      _messages.add(optimisticMsg);
    });
    _scrollToBottom();

    final ok = await SupabaseService.sendMessage(
      familyId: widget.student.familyId,
      senderId: widget.student.id,
      senderName: widget.student.name,
      receiverId: _selectedReceiver,
      content: clean,
      messageType: messageType,
      audioUrl: audioUrl,
    );

    if (ok) {
      _loadMessages(silent: true);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Mesaj gönderilemedi, lütfen bağlantınızı kontrol edin.'),
            backgroundColor: Colors.redAccent,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // BAS-KONUŞ CANLI KAYIT BAŞLAT
  void _startVoiceRecording() {
    if (_isRecording) return;
    setState(() {
      _isRecording = true;
      _recordSeconds = 0;
    });

    TTSService.speak('Bip! Telsiz mandalı açıldı.');

    _recordTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (mounted) {
        setState(() => _recordSeconds++);
      }
    });
  }

  // BAS-KONUŞ KAYDI DURDUR VE TELSİZDEN FIRLAT
  Future<void> _stopVoiceRecording() async {
    if (!_isRecording) return;
    _recordTimer?.cancel();
    final duration = _recordSeconds > 0 ? _recordSeconds : 1;

    setState(() {
      _isRecording = false;
    });

    TTSService.speak('Bip! Tamam.');

    final voiceContent = '🎙️ Sesli Telsiz Anonsu ($duration sn): "${widget.student.name} telsizden sesleniyor, tamam!"';
    await _sendMessage(voiceContent, messageType: 'audio');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('📻 Telsiz Anonsu Gönderildi ($duration saniye)'),
          backgroundColor: KidsTheme.emerald,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // BAS-KONUŞ TIKLA-AÇ / TIKLA-KAPAT TOGGLE
  void _toggleVoiceRecording() {
    if (_isRecording) {
      _stopVoiceRecording();
    } else {
      _startVoiceRecording();
    }
  }

  // SESLİ MESAJI DİNLE / OYNAT
  void _playAudioMessage(MessageModel msg) {
    if (_currentlyPlayingId == msg.id) {
      TTSService.stop();
      setState(() => _currentlyPlayingId = null);
      return;
    }

    setState(() => _currentlyPlayingId = msg.id);

    String speech = msg.content;
    if (speech.contains(':')) {
      speech = speech.split(':').last.replaceAll('"', '').trim();
    }

    TTSService.speak('${msg.senderName} telsizden diyor ki: $speech');

    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && _currentlyPlayingId == msg.id) {
        setState(() => _currentlyPlayingId = null);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 1. Telsiz Kanal & Alıcı Seçim Barı
        _buildRadioHeader(),

        // 2. Mesaj Akış Geçmişi
        Expanded(
          child: _isLoading && _messages.isEmpty
              ? const Center(child: CircularProgressIndicator(color: KidsTheme.cyan))
              : _messages.isEmpty
                  ? _buildEmptyRadioState()
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

        // 3. Hızlı Telsiz Kodları (Yatay Kaydırılabilir Bar + Oklar)
        _buildQuickPhrasesRow(),

        // 4. BAS-KONUŞ & Mesaj Gönderme Konsolu
        _buildTacticalConsole(),
      ],
    );
  }

  Widget _buildRadioHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: KidsTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: KidsTheme.cyan.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Text('📻', style: TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.greenAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'AİLE FREKANSI (CANLI)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Colors.greenAccent,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
                    const Text(
                      'Bas-Konuş Aile Telsizi',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
              ),
              // Adalet Divanı İtiraz Butonu
              OutlinedButton.icon(
                onPressed: () => AppealModal.show(context, widget.student, onSuccess: widget.onRefreshUser),
                icon: const Text('⚖️', style: TextStyle(fontSize: 13)),
                label: const Text('İtiraz Et', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: KidsTheme.rose.withOpacity(0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
              ),
            ],
          ),

          // Alıcı Seçici (Tüm Aile / Anne / Baba / Kardeş)
          if (_otherMembers.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Text('Alıcı: ', style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildReceiverChip('all', '📢 Tüm Aile'),
                          ..._otherMembers.map((m) {
                            final icon = m.role == 'parent' ? '👨‍👩‍👧' : '🧒';
                            final shortName = m.name.split(' ').first;
                            return _buildReceiverChip(m.id, '$icon $shortName');
                          }),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReceiverChip(String id, String label) {
    final isSelected = _selectedReceiver == id;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () => setState(() => _selectedReceiver = id),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? KidsTheme.primary : KidsTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? KidsTheme.cyan : Colors.white12,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white70,
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyRadioState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: KidsTheme.surfaceElevated,
              shape: BoxShape.circle,
            ),
            child: const Text('📻', style: TextStyle(fontSize: 40)),
          ),
          const SizedBox(height: 12),
          const Text(
            'Telsiz Frekansı Açık ve Net',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Aşağıdaki "BAS-KONUŞ" düğmesine dokunarak veya hazır mesaj seçerek ailene anons yapabilirsin.',
            textAlign: TextAlign.center,
            style: TextStyle(color: KidsTheme.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPhrasesRow() {
    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        children: [
          // Sol Kaydırma Butonu
          InkWell(
            onTap: () {
              _quickPhrasesScrollCtrl.animateTo(
                (_quickPhrasesScrollCtrl.offset - 160).clamp(0.0, _quickPhrasesScrollCtrl.position.maxScrollExtent),
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: KidsTheme.surfaceElevated,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white12),
              ),
              child: const Icon(Icons.chevron_left_rounded, color: Colors.cyanAccent, size: 18),
            ),
          ),
          const SizedBox(width: 4),

          // Yatay Kaydırılabilir Hazır Mesajlar Listesi
          Expanded(
            child: ScrollConfiguration(
              behavior: const AppScrollBehavior(),
              child: ListView.builder(
                controller: _quickPhrasesScrollCtrl,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                itemCount: _quickPhrases.length,
                itemBuilder: (context, i) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      backgroundColor: KidsTheme.surfaceElevated,
                      side: BorderSide(color: Colors.white.withOpacity(0.12)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      label: Text(
                        _quickPhrases[i],
                        style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => _sendMessage(_quickPhrases[i], messageType: 'quick_request'),
                    ),
                  );
                },
              ),
            ),
          ),

          const SizedBox(width: 4),
          // Sağ Kaydırma Butonu
          InkWell(
            onTap: () {
              _quickPhrasesScrollCtrl.animateTo(
                (_quickPhrasesScrollCtrl.offset + 160).clamp(0.0, _quickPhrasesScrollCtrl.position.maxScrollExtent),
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: KidsTheme.surfaceElevated,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white12),
              ),
              child: const Icon(Icons.chevron_right_rounded, color: Colors.cyanAccent, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTacticalConsole() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
      decoration: BoxDecoration(
        color: KidsTheme.surfaceElevated,
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Canlı Kayıt Yapılıyorsa Canlı Banner
            if (_isRecording)
              ScaleTransition(
                scale: Tween<double>(begin: 0.96, end: 1.02).animate(
                  CurvedAnimation(parent: _pulseAnimCtrl, curve: Curves.easeInOut),
                ),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade900.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.redAccent, width: 2),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('🔴', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Text(
                        'TELSİZ YAYINDA: 00:${_recordSeconds.toString().padLeft(2, '0')} (Bitirmek ve Göndermek için Dokun)',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),

            Row(
              children: [
                // BÜYÜK BAS-KONUŞ DÜĞMESİ (Hem Tıklama Hem Basılı Tutma Desteği)
                GestureDetector(
                  onTap: _toggleVoiceRecording,
                  onLongPressStart: (_) => _startVoiceRecording(),
                  onLongPressEnd: (_) => _stopVoiceRecording(),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: _isRecording
                          ? const LinearGradient(colors: [Colors.redAccent, Colors.red])
                          : const LinearGradient(colors: [Color(0xFF0D9488), Color(0xFF0F766E)]),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: (_isRecording ? Colors.red : Colors.teal).withOpacity(0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isRecording ? Icons.mic_rounded : Icons.radio_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isRecording ? 'BİTİR & GÖNDER' : 'BAS-KONUŞ',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Metin Girişi
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Ailene telsiz mesajı yaz...',
                      hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                      filled: true,
                      fillColor: Colors.black26,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (t) => _sendMessage(t),
                  ),
                ),
                const SizedBox(width: 8),

                // Gönder Butonu
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [KidsTheme.primary, KidsTheme.cyan],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                    onPressed: () => _sendMessage(_msgController.text),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(MessageModel msg, bool isMe) {
    final bool isAudioMsg = msg.isAudio;
    final bool isPlayingThis = _currentlyPlayingId == msg.id;

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
                color: KidsTheme.primary.withOpacity(0.2),
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
                color: isMe
                    ? (isAudioMsg ? const Color(0xFF1E3A8A) : KidsTheme.primary)
                    : (isAudioMsg ? const Color(0xFF134E4A) : KidsTheme.surfaceElevated),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
                border: Border.all(
                  color: isAudioMsg ? Colors.cyanAccent.withOpacity(0.4) : (isMe ? Colors.white24 : Colors.white10),
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
                        color: KidsTheme.cyan,
                      ),
                    ),

                  // Sesli Mesaj Oynatıcı Kartı
                  if (isAudioMsg) ...[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () => _playAudioMessage(msg),
                          icon: Icon(
                            isPlayingThis ? Icons.stop_circle_rounded : Icons.play_circle_fill_rounded,
                            color: isPlayingThis ? Colors.amber : Colors.cyanAccent,
                            size: 28,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isPlayingThis ? 'Telsiz Çalıyor... 📻' : 'Sesli Telsiz Anonsu 🎙️',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            const Text(
                              'ılı.lıllılı.ıllı.lı',
                              style: TextStyle(color: Colors.cyanAccent, fontSize: 11, letterSpacing: 1.5),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ] else ...[
                    Text(
                      msg.content,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ],

                  const SizedBox(height: 3),
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
