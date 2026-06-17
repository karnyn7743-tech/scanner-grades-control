import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart' as imgExcel;
import 'package:file_picker/file_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
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
      title: 'نظام أبو الخضر للرصد الثنائي المستقر',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.light),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark),
      ),
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
  int selectedSubjectColumnIndex = 4;
  String? excelFilePath;
  imgExcel.Excel? excel;
  String? sheetName;

  bool _isDialogShowing = false;
  final Set<String> _scannedRecords = {};

  final MobileScannerController cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  String currentStudentQR = "";
  String currentStudentName = "طالب غير مسجل";
  int currentStudentRowIndex = -1;

  final TextEditingController gradeController = TextEditingController();

  int get currentSubjectCount {
    if (selectedSubject == null) return 0;
    return _scannedRecords.where((key) => key.startsWith("${selectedSubject}_")).length;
  }

  String _cleanText(String input) {
    return input.trim().replaceAll('\n', '').replaceAll('\r', '').replaceAll(' ', '');
  }

  // الكاميرا الرئيسية مستمرة دائماً ولا تتوقف، مما يمنع تعليق الشاشة السوداء نهائياً
  void onCameraDetectHandler(BarcodeCapture capture) {
    if (_isDialogShowing || excel == null || sheetName == null || selectedSubject == null) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty || barcodes.first.rawValue == null) return;

    String cleanScannedQR = _cleanText(barcodes.first.rawValue!);
    if (cleanScannedQR.isEmpty) return;

    var table = excel!.tables[sheetName];
    if (table == null) return;

    String studentName = "طالب غير مسجل";
    int studentRowIndex = -1;

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
      currentStudentQR = cleanScannedQR;
      currentStudentName = studentName;
      currentStudentRowIndex = studentRowIndex;
      gradeController.clear();
    });

    showConfirmationDialog();
  }

  void showConfirmationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.person_search_rounded, color: Colors.blue, size: 28),
                const SizedBox(width: 10),
                const Text('بيانات الطالب المقروءة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('رقم الجلوس (QR): ', style: TextStyle(color: Colors.grey)),
                      Text(currentStudentQR, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.maxFinite,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: currentStudentRowIndex == -1 ? Colors.red.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: currentStudentRowIndex == -1 ? Colors.red.shade400 : Colors.blue.shade400,
                        width: 1.2
                      ),
                    ),
                    child: Text(
                      currentStudentRowIndex == -1 ? '🚨 رقم الجلوس هذا غير مدرج في كشف الإكسيل!' : '👤 الاسم: $currentStudentName',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: currentStudentRowIndex == -1 ? Colors.red.shade700 : Colors.blue.shade800
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  const Text('أدخل درجة الطالب الحالية:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: gradeController,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.redAccent),
                    decoration: InputDecoration(
                      hintText: '0',
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _isDialogShowing = false;
                  });
                  Navigator.pop(context);
                },
                child: const Text('إلغاء وتخطي', style: TextStyle(color: Colors.red)),
              ),
              ElevatedButton.icon(
                onPressed: currentStudentRowIndex == -1 ? null : () async {
                  String enteredGrade = gradeController.text.trim();
                  if (enteredGrade.isNotEmpty) {
                    Navigator.pop(context);
                    await saveGradeToExcel(currentStudentQR, currentStudentRowIndex, enteredGrade);
                  }
                },
                icon: const Icon(Icons.save_rounded),
                label: const Text('اعتماد وحفظ سريع'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> saveGradeToExcel(String studentId, int rowIndex, String grade) async {
    if (excel == null || sheetName == null) return;
    var table = excel!.tables[sheetName];
    if (table == null) return;

    try {
      // 1. تحديث الجدول في الذاكرة الحية للمشروع لضمان دقة الرصد التراكمي
      var cell = table.cell(imgExcel.CellIndex.indexByColumnRow(
        columnIndex: selectedSubjectColumnIndex,
        rowIndex: rowIndex,
      ));
      cell.value = imgExcel.TextCellValue(grade);

      setState(() {
        _scannedRecords.add("${selectedSubject}_$studentId");
      });

      // 2. آلية الحفظ المتوافقة 100% مع إصدار file_saver: ^0.4.0 الحديث والمكتوب بمشروعك
      var fileBytes = excel!.save();
      if (fileBytes != null) {
        String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        // دمج الامتداد داخل الاسم مباشرة لحل مشكلة البناء الفاشل في السيرفر
        String fullFileName = "control_${selectedSubject}_update_$timestamp.xlsx";
        
        await FileSaver.instance.saveFile(
          name: fullFileName,
          bytes: Uint8List.fromList(fileBytes),
          mimeType: MimeType.other, 
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ تم رصد الدرجة ($grade) للطالب بنجاح وتم حفظ نسخة محدثة!'),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ حدث خطأ أثناء عملية الحفظ الفعلي: $e'), backgroundColor: Colors.red)
      );
    }

    // إعادة الكاميرا فوراً وبشكل تلقائي للعمل المستمر دون تعليق
    setState(() {
      _isDialogShowing = false;
    });
  }

  Future<void> pickAndLoadExcel() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom, 
        allowedExtensions: ['xlsx', 'xls']
      );
      if (result != null && result.files.single.path != null) {
        var bytes = File(result.files.single.path!).readAsBytesSync();
        excel = imgExcel.Excel.decodeBytes(bytes);
        sheetName = excel!.tables.keys.first;
        var table = excel!.tables[sheetName];

        if (table != null && table.maxRows > 0) {
          var firstRow = table.rows.first;
          List<String> extractedSubjects = [];

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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ قراءة ملف الكنترول: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('نظام أبو الخضر للرصد المستقر v5.2', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          centerTitle: true,
          elevation: 2,
          actions: [
            IconButton(
              icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
              onPressed: () {
                MyApp.of(context)?.changeTheme(isDark ? ThemeMode.light : ThemeMode.dark);
              },
            )
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: pickAndLoadExcel,
                      icon: Icon(excelFilePath == null ? Icons.file_present_rounded : Icons.task_alt_rounded),
                      label: Text(excelFilePath == null ? "اختيار ملف الإكسيل الرئيسي" : "تم تحميل الكنترول بنجاح"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: excelFilePath == null ? Colors.blue.shade600 : Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.purple.withOpacity(0.2) : Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.purple.shade300, width: 1.2),
                    ),
                    child: Column(
                      children: [
                        const Text("المرصود", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.purple)),
                        Text("$currentSubjectCount", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.purple)),
                      ],
                    ),
                  )
                ],
              ),
            ),
            if (excelFilePath != null && subjects.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 2),
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: Colors.grey.withOpacity(0.3))
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.menu_book_rounded, color: Colors.blue, size: 20),
                        const SizedBox(width: 8),
                        const Text("المادة النشطة:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedSubject,
                            decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.zero),
                            isExpanded: true,
                            items: subjects.map((String sub) {
                              return DropdownMenuItem<String>(value: sub, child: Text(sub, style: const TextStyle(fontSize: 13)));
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
                  ),
                ),
              )
            ],
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade800, width: 2),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: excelFilePath != null
                      ? MobileScanner(
                          controller: cameraController, 
                          onDetect: onCameraDetectHandler
                        )
                      : const Center(
                          child: Text(
                            "الرجاء تحديد ملف الكنترول أولاً لبدء تشغيل الكاميرا التلقائية والمستمرة.",
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ),
                ),
              ),
            ),
            if (excelFilePath != null)
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue.withOpacity(0.3))
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.refresh, color: Colors.blue, size: 18),
                      SizedBox(width: 8),
                      Text("وجه الكاميرا لـ QR الطالب، سيفتح حقل رصد الدرجة مباشرة ومستمر بدون انقطاع.", style: TextStyle(fontSize: 11, color: Colors.blue)),
                    ],
                  ),
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
    super.dispose();
  }
}
