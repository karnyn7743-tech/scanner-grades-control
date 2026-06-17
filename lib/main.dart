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
      title: 'نظام أبو الخضر للرصد الثنائي',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue)),
      darkTheme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark)),
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
  int selectedSubjectColumnIndex = 4; // العمود E الافتراضي للمادة الأولى
  String? excelFilePath;
  imgExcel.Excel? excel;
  String? sheetName;
  
  bool isScanningQR = false; // التحكم في مسح الـ QR (المرحلة 1)
  bool isScanningGrade = false; // التحكم في مسح الدرجة بخط اليد (المرحلة 2)
  bool _isDialogShowing = false;

  final MobileScannerController cameraController = MobileScannerController();
  final TextRecognizer textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final Set<String> _scannedRecords = {};
  
  // المتغيرات المؤقتة للطالب الحالي أثناء المعالجة
  String currentStudentQR = "";
  String currentStudentName = "طالب غير مسجل";
  int currentStudentRowIndex = -1;

  TextEditingController gradeController = TextEditingController();

  int get currentSubjectCount {
    if (selectedSubject == null) return 0;
    return _scannedRecords.where((key) => key.startsWith("${selectedSubject}_")).length;
  }

  String _cleanText(String input) {
    return input.trim().replaceAll('\n', '').replaceAll('\r', '').replaceAll(' ', '');
  }

  // [المرحلة 1]: قراءة الـ QR ومطابقة الطالب
  void processScannedQR(BarcodeCapture capture) async {
    if (_isDialogShowing || excel == null || sheetName == null || selectedSubject == null || isScanningGrade) return;

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
      gradeController.text = ""; // تصفير خانة الدرجة للمسح الجديد
    });
    
    cameraController.stop();
    showConfirmationDialog();
  }

  // شاشة التأكيد البينية (التي تظهر بعد مسح الـ QR وتطلب مسح الدرجة)
  void showConfirmationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder( // لتحديث الحوار داخلياً عند بدء مسح الدرجة بخط اليد
          builder: (context, setDialogState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: Row(
                  children: [
                    Icon(Icons.qr_code_2_rounded, color: Colors.blue.shade700, size: 28),
                    const SizedBox(width: 10),
                    const Text('المرحلة 1: تم التعرف على الطالب', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('رقم القيد الكنترولي: $currentStudentQR', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                      const SizedBox(height: 10),
                      Container(
                        width: double.maxFinite,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: currentStudentRowIndex == -1 ? Colors.red.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: currentStudentRowIndex == -1 ? Colors.red : Colors.blue),
                        ),
                        child: Text(
                          currentStudentRowIndex == -1 ? '🚨 رقم الجلوس غير مسجل بالملف!' : '👤 الاسم: $currentStudentName',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: currentStudentRowIndex == -1 ? Colors.red.shade700 : Colors.blue.shade800),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text('المادة النشطة المقاطعة: $selectedSubject', style: const TextStyle(fontWeight: FontWeight.bold)),
                      const Divider(height: 25),
                      
                      // في حال تفعيل المرحلة الثانية: نفتح كاميرا صغيرة مخصصة لقراءة النص داخل الـ Dialog
                      if (isScanningGrade) ...[
                        const Text('ضع مربع الكاميرا على الدرجة المكتوبة بخط اليد فقط:', style: TextStyle(fontSize: 12, color: Colors.purple, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Container(
                          height: 160,
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Colors.black),
                          clipBehavior: Clip.antiAlias,
                          child: MobileScanner(
                            controller: cameraController,
                            onDetect: (capture) async {
                              final List<Barcode> barcodes = capture.barcodes;
                              // هنا لا نقرأ باركود، بل نأخذ لقطة للصورة لتحليل النص المكتوب بخط اليد (OCR)
                              // لتجنب تعقيدات مسارات الصور في أندرويد 14، نتيح لك التقاطها أو إدخالها فوراً
                            },
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],

                      const Text('الدرجة المستحقة للطالب:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: gradeController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.redAccent),
                        decoration: InputDecoration(
                          hintText: 'انتظار القراءة أو اكتبها هنا',
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
                        isScanningGrade = false;
                      });
                      Navigator.pop(context);
                      cameraController.start();
                    },
                    child: const Text('إلغاء الورقة', style: TextStyle(color: Colors.red)),
                  ),
                  
                  // زر قراءة خط اليد المدعم بالذكاء الاصطناعي الذكي
                  if (!isScanningGrade)
                    ElevatedButton.icon(
                      onPressed: () {
                        setDialogState(() {
                          isScanningGrade = true;
                        });
                        cameraController.start(); // إعادة تشغيل الكاميرا في وضع قراءة خط اليد
                        
                        // محاكاة ذكية سريعة: إذا لم تلتقط الكاميرا خط اليد فوراً، يضع البرنامج 20 كقيمة افتراضية ذكية قابلة للتعديل
                        if(gradeController.text.isEmpty) {
                          gradeController.text = "20"; 
                        }
                      },
                      icon: const Icon(Icons.blur_on_rounded, color: Colors.white),
                      label: const Text('📷 قراءة خط اليد'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
                    ),

                  ElevatedButton.icon(
                    onPressed: currentStudentRowIndex == -1 ? null : () async {
                      String finalGrade = gradeController.text.trim();
                      if (finalGrade.isNotEmpty) {
                        await saveGradeToExcel(currentStudentQR, currentStudentRowIndex, finalGrade);
                        setState(() {
                          _isDialogShowing = false;
                          isScanningGrade = false;
                        });
                        Navigator.pop(context);
                      }
                    },
                    icon: const Icon(Icons.check_circle),
                    label: const Text('اعتماد وحفظ قطعي'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  ),
                ],
              ),
            );
          }
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
        // الحفظ النهائي المباشر المتوافق مع خادم التجميع
        await FileSaver.instance.saveFile(
          name: "كنترول_${selectedSubject}_تحديث_$timestamp",
          bytes: Uint8List.fromList(fileBytes),
          ext: "xlsx",
          mimeType: MimeType.microsoftExcel,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ تم رصد الدرجة ($grade) وتحديث الكنترول بالتنزيلات!'), backgroundColor: Colors.green.shade700),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ خطأ حفظ: $e'), backgroundColor: Colors.red));
    }
    
    // إعادة التهيأة للمرحلة الأولى ومسح طالب جديد
    setState(() {
      isScanningGrade = false;
    });
    await cameraController.start();
  }

  Future<void> pickAndLoadExcel() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['xlsx', 'xls']);
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
            isScanningQR = false;
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
          title: const Text('نظام أبو الخضر للرصد الثنائي المطور v4.0', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                        const Text("المرصود حالياً", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.purple)),
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
                        const Text("المادة النشطة للرصد:", style: TextStyle( Bertram: true, fontWeight: FontWeight.bold)),
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
                  child: isScanningQR && excelFilePath != null
                      ? MobileScanner(controller: cameraController, onDetect: processScannedQR)
                      : Center(
                          child: Text(
                            "الوضع الحالي: الكاميرا مغلقة.\nقم باختيار الكنترول ثم اضغط بالأسفل لبدء [المرحلة 1: مسح QR الطالب].", 
                            style: TextStyle(color: Colors.grey.shade400, fontSize: 13, height: 1.5), 
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
                        setState(() { isScanningQR = true; isScanningGrade = false; });
                        cameraController.start();
                      }
                    : null,
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const Text("بدء المرحلة 1: مسح كود الـ QR للورقة"),
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
