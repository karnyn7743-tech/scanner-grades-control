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
      title: 'نظام أبو الخضر للرصد الذكي',
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
  int selectedSubjectCode = 1;
  int selectedSubjectColumnIndex = 4; 
  String? excelFilePath;
  imgExcel.Excel? excel;
  String? sheetName;
  bool isScanningStarted = false;
  bool _isDialogShowing = false; 

  final MobileScannerController cameraController = MobileScannerController();
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
      builder: (context) {
        final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.fact_check_rounded, color: Colors.blue.shade700, size: 28),
                const SizedBox(width: 10),
                const Text('تأكيد رصد الدرجة الكنترولية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('رقم القيد/الجلوس: ', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                      Text(cleanScannedQR, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.maxFinite,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: studentRowIndex == -1 ? Colors.red.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: studentRowIndex == -1 ? Colors.red.shade400 : Colors.blue.shade400,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      studentRowIndex == -1 ? '🚨 تنبيه: رقم الجلوس غير متطابق بملف الكنترول' : '👤 اسم الطالب: $studentName',
                      style: TextStyle(
                        fontSize: 15, 
                        fontWeight: FontWeight.bold, 
                        color: studentRowIndex == -1 ? Colors.red.shade700 : Colors.blue.shade800
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('المادة النشطة: ', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                      Text(selectedSubject ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('الدرجة المرصودة ورقياً:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: gradeController,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.redAccent),
                    decoration: InputDecoration(
                      hintText: 'أدخل الدرجة',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.blue, width: 2)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setState(() { _isDialogShowing = false; });
                  Navigator.pop(context);
                  cameraController.start(); 
                },
                child: const Text('إلغاء وتخطي الورقة', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ),
              ElevatedButton.icon(
                onPressed: studentRowIndex == -1 ? null : () async {
                  String finalGrade = gradeController.text.trim();
                  if (finalGrade.isNotEmpty) {
                    await saveGradeToExcel(cleanScannedQR, studentRowIndex, finalGrade);
                    setState(() { _isDialogShowing = false; });
                    Navigator.pop(context);
                  }
                },
                icon: const Icon(Icons.save_rounded),
                label: const Text('اعتماد وحفظ'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600, 
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
        await FileSaver.instance.saveFile(
          name: "كنترول_${selectedSubject}_$timestamp",
          bytes: Uint8List.fromList(fileBytes),
          ext: "xlsx",
          mimeType: MimeType.microsoftExcel,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ تم رصد الدرجة ($grade) للطالب وتحديث الكنترول بنجاح!'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ خطأ أثناء الحفظ: $e'), backgroundColor: Colors.red),
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
          title: const Text('نظام أبو الخضر للرصد الذكي v3.4', style: TextStyle(fontWeight: FontWeight.bold)),
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
              padding: const EdgeInsets.all(16.0),
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
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.purple.withOpacity(0.2) : Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.purple.shade300, width: 1.5),
                    ),
                    child: Column(
                      children: [
                        const Text("المرصود حالياً", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.purple)),
                        Text("$currentSubjectCount", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.purple)),
                      ],
                    ),
                  )
                ],
              ),
            ),
            if (excelFilePath != null && subjects.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
                child: Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        const Icon(Icons.menu_book_rounded, color: Colors.blue),
                        const SizedBox(width: 8),
                        const Text("المادة النشطة:", style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedSubject,
                            decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.zero),
                            isExpanded: true,
                            items: subjects.map((String sub) {
                              return DropdownMenuItem<String>(value: sub, child: Text(sub, style: const TextStyle(fontSize: 14)));
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
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black, 
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade800, width: 2),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: isScanningStarted && excelFilePath != null
                      ? MobileScanner(controller: cameraController, onDetect: processScannedData)
                      : Center(
                          child: Text(
                            "يرجى تحميل ملف الكنترول أولاً،\nثم اضغط على الزر بالأسفل لتشغيل الكاميرا والرصد الفعلي المباشر.", 
                            style: TextStyle(color: Colors.grey.shade400, fontSize: 14, height: 1.5), 
                            textAlign: TextAlign.center
                          ),
                        ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                onPressed: excelFilePath != null
                    ? () {
                        setState(() { isScanningStarted = true; });
                        cameraController.start();
                      }
                    : null,
                icon: const Icon(Icons.center_focus_weak_rounded),
                label: const Text("بدء الكاميرا والرصد المباشر"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade800,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
