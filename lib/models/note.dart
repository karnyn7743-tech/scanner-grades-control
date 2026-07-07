class Note {
  final String id;
  final NoteType type;
  final String title;
  final String message;
  final DateTime timestamp;
  final String? studentId;
  final String? studentName;

  Note({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.timestamp,
    this.studentId,
    this.studentName,
  });

  factory Note.error(String message, {String? studentId, String? studentName}) => Note(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
    type: NoteType.error,
    title: 'خطأ',
    message: message,
    timestamp: DateTime.now(),
    studentId: studentId,
    studentName: studentName,
  );

  factory Note.warning(String message, {String? studentId, String? studentName}) => Note(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
    type: NoteType.warning,
    title: 'تحذير',
    message: message,
    timestamp: DateTime.now(),
    studentId: studentId,
    studentName: studentName,
  );

  factory Note.success(String message, {String? studentId, String? studentName}) => Note(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
    type: NoteType.success,
    title: 'نجاح',
    message: message,
    timestamp: DateTime.now(),
    studentId: studentId,
    studentName: studentName,
  );

  factory Note.info(String message, {String? studentId, String? studentName}) => Note(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
    type: NoteType.info,
    title: 'معلومة',
    message: message,
    timestamp: DateTime.now(),
    studentId: studentId,
    studentName: studentName,
  );
}

enum NoteType {
  error,
  warning,
  success,
  info,

  String, get, displayName {
  switch (this) {
    case NoteType.error: return 'خطأ';
    case NoteType.warning: return 'تحذير';
    case NoteType.success: return 'نجاح';
    case NoteType.info: return 'معلومة';
  }
}

Color get color {
  switch (this) {
    case NoteType.error: return Colors.red;
    case NoteType.warning: return Colors.orange;
    case NoteType.success: return Colors.green;
    case NoteType.info: return Colors.blue;
  }
}

IconData get icon {
  switch (this) {
    case NoteType.error: return Icons.error;
    case NoteType.warning: return Icons.warning;
    case NoteType.success: return Icons.check_circle;
    case NoteType.info: return Icons.info;
  }
}
}
