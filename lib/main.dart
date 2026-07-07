import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'screens/home_screen.dart';

void main() async {
  // تأكد من تهيئة Flutter قبل أي شيء
  WidgetsFlutterBinding.ensureInitialized();

  // طلب الأذونات مع معالجة الأخطاء (لمنع انهيار التطبيق)
  try {
    await [
      Permission.camera,
      Permission.storage,
      Permission.manageExternalStorage,
    ].request();
  } catch (e) {
    // إذا فشل طلب الأذونات، نستمر في التشغيل (قد يطلبها المستخدم لاحقاً)
    print('خطأ في طلب الأذونات: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'نظام إدخال الدرجات',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        fontFamily: 'Cairo',
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      ),
      // الاتجاه من اليمين لليسار لدعم اللغة العربية
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      home: HomeScreen(),
    );
  }
}
