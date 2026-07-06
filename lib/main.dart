import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'screens/exam_generator_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // طلب الأذونات عند بدء التشغيل
  await _requestPermissions();
  runApp(const MyApp());
}

Future<void> _requestPermissions() async {
  try {
    var status = await Permission.storage.request();
    if (!status.isGranted) {
      print('⚠️ لم يتم منح إذن التخزين');
    } else {
      print('✅ تم منح إذن التخزين');
    }
  } catch (e) {
    print('❌ خطأ في طلب الأذونات: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scanner Grades Control',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const ExamGeneratorScreen(),
    );
  }
}
