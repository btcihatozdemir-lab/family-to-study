class SubmissionModel {
  final String id;
  final String taskId;
  final String taskTitle;
  final String studentId;
  final String studentName;
  final int points;
  final String status;
  final List<String> photoUrls;
  final DateTime createdAt;

  SubmissionModel({
    required this.id,
    required this.taskId,
    required this.taskTitle,
    required this.studentId,
    required this.studentName,
    required this.points,
    required this.status,
    required this.photoUrls,
    required this.createdAt,
  });

  factory SubmissionModel.fromJson(Map<String, dynamic> json, {String taskTitle = 'Görev', String studentName = 'Öğrenci', int points = 10}) {
    List<String> photos = [];
    if (json['photo_urls'] is List) {
      photos = (json['photo_urls'] as List).map((p) => p.toString()).toList();
    }

    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(json['created_at']?.toString() ?? '');
    } catch (_) {
      parsedDate = DateTime.now();
    }

    return SubmissionModel(
      id: json['id']?.toString() ?? '',
      taskId: json['task_id']?.toString() ?? '',
      taskTitle: json['task_title']?.toString() ?? taskTitle,
      studentId: json['user_id']?.toString() ?? '',
      studentName: json['student_name']?.toString() ?? studentName,
      points: json['points'] is int ? json['points'] : points,
      status: json['status']?.toString() ?? 'pending',
      photoUrls: photos,
      createdAt: parsedDate,
    );
  }
}
