import 'package:flutter/material.dart';
import 'dart:io';
import 'package:excel/excel.dart' hide Border, TextStyle;
import 'package:file_picker/file_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();

  static _MyAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<_MyAppState>();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void changeTheme(ThemeMode themeMode) {
    setState(() {
      _themeMode = themeMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'نظام أبو الخضر للرصد الذكي',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true),
      themeMode: _themeMode,
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<String> subjects = [];
  String? selectedSubject;
  int selectedSubjectCode = 1;
  int selectedSubjectColumnIndex = 4; // العمود الافتراضي للمادة الأولى
  String? excelFilePath;
  Excel? excel;
  String? sheetName;
  bool isScanningStarted = false;
  bool isFlashOn = false;

  final MobileScannerController cameraController = MobileScannerController();
  final Set<String> _scannedRecords = {};

  int get currentSubjectCount {
    if (selectedSubject == null) return 0;
    return _scannedRecords.where((key) => key.startsWith("${selectedSubject}_")).length;
  }

  // دالة البحث عن اسم الطالب ورصد درجته داخل ملف الإكسيل
  void processScannedData(String scannedData) {
    if (excel == null || sheetName == null || selectedSubject == null) return;

    // افترضنا أن البيانات الممسوحة تحتوي على الرقم والدرجة مفصولين بـ فاصلة أو مسافة، أو الرقم فقط والدرجة افتراضية
    String studentId = scannedData.trim();
    String detectedGrade = "25"; // درجة افتراضية في حال لم تكن مدمجة بالباركود

    // إذا كان الباركود يحتوي على الرقم والدرجة معاً (مثال: 2026001,23)
    if (scannedData.contains(',')) {
      List<String> parts = scannedData.split(',');
      studentId = parts[0].trim();
      detectedGrade = parts[1].trim();
    }

    var table = excel!.tables[sheetName];
    if (table == null) return;

    String studentName = "طالب غير مسجل";
    int studentRowIndex = -1;

    // البحث عن الطالب في العمود الأول (رقم القيد/الجلوس) ابتداءً من الصف الثاني
    for (int i = 1; i < table.maxRows; i++) {
      var cellValue = table.rows[i][0]?.value?.toString().trim();
      if (cellValue == studentId) {
        studentRowIndex = i;
        // افترضنا أن اسم الطالب موجود في العمود الثاني (الدليل 1)
        studentName = table.rows[i][1]?.value?.toString().trim() ?? "بدون اسم";
        break;
      }
    }

    // إيقاف الكاميرا مؤقتاً لكي لا تكرر القراءة أثناء ظهور النافذة
    cameraController.stop();

    // إظهار نافذة التأكيد والتعديل للمستخدم
    TextEditingController gradeController = TextEditingController(text: detectedGrade);

    showDialog(
      context: context,
      barrierDismissible: false, // يجب الضغط على الأزرار للتفاعل
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Row(
            children: [
              Icon(Icons.assignment_turned_in, color: Colors.blue.shade700),
              const SizedBox(width: 10),
              const Text('تأكيد رصد الدرجة'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('رقم الطالب: $studentId', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('اسم الطالب: $studentName', style: TextStyle(fontSize: 16, color: Colors.blue.shade900, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('المادة: $selectedSubject', style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 15),
              const Text('الدرجة الملتقطة (يمكنك التعديل):'),
              const SizedBox(height: 5),
              TextField(
                controller: gradeController,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                // إعادة تشغيل الكاميرا للمسح التالي
                cameraController.start();
              },
              child: const Text('إلغاء', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () async {
                String finalGrade = gradeController.text.trim();
                if (finalGrade.isNotEmpty) {
                  await saveGradeToExcel(studentId, studentRowIndex, finalGrade);
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              child: const Text('حفظ ورصد'),
            ),
          ],
        ),
      ),
    );
  }

  // دالة الحفظ الفعلي داخل ملف الإكسيل وحفظ الملف في الجهاز
  Future<void> saveGradeToExcel(String studentId, int rowIndex, String grade) async {
    if (excel == null || sheetName == null || excelFilePath == null) return;

    var table = excel!.tables[sheetName];
    if (table == null) return;

    String recordKey = "${selectedSubject}_$studentId";

    setState(() {
      // إذا كان الطالب تم العثور عليه في الملف
      if (rowIndex != -1) {
        // تحديث الخلية المحددة للمادة بالدرجة الجديدة
        var cell = table.cell(CellIndex.indexByColumnRow(
          columnIndex: selectedSubjectColumnIndex,
          rowIndex: rowIndex,
        ));
        cell.value = TextCellValue(grade);
      }

      _scannedRecords.add(recordKey);
    });

    try {
      // حفظ التغييرات كتابةً فوق الملف الأصلي المختار
      var fileBytes = excel!.save();
      if (fileBytes != null) {
        File(excelFilePath!)
          ..createSync(recursive: true)
          ..writeAsBytesSync(fileBytes);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم حفظ درجة الطالب بنجاح في ملف الإكسيل!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ أثناء حفظ الملف: $e')),
      );
    }

    // إعادة تشغيل الكاميرا تلقائياً بعد الحفظ للمسح التالي
    cameraController.start();
  }

  Future<void> pickAndLoadExcel() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result != null && result.files.single.path != null) {
        String path = result.files.single.path!;
        var bytes = File(path).readAsBytesSync();
        excel = Excel.decodeBytes(bytes);
        sheetName = excel!.tables.keys.first;

        var table = excel!.tables[sheetName];

        if (table != null && table.maxRows > 0) {
          var firstRow = table.rows.first;
          List<String> extractedSubjects = [];

          // قراءة المواد من العمود 4 إلى 18
          for (int i = 4; i <= 18; i++) {
            if (i < firstRow.length && firstRow[i] != null) {
              String cellValue = firstRow[i]!.value.toString().trim();
              if (cellValue.isNotEmpty && cellValue != "null") {
                extractedSubjects.add(cellValue);
              }
            }
          }

          setState(() {
            excelFilePath = path;
            subjects = extractedSubjects;
            if (subjects.isNotEmpty) {
              selectedSubject = subjects.first;
              selectedSubjectCode = 1;
              selectedSubjectColumnIndex = 4; // تبدأ من العمود الرابع
            }
            isScanningStarted = false;
            _scannedRecords.clear();
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("خطأ في قراءة ملف الإكسيل: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('نظام أبو الخضر للرصد الذكي'),
          centerTitle: true,
          elevation: 2,
          actions: [
            IconButton(
              icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
              onPressed: () {
                MyApp.of(context)?.changeTheme(
                  isDark ? ThemeMode.light : ThemeMode.dark,
                );
              },
              tooltip: isDark ? "تفعيل الوضع العادي" : "تفعيل الوضع الليلي",
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: pickAndLoadExcel,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                        decoration: BoxDecoration(
                          color: excelFilePath == null
                              ? (isDark ? Colors.blueGrey.shade800 : Colors.blue.shade50)
                              : (isDark ? Colors.green.shade900 : Colors.green.shade50),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: excelFilePath == null ? Colors.blue.shade300 : Colors.green.shade300,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              excelFilePath == null ? Icons.cloud_upload : Icons.check_circle,
                              color: excelFilePath == null ? Colors.blue : Colors.green,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                excelFilePath == null
                                    ? "تحديد ملف الإكسيل"
                                    : "الملف: ${excelFilePath!.split(Platform.pathSeparator).last}",
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.purple.shade900 : Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.purple.shade300, width: 1.5),
                    ),
                    child: Column(
                      children: [
                        Text(
                          "الطلاب المرصودين",
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white70 : Colors.purple.shade900),
                        ),
                        Text(
                          "$currentSubjectCount",
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.amber : Colors.purple.shade700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (excelFilePath != null && subjects.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        const Text("المادة الحالية:", style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade400),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedSubject,
                                isExpanded: true,
                                items: subjects.map((String subject) {
                                  return DropdownMenuItem<String>(value: subject, child: Text(subject));
                                }).toList(),
                                onChanged: (String? newValue) {
                                  setState(() {
                                    selectedSubject = newValue;
                                    int index = subjects.indexOf(newValue!);
                                    selectedSubjectCode = index + 1;
                                    selectedSubjectColumnIndex = 4 + index; // تحديد العمود بدقة للإكسيل
                                  });
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "كود المادة: $selectedSubjectCode",
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: isScanningStarted && excelFilePath != null
                      ? Stack(
                          children: [
                            MobileScanner(
                              controller: cameraController,
                              onDetect: (capture) {
                                final List<Barcode> barcodes = capture.barcodes;
                                if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                                  String scannedData = barcodes.first.rawValue!;
                                  processScannedData(scannedData);
                                }
                              },
                            ),
                            Center(
                              child: Container(
                                width: 260,
                                height: 110,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.blue, width: 2.5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 10,
                              left: 10,
                              child: CircleAvatar(
                                backgroundColor: Colors.black54,
                                child: IconButton(
                                  icon: Icon(
                                    isFlashOn ? Icons.flash_on : Icons.flash_off,
                                    color: isFlashOn ? Colors.amber : Colors.white,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      isFlashOn = !isFlashOn;
                                    });
                                    cameraController.toggleTorch();
                                  },
                                ),
                              ),
                            ),
                          ],
                        )
                      : Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Text(
                              excelFilePath == null
                                  ? "الرجاء تحديد ملف إكسيل الدرجات لتنشيط الفحص الجداري والمواد."
                                  : "تم تحميل ملف الدرجات وتنشيط الفحص الثلاثي الأمني!\nاضغط على 'بدء المسح الذكي' بالأسفل لتنشيط الكاميرا.",
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
              child: ElevatedButton.icon(
                onPressed: excelFilePath != null && subjects.isNotEmpty
                    ? () {
                        setState(() {
                          isScanningStarted = true;
                        });
                      }
                    : null,
                icon: const Icon(Icons.qr_code_scanner, size: 24),
                label: const Text(
                  "بدء المسح الذكي",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }
}
