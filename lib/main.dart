import 'package:flutter/material.dart';
import 'screens/exam_generator_screen.dart'; // استيراد شاشة التوليد مباشرة

void main() {
  runApp(const ExamAutomationApp());
}

class ExamAutomationApp extends StatelessWidget {
  const ExamAutomationApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'نظام أتمتة طباعة الاختبارات',
      debugShowCheckedModeBanner: false,
      // ضبط الثيم العام للتطبيق ليتوافق مع ألوان الهوية البصرية الجديدة
      theme: ThemeData(
        primaryColor: const Color(0xff029ae4),
        scaffoldBackgroundColor: const Color(0xffeef7fe),
        fontFamily: 'Cairo', // تعيين الخط العربي الافتراضي لواجهات التطبيق
        appBarTheme: const AppBarTheme(
          backgroundColor: const Color(0xff029ae4),
          centerTitle: true,
          elevation: 2,
        ),
      ),
      // جعل شاشة توليد أوراق الاختبارات هي الشاشة الرئيسية للتطبيق
      home: const ExamGeneratorScreen(),
    );
  }
}
