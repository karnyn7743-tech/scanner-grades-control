class ExamData {
  final String examId;
  final String subjectName;
  final String subjectId;
  final DateTime examDate;
  final Map<String, String> studentGrades; // studentSecretCode -> grade

  ExamData({
    required this.examId,
    required this.subjectName,
    required this.subjectId,
    required this.examDate,
    Map<String, String>? studentGrades,
  }) : studentGrades = studentGrades ?? {};

  factory ExamData.fromJson(Map<String, dynamic> json) => ExamData(
    examId: json['examId'],
    subjectName: json['subjectName'],
    subjectId: json['subjectId'],
    examDate: DateTime.parse(json['examDate']),
    studentGrades: Map<String, String>.from(json['studentGrades'] ?? {}),
  );

  Map<String, dynamic> toJson() => {
    'examId': examId,
    'subjectName': subjectName,
    'subjectId': subjectId,
    'examDate': examDate.toIso8601String(),
    'studentGrades': studentGrades,
  };
}
