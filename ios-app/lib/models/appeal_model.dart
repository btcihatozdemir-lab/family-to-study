class AppealModel {
  final String id;
  final String familyId;
  final String studentId;
  final String studentName;
  final String reasonText;
  final String? audioUrl;
  final String status;
  final DateTime createdAt;

  AppealModel({
    required this.id,
    required this.familyId,
    required this.studentId,
    required this.studentName,
    required this.reasonText,
    this.audioUrl,
    required this.status,
    required this.createdAt,
  });

  factory AppealModel.fromJson(Map<String, dynamic> json, {String studentName = 'Öğrenci'}) {
    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(json['created_at']?.toString() ?? '');
    } catch (_) {
      parsedDate = DateTime.now();
    }

    return AppealModel(
      id: json['id']?.toString() ?? '',
      familyId: json['family_id']?.toString() ?? '',
      studentId: json['user_id']?.toString() ?? '',
      studentName: json['student_name']?.toString() ?? studentName,
      reasonText: json['reason_text']?.toString() ?? 'Gerekçe belirtilmedi.',
      audioUrl: json['audio_url']?.toString(),
      status: json['status']?.toString() ?? 'pending',
      createdAt: parsedDate,
    );
  }
}
