import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'screens/home_screen.dart'; // استيراد الشاشة الرئيسية المستقلة الجديدة

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // طلب صلاحيات الوصول إلى الذاكرة والتخزين عند بدء التشغيل
  await _requestPermissions();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'صانع أوراق الاختبارات',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterialDesign: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const HomeScreen(), // توجيه التطبيق ليفتح مباشرة على واجهة التوليد المرنة
    );
  }
}

// دالة فحص وتأكيد الصلاحيات لضمان حفظ الـ PDF بدون قيود النظام
Future<void> _requestPermissions() async {
  var status = await Permission.storage.status;
  if (!status.isGranted) {
    await Permission.storage.request();
  }
}
