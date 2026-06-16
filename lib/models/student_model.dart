class StudentModel {
  final String id;          // رقم جلوس الطالب أو معرفه المستخرج من الـ QR
  final String? name;       // اسم الطالب (يتم جلبة اختياريًا من ملف الإكسيل إذا لزم الأمر)
  final String subject;     // اسم المادة الحالية التي تم اختيارها من القائمة
  final String grade;       // الدرجة الحقيقية المستخرجة عبر الـ OCR

  StudentModel({
    required this.id,
    this.name,
    required this.subject,
    required this.grade,
  });

  // تحويل البيانات إلى خريطة (Map) لتسهيل التعامل معها أو إرسالها لخدمة الحفظ
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'subject': subject,
      'grade': grade,
    };
  }

  // إنشاء كائن طالب جديد من بيانات قادمة (مثلاً عند القراءة من مصدر خارجي)
  factory StudentModel.fromMap(Map<String, dynamic> map) {
    return StudentModel(
      id: map['id'] ?? '',
      name: map['name'],
      subject: map['subject'] ?? '',
      grade: map['grade'] ?? '',
    );
  }
}
