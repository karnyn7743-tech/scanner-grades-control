import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';

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
      title: 'الأتمتة المصغرة في كنترول الإختبارات',
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
      home: const ActivationCheckScreen(), // الشاشة البادئة لفحص التفعيل
    );
  }
}

// ==========================================
// خدمة خوارزمية التفعيل الدائم المعتمدة على Device ID
// ==========================================
class ActivationService {
  static const String _secretSalt = "STUGRA_SCAN_SECRET_KEY_2026";

  // الحصول على معرف الجهاز الفريد
  static Future<String> getDeviceId() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id; // Android ID الفريد للجهاز
    } else if (Platform.isIOS) {
      IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
      return iosInfo.identifierForVendor ?? "UNKNOWN_DEVICE";
    }
    return "UNKNOWN_DEVICE";
  }

  // خوارزمية توليد كود التفعيل الصحيح بناءً على معرف الجهاز
  static String generateActivationCode(String deviceId) {
    var bytes = utf8.encode(deviceId + _secretSalt);
    var digest = sha256.convert(bytes).toString().toUpperCase();
    
    // تنسيق كود التفعيل ليصبح بالشكل: STUG-XXXX-YYYY
    String part1 = digest.substring(0, 4);
    String part2 = digest.substring(4, 8);
    return "STUG-$part1-$part2";
  }

  // التحقق من صحة حالة التفعيل المسجلة
  static Future<bool> isActivated() async {
    final prefs = await SharedPreferences.getInstance();
    bool activated = prefs.getBool('is_activated') ?? false;
    if (!activated) return false;

    String? savedCode = prefs.getString('activation_code');
    String deviceId = await getDeviceId();
    String expectedCode = generateActivationCode(deviceId);

    return savedCode == expectedCode;
  }

  // حفظ التفعيل دائمياً
  static Future<bool> saveActivation(String code) async {
    String deviceId = await getDeviceId();
    String expectedCode = generateActivationCode(deviceId);

    if (code.trim().toUpperCase() == expectedCode) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_activated', true);
      await prefs.setString('activation_code', expectedCode);
      return true;
    }
    return false;
  }
}

// ==========================================
// شاشة الفحص والتفعيل الأولية
// ==========================================
class ActivationCheckScreen extends StatefulWidget {
  const ActivationCheckScreen({super.key});

  @override
  State<ActivationCheckScreen> createState() => _ActivationCheckScreenState();
}

class _ActivationCheckScreenState extends State<ActivationCheckScreen> {
  bool _isLoading = true;
  bool _isActivated = false;
  String _deviceId = "";
  final TextEditingController _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    String devId = await ActivationService.getDeviceId();
    bool active = await ActivationService.isActivated();
    
    setState(() {
      _deviceId = devId;
      _isActivated = active;
      _isLoading = false;
    });
  }

  void _verifyAndActivate() async {
    if (_codeController.text.trim().isEmpty) return;

    bool success = await ActivationService.saveActivation(_codeController.text);
    if (success) {
      setState(() {
        _isActivated = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("🎉 تم تفعيل التطبيق بنجاح ومدى الحياة!")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ كود التفعيل غير صحيح لهذا الجهاز!")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // إذا كان الجهاز مفعلاً، يتم فتح الصفحة الرئيسية التي تحتوي على الشاشات الثلاث مباشرة
    if (_isActivated) {
      return HomeScreen(); 
    }

    // واجهة شاشة قفل التفعيل
    return Scaffold(
      backgroundColor: const Color(0xFF1E1B18),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.security, size: 80, color: Colors.blueAccent),
                const SizedBox(height: 16),
                const Text(
                  "تفعيل تطبيق كنترول الاختبارات",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  "التطبيق محمي. يرجى نسخ معرف الجهاز التالي وإرساله لإصدار كود التفعيل الخاص بك:",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 20),
                
                // عرض معرف الجهاز
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blueAccent.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _deviceId,
                          style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, color: Colors.white70),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _deviceId));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("تم نسخ معرف الجهاز")),
                          );
                        },
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // حقل إدخال كود التفعيل
                TextField(
                  controller: _codeController,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 2),
                  decoration: InputDecoration(
                    hintText: "STUG-XXXX-YYYY",
                    hintStyle: const TextStyle(color: Colors.white30, letterSpacing: 1),
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.blueAccent),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _verifyAndActivate,
                  child: const Text("تفعيل التطبيق الآن", style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
