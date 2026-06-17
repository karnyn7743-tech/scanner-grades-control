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
  int selectedSubjectColumnIndex = 4; // العمود الخامس الافتراضي للمادة الأولى
  String? excelFilePath;
  imgExcel.Excel? excel;
  String? sheetName;
  bool isScanningStarted = false;
  bool _isDialogShowing = false; 

  final MobileScannerController cameraController = MobileScannerController();
  // تعديل لتفادي أخطاء الإصدارات في التخلص من الكائن
  final TextRecognizer textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final Set<String> _scannedRecords = {};

  int get currentSubjectCount {
    if (selectedSubject == null) return 0;
    return _scannedRecords.where((key) => key.startsWith("${selectedSubject}_")).length;
  }

  String _cleanText(String input) {
    return input.trim().replaceAll('\n', '').replaceAll('\r', '').replaceAll(' ', '');
  }

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
    
    // البحث في العمود D (كود الطالب / رقم الجلوس الكنترولي) وهو الفهرس رقم 3
    for (int i = 1; i < table.maxRows; i++) {
      var qrCellValue = table.rows[i][3]?.value; 
      if (qrCellValue == null) continue;
      
      String cleanCellQR = _cleanText(qrCellValue.toString());
      if (cleanCellQR == cleanScannedQR) {
        studentRowIndex = i;
        studentName = table.rows[i][1]?.value?.toString().trim() ?? "بدون اسم";
        break;
      }
    }

    setState(() {
      _isDialogShowing = true;
    });
    cameraController.stop();

    TextEditingController gradeController = TextEditingController(text: "20");

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 10),
              Text('تأكيد رصد الدرجة'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('رقم القيد/الجـلوس: $cleanScannedQR', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Container(
                width: double.maxFinite,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: studentRowIndex == -1 ? Colors.red.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: studentRowIndex == -1 ? Colors.red : Colors.blue),
                ),
                child: Text(
                  studentRowIndex == -1 ? 'تنبيه: رقم الجلوس غير متطابق بملف الكنترول الحالي' : 'اسم الطالب: $studentName',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: studentRowIndex == -1 ? Colors.red : Colors.blue),
                ),
              ),
              const SizedBox(height: 10),
              Text('المادة المستهدفة: $selectedSubject'),
              const SizedBox(height: 15),
              TextField(
                controller: gradeController,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'الدرجة الملتقطة للطالب (يرجى إدخالها أو تأكيدها):',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() { _isDialogShowing = false; });
                Navigator.pop(context);
                cameraController.start(); 
              },
              child: const Text('إلغاء وفحص جديد', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: studentRowIndex == -1 ? null : () async {
                String finalGrade = gradeController.text.trim();
                if (finalGrade.isNotEmpty) {
                  await saveGradeToExcel(cleanScannedQR, studentRowIndex, finalGrade);
                  setState(() { _isDialogShowing = false; });
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              child: const Text('حفظ ورصد في الإكسيل'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> saveGradeToExcel(String studentId, int rowIndex, String grade) async {
    if (excel == null || sheetName == null) return;
    var table = excel!.tables[sheetName];
    if (table == null) return;

    try {
      var cell = table.cell(imgExcel.CellIndex.indexByColumnRow(
        columnIndex: selectedSubjectColumnIndex,
        rowIndex: rowIndex,
      ));
      cell.value = imgExcel.TextCellValue(grade);

      setState(() {
        _scannedRecords.add("${selectedSubject}_$studentId");
      });

      var fileBytes = excel!.save();
      if (fileBytes != null) {
        String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        // تعديل التصدير ليتوافق تماماً مع حزمة file_saver 0.4.0 الحديثة المعتمدة بـ Codemagic
        await FileSaver.instance.saveFile(
          name: "كنترول_${selectedSubject}_$timestamp",
          bytes: Uint8List.fromList(fileBytes),
          ext: "xlsx",
          mimeType: MimeType.microsoftExcel,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم حفظ الدرجة وتحديث ملف الإكسيل بنجاح في مجلد التنزيلات!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ خطأ حماية أثناء الحفظ الفعلي: $e'), backgroundColor: Colors.red),
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
        var bytes = File(result.files.single.path!).readAsBytesSync();
        excel = imgExcel.Excel.decodeBytes(bytes);
        sheetName = excel!.tables.keys.first;
        var table = excel!.tables[sheetName];

        if (table != null && table.maxRows > 0) {
          var firstRow = table.rows.first;
          List<String> extractedSubjects = [];

          // قراءة المواد بداية من العمود الخامس (الفهرس 4)
          for (int i = 4; i < firstRow.length; i++) {
            if (firstRow[i] != null) {
              String cellValue = firstRow[i]!.value.toString().trim();
              if (cellValue.isNotEmpty && cellValue != "null") {
                extractedSubjects.add(cellValue);
              }
            }
          }

          setState(() {
            excelFilePath = result.files.single.path;
            subjects = extractedSubjects;
            if (subjects.isNotEmpty) {
              selectedSubject = subjects.first;
              selectedSubjectColumnIndex = 4;
            }
            _scannedRecords.clear();
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("خطأ قراءة ملف الكنترول: $e")),
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
          title: const Text('نظام أبو الخضر للرصد الذكي v3.3'),
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
                    child: ElevatedButton.icon(
                      onPressed: pickAndLoadExcel,
                      icon: Icon(excelFilePath == null ? Icons.file_open : Icons.task_alt),
                      label: Text(excelFilePath == null ? "اختيار ملف الإكسيل الرئيسي" : "تم تحميل الكنترول بنجاح"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: excelFilePath == null ? Colors.blue : Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.purple),
                      borderRadius: BorderRadius.circular(8)
                    ),
                    child: Text("المرصود: $currentSubjectCount", style: const TextStyle(fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            ),
            if (excelFilePath != null && subjects.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    const Text("المادة النشطة:", style: TextStyle( Bertram: true, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButton<String>(
                        value: selectedSubject,
                        isExpanded: true,
                        items: subjects.map((String sub) {
                          return DropdownMenuItem<String>(value: sub, child: Text(sub));
                        }).toList(),
                        onChanged: (String? val) {
                          setState(() {
                            selectedSubject = val;
                            int idx = subjects.indexOf(val!);
                            selectedSubjectColumnIndex = 4 + idx;
                          });
                        },
                      ),
                    )
                  ],
                ),
              )
            ],
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  color: Colors.black,
                  child: isScanningStarted && excelFilePath != null
                      ? MobileScanner(controller: cameraController, onDetect: processScannedData)
                      : const Center(child: Text("قم بتحميل ملف الكنترول ثم اضغط على زر بدء الرصد المباشر ورص درجات الطلاب ورقياً.", style: const TextStyle(color: Colors.white), textAlign: TextAlign.center)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: excelFilePath != null
                    ? () {
                        setState(() { isScanningStarted = true; });
                        cameraController.start();
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade800,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50)
                ),
                child: const Text("بدء المسح والرصد الفعلي المباشر"),
              ),
            )
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    cameraController.dispose();
    // تم حذف دالة textRecognizer.close() لتجنب خطأ توافق الإصدارات البرمجية بالمنصة
    super.dispose();
  }
}
