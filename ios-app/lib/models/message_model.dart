class MessageModel {
  final String id;
  final String familyId;
  final String senderId;
  final String senderName;
  final String receiverId;
  final String messageType; // 'text', 'audio', 'quick_request'
  final String content;
  final String? audioUrl;
  final bool isRead;
  final DateTime createdAt;

  MessageModel({
    required this.id,
    required this.familyId,
    required this.senderId,
    this.senderName = 'Aile Bireyi',
    this.receiverId = 'all',
    this.messageType = 'text',
    required this.content,
    this.audioUrl,
    this.isRead = false,
    required this.createdAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json, {String? fallbackSenderName}) {
    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(json['created_at']?.toString() ?? '');
    } catch (_) {
      parsedDate = DateTime.now();
    }

    return MessageModel(
      id: json['id']?.toString() ?? '',
      familyId: json['family_id']?.toString() ?? '',
      senderId: json['sender_id']?.toString() ?? '',
      senderName: fallbackSenderName ?? json['sender_name']?.toString() ?? 'Aile Bireyi',
      receiverId: json['receiver_id']?.toString() ?? 'all',
      messageType: json['message_type']?.toString() ?? 'text',
      content: json['content']?.toString() ?? '',
      audioUrl: json['audio_url']?.toString(),
      isRead: json['is_read'] == true,
      createdAt: parsedDate,
    );
  }

  bool get isAudio => messageType == 'audio' || content.contains('🎙️') || content.contains('Sesli');
}
