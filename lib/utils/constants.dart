import 'package:flutter/material.dart';

class AppConstants {
  // إعدادات التطبيق
  static const String appName = 'نظام إدخال الدرجات';
  static const String appVersion = '1.0.0';

  // إعدادات الكاميرا
  static const ResolutionPreset cameraResolution = ResolutionPreset.medium;
  static const double scanZoneHeightRatio = 0.25; // 25% من ارتفاع الشاشة
  static const double scanZoneBottomOffset = 0.70; // 70% من ارتفاع الشاشة من الأعلى

  // إعدادات OCR
  static const double ocrConfidenceThreshold = 0.7;
  static const Duration ocrDebounceTime = Duration(milliseconds: 500);

  // إعدادات QR
  static const Duration qrDebounceTime = Duration(milliseconds: 800);

  // إعدادات Excel
  static const int secretCodeColumnIndex = 3; // العمود D (0-index)
  static const int nameColumnIndex = 1;       // العمود B
  static const int idColumnIndex = 0;         // العمود A
  static const int classColumnIndex = 2;      // العمود C
  static const int firstSubjectColumnIndex = 4; // العمود E

  // ألوان المناطق
  static const Color subjectIdZoneColor = Colors.orange;
  static const Color qrZoneColor = Colors.blue;
  static const Color gradeZoneColor = Colors.green;

  // نصوص
  static const String hintPositionQR = 'ضع رمز QR داخل الإطار الأزرق';
  static const String hintPositionGrade = 'ضع الدرجة داخل الإطار الأخضر';
  static const String hintPositionSubjectId = 'ضع رقم المادة داخل الإطار البرتقالي';

  // رسائل
  static const String msgQRDuplicate = 'تم إدخال درجة هذا الطالب مسبقاً';
  static const String msgQRNotFound = 'لم يتم العثور على رمز QR';
  static const String msgStudentNotFound = 'لم يتم العثور على الطالب';
  static const String msgGradeSaved = 'تم حفظ الدرجة بنجاح';
  static const String msgReadyForNext = 'جاهز للورقة التالية';
}
