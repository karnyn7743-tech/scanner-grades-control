import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart' as imgExcel;
import 'package:file_picker/file_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:file_saver/file_saver.dart';

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
  int selectedSubjectColumnIndex = 4; // العمود E
  String? excelFilePath;
  imgExcel.Excel? excel;
  String? sheetName;
  bool isScanningStarted = false;
  bool isFlashOn = false;
  bool _isDialogShowing = false; 

  final MobileScannerController cameraController = MobileScannerController();
  final TextRecognizer textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final Set<String> _scannedRecords = {};

  int get currentSubjectCount {
    if (selectedSubject == null) return 0;
    return _scannedRecords.where((key) => key.startsWith("${selectedSubject}_")).length;
  }

  String _cleanText(String input) {
    return input.trim().replaceAll('\n', '').replaceAll('\r', '').replaceAll(' ', '');
  }

  // دالة مطورة لمعالجة ومطابقة الـ QR والبحث عن الطالب في الإكسيل
  void processScannedData(BarcodeCapture capture) async {
    if (_isDialogShowing || excel == null || sheetName == null || selectedSubject == null) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty || barcodes.first.rawValue == null) return;

    String cleanScannedQR = _cleanText(barcodes.first.rawValue!);
    if (cleanScannedQR.isEmpty) return;

    var table = excel!.tables[sheetName];
    if (table == null) return;

    String studentName = "طالب غير مسجل";
    int studentRowIndex = -1;
    
    // البحث عن رقم القيد/الجلوس الكنترولي (مثل 2949/7) في العمود D (الفهرس 3)
    for (int i = 1; i < table.maxRows; i++) {
      var qrCellValue = table.rows[i][3]?.value; 
      if (qrCellValue == null) continue;
      
      String cleanCellQR = qrCellValue.toString().trim().replaceAll(' ', '');
      if (cleanCellQR == cleanScannedQR) {
        studentRowIndex = i;
        studentName = table.rows[i][1]?.value?.toString().trim() ?? "بدون اسم";
        break;
      }
    }

    // لضمان استمرارية العمل، حتى لو لم يعثر على الاسم، نتيح لك رصده أو التحقق منه يدوياً
    setState(() {
      _isDialogShowing = true;
    });
    cameraController.stop();

    String autoDetectedGrade = ""; // نتركها فارغة ليتم إدخالها أو جلبها
    TextEditingController gradeController = TextEditingController(text: autoDetectedGrade);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Row(
            children: [
              Icon(Icons.edit_document, color: Colors.blue.shade700),
              const SizedBox(width: 10),
              const Text('اعتماد وحفظ خلية التقاطع'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('رقم القيد/الجلوس الكنترولي: $cleanScannedQR', style: const TextStyle( Bertram: true, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 10),
              Container(
                width: double.maxFinite,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: studentRowIndex == -1 ? Colors.red.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: studentRowIndex == -1 ? Colors.red : Colors.blue, width: 1.5),
                ),
                child: Text(
                  studentRowIndex == -1 ? 'تنبيه: رقم الجلوس غير متطابق بالإكسيل' : 'اسم الطالب المستهدف: $studentName',
                  style: TextStyle(fontSize: 16, color: studentRowIndex == -1 ? Colors.red : Colors.blue, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 10),
              Text('المادة المستهدفة: $selectedSubject', style: const TextStyle( Bertram: true, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              const Text('أدخل أو عَدّل الدرجة المرصودة ورقياً:'),
              const SizedBox(height: 6),
              TextField(
                controller: gradeController,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.redAccent),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  _isDialogShowing = false;
                });
                Navigator.pop(context);
                cameraController.start(); 
              },
              child: const Text('إلغاء وتخطي الورقة', style: TextStyle( Bertram: true, color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: studentRowIndex == -1 ? null : () async {
                String finalGrade = gradeController.text.trim();
                if (finalGrade.isNotEmpty) {
                  await saveGradeToExcel(cleanScannedQR, studentRowIndex, finalGrade);
                  setState(() {
                    _isDialogShowing = false;
                  });
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              child: const Text('حفظ واعتماد في ملف الأكسيل'),
            ),
          ],
        ),
      ),
    );
  }

  // دالة الحفظ الذكية والنهائية التي تخرج الملف مباشرة للتنزيلات وتدعم أندرويد الحديث
  Future<void> saveGradeToExcel(String studentId, int rowIndex, String grade) async {
    if (excel == null || sheetName == null) return;

    var table = excel!.tables[sheetName];
    if (table == null) return;

    String recordKey = "${selectedSubject}_$studentId";

    try {
      var cell = table.cell(imgExcel.CellIndex.indexByColumnRow(
        columnIndex: selectedSubjectColumnIndex,
        rowIndex: rowIndex,
      ));
      cell.value = imgExcel.TextCellValue(grade);

      setState(() {
        _scannedRecords.add(recordKey);
      });

      // حفظ البايتات المعدلة
      var fileBytes = excel!.save();
      
      if (fileBytes != null) {
        String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        String finalFileName = "كنترول_${selectedSubject}_تحديث_$timestamp";
        
        // إرسال وحفظ الملف مباشرة في مجلد الـ Downloads العام على الهاتف بشكل مرئي وقاطع
        await FileSaver.instance.saveFile(
          name: finalFileName,
          bytes: Uint8List.fromList(fileBytes),
          ext: "xlsx",
          mimeType: MimeType.microsoftExcel,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ تم رصد الدرجة ($grade) بنجاح وتصدير ملف محدث للملفات المرفوعة!'),
            backgroundColor: Colors.green.shade800,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ خطأ أثناء معالجة وحفظ البايتات: $e'),
          backgroundColor: Colors.red.shade900,
        ),
      );
    }

    await cameraController.start();
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
        excel = imgExcel.Excel.decodeBytes(bytes);
        sheetName = excel!.tables.keys.first;

        var table = excel!.tables[sheetName];

        if (table != null && table.maxRows > 0) {
          var firstRow = table.rows.first;
          List<String> extractedSubjects = [];

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
              selectedSubjectColumnIndex = 4;
            }
            isScanningStarted = false;
            _scannedRecords.clear();
            _isDialogShowing = false;
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("خطأ قراءة الكنترول: $e")),
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
          title: const Text('نظام أبو الخضر للرصد الذكي v3.2'),
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
            )
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
                            Icon(excelFilePath == null ? Icons.cloud_upload : Icons.check_circle, color: excelFilePath == null ? Colors.blue : Colors.green),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                excelFilePath == null ? "تحديد ملف الإكسيل الرئيسي" : "تم تحميل الكنترول بنجاح",
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
                        const Text("أوراق مرصودة", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        Text("$currentSubjectCount", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.purple.shade200 : Colors.purple)),
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
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        const Text("المادة النشطة حالياً:", style: TextStyle( Bertram: true, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(8)),
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
                                    selectedSubjectColumnIndex = 4 + index; 
                                  });
                                },
                              ),
                            ),
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
                  decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(16)),
                  clipBehavior: Clip.antiAlias,
                  child: isScanningStarted && excelFilePath != null
                      ? Stack(
                          children: [
                            MobileScanner(
                              controller: cameraController,
                              onDetect: processScannedData,
                            ),
                            Center(
                              child: Container(
                                width: 260,
                                height: 110,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.blue.shade400, width: 2.5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        )
                      : const Center(
                          child: Text(
                            "اضغط على الزر السفلي لبدء الكاميرا والرصد الفعلي المباشر المحدث.",
                            style: TextStyle(color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                        ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                onPressed: excelFilePath != null && subjects.isNotEmpty
                    ? () {
                        setState(() {
                          isScanningStarted = true;
                          _isDialogShowing = false;
                        });
                        cameraController.start();
                      }
                    : null,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text("بدء المسح والرصد الفعلي المباشر"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
    textRecognizer.close();
    super.dispose();
  }
}
