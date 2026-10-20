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
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await [
      Permission.camera,
      Permission.storage,
      Permission.manageExternalStorage,
    ].request();
  } catch (e) {
    debugPrint('خطأ في طلب الأذونات: $e');
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
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      home: const ActivationCheckScreen(),
    );
  }
}

// ==========================================
// خدمة خوارزمية التفعيل الدائم والتجريبي المعتمدة على Device ID
// ==========================================
class ActivationService {
  static const String _secretSaltPermanent = "STUGRA_SCAN_SECRET_KEY_2026";
  static const String _secretSaltTrial = "STUGRA_TRIAL_KEY_2026";

  // الحصول على معرف الجهاز الفريد
  static Future<String> getDeviceId() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id;
    } else if (Platform.isIOS) {
      IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
      return iosInfo.identifierForVendor ?? "UNKNOWN_DEVICE";
    }
    return "UNKNOWN_DEVICE";
  }

  // توليد كود التفعيل الدائم: STUG-XXXX-YYYY
  static String generatePermanentCode(String deviceId) {
    var bytes = utf8.encode(deviceId + _secretSaltPermanent);
    var digest = sha256.convert(bytes).toString().toUpperCase();
    String part1 = digest.substring(0, 4);
    String part2 = digest.substring(4, 8);
    return "STUG-$part1-$part2";
  }

  // توليد كود التجربة ليوم واحد: TRIAL-XXXX-YYYY
  static String generateTrialCode(String deviceId) {
    var bytes = utf8.encode(deviceId + _secretSaltTrial);
    var digest = sha256.convert(bytes).toString().toUpperCase();
    String part1 = digest.substring(0, 4);
    String part2 = digest.substring(4, 8);
    return "TRIAL-$part1-$part2";
  }

  // التحقق من صلاحية التشغيل الحالية (دائم أو تجريبي ساري المفعول)
  static Future<bool> isActivated() async {
    final prefs = await SharedPreferences.getInstance();
    bool activated = prefs.getBool('is_activated') ?? false;
    if (!activated) return false;

    bool isTrial = prefs.getBool('is_trial') ?? false;
    String? savedCode = prefs.getString('activation_code');
    String deviceId = await getDeviceId();

    // 1. فحص التفعيل الدائم
    if (!isTrial) {
      String expectedPermanent = generatePermanentCode(deviceId);
      return savedCode == expectedPermanent;
    }

    // 2. فحص النسخة التجريبية (24 ساعة)
    String expectedTrial = generateTrialCode(deviceId);
    if (savedCode != expectedTrial) {
      await _expireTrial(prefs);
      return false;
    }

    int? startTime = prefs.getInt('trial_start_time');
    int? lastCheckTime = prefs.getInt('trial_last_check_time');
    int now = DateTime.now().millisecondsSinceEpoch;

    if (startTime == null || lastCheckTime == null) {
      await _expireTrial(prefs);
      return false;
    }

    // حماية ضد التلاعب بتقديم أو تأخير ساعة الهاتف
    if (now < lastCheckTime) {
      await _expireTrial(prefs);
      return false;
    }

    // انتهاء مدة الـ 24 ساعة (24 * 60 * 60 * 1000 مللي ثانية)
    const int trialDuration = 24 * 60 * 60 * 1000;
    if (now - startTime > trialDuration) {
      await _expireTrial(prefs);
      return false;
    }

    // تحديث آخر وقت استخدام بنجاح
    await prefs.setInt('trial_last_check_time', now);
    return true;
  }

  // حفظ ومعالجة الكود المدخل
  static Future<String> saveActivation(String code) async {
    final cleanCode = code.trim().toUpperCase();
    String deviceId = await getDeviceId();
    final prefs = await SharedPreferences.getInstance();

    // التحقق أولاً من المفتاح الدائم
    String expectedPermanent = generatePermanentCode(deviceId);
    if (cleanCode == expectedPermanent) {
      await prefs.setBool('is_activated', true);
      await prefs.setBool('is_trial', false);
      await prefs.setString('activation_code', cleanCode);
      return "SUCCESS_PERMANENT";
    }

    // التحقق من مفتاح التجربة
    String expectedTrial = generateTrialCode(deviceId);
    if (cleanCode == expectedTrial) {
      // منع استخدام التجربة مرة أخرى لنفس الجهاز إذا انتهت سابقاً
      bool trialUsedBefore = prefs.getBool('trial_used_before') ?? false;
      if (trialUsedBefore) {
        return "TRIAL_ALREADY_USED";
      }

      int now = DateTime.now().millisecondsSinceEpoch;
      await prefs.setBool('is_activated', true);
      await prefs.setBool('is_trial', true);
      await prefs.setBool('trial_used_before', true);
      await prefs.setString('activation_code', cleanCode);
      await prefs.setInt('trial_start_time', now);
      await prefs.setInt('trial_last_check_time', now);
      return "SUCCESS_TRIAL";
    }

    return "INVALID_CODE";
  }

  static Future<void> _expireTrial(SharedPreferences prefs) async {
    await prefs.setBool('is_activated', false);
    await prefs.remove('activation_code');
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
    String input = _codeController.text.trim();
    if (input.isEmpty) return;

    String result = await ActivationService.saveActivation(input);

    if (result == "SUCCESS_PERMANENT") {
      setState(() {
        _isActivated = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("🎉 تم تفعيل التطبيق بنجاح ومدى الحياة!")),
      );
    } else if (result == "SUCCESS_TRIAL") {
      setState(() {
        _isActivated = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⏳ تم تفعيل النسخة التجريبية بنجاح لمدة 24 ساعة.")),
      );
    } else if (result == "TRIAL_ALREADY_USED") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ لقد تم استنفاد فترة التجربة لهذا الجهاز سابقاً. يرجى إدخال كود التفعيل الدائم.")),
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

    if (_isActivated) {
      return const HomeScreen();
    }

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
                  "التطبيق محمي. يرجى نسخ معرف الجهاز التالي وإرساله لإصدار كود التفعيل أو كود التجربة:",
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
                    hintText: "STUG-XXXX-YYYY أو TRIAL-XXXX-YYYY",
                    hintStyle: const TextStyle(color: Colors.white30, letterSpacing: 1, fontSize: 14),
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
                  child: const Text("تأكيد التفعيل", style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
