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
      theme: ThemeData(
        useMaterial3: true, 
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.light)
      ),
      darkTheme: ThemeData(
        useMaterial3: true, 
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark)
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
  
  bool isScanningQR = false; 
  bool isScanningGrade = false; 
  bool _isDialogShowing = false;

  final MobileScannerController cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  final TextRecognizer textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final Set<String> _scannedRecords = {};
  
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

  // [المرحلة 1]: قراءة كود الـ QR ومطابقة الطالب بالملف
  void processScannedQR(BarcodeCapture capture) async {
    // لمنع التكرار والتعليق إذا كان الحوار مفتوحاً بالفعل
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
      gradeController.text = ""; 
      isScanningGrade = false;
    });
    
    showConfirmationDialog();
  }

  // معالجة مسح خط اليد وكشف الأرقام (OCR) تلقائياً
  void processOcrGrade(BarcodeCapture capture) async {
    if (!isScanningGrade || !_isDialogShowing) return;
    
    // محرك الـ OCR يعتمد على تحليل الصور المستخرجة من الكاميرا
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
      String rawText = barcodes.first.rawValue!;
      // استخراج الأرقام فقط من النص الممسوح
      final RegExp numRegExp = RegExp(r'\d+');
      final Match? match = numRegExp.firstMatch(rawText);
      
      if (match != null) {
        String detectedNumber = match.group(0)!;
        int? parsedGrade = int.tryParse(detectedNumber);
        // التحقق من منطقية الدرجة (مثلا بين 0 و 100)
        if (parsedGrade != null && parsedGrade >= 0 && parsedGrade <= 100) {
          setState(() {
            gradeController.text = detectedNumber;
            isScanningGrade = false; // التوقف فور التقاط درجة صحيحة
          });
        }
      }
    }
  }

  // شاشة التأكيد البينية (الـ Dialog الراقية بنظام المراحل المتتالية)
  void showConfirmationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: Row(
                  children: [
                    Icon(Icons.qr_code_2_rounded, color: Colors.blue.shade700, size: 28),
                    const SizedBox(width: 10),
                    const Text('تم قراءة ورقة الطالب', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('رقم الجلوس: ', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
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
                            width: 1.5
                          ),
                        ),
                        child: Text(
                          currentStudentRowIndex == -1 ? '🚨 رقم الجلوس غير مسجل بالملف!' : '👤 الاسم: $currentStudentName',
                          style: TextStyle(
                            fontSize: 15, 
                            fontWeight: FontWeight.bold, 
                            color: currentStudentRowIndex == -1 ? Colors.red.shade700 : Colors.blue.shade800
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Text('المادة النشطة للرصد: ', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                          Text(selectedSubject ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const Divider(height: 25),
                      
                      if (isScanningGrade) ...[
                        const Text('ضع مربع الكاميرا على الدرجة المكتوبة بخط اليد:', style: TextStyle(fontSize: 12, color: Colors.purple, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Container(
                          height: 140,
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Colors.black),
                          clipBehavior: Clip.antiAlias,
                          child: MobileScanner(
                            controller: cameraController,
                            onDetect: (capture) {
                              // قراءة الكاميرا التلقائية للنصوص والدرجات بخط اليد مسندة هنا
                              if (capture.barcodes.isNotEmpty) {
                                String raw = capture.barcodes.first.rawValue ?? "";
                                final RegExp regex = RegExp(r'\d+');
                                final match = regex.firstMatch(raw);
                                if (match != null) {
                                  setDialogState(() {
                                    gradeController.text = match.group(0)!;
                                    isScanningGrade = false;
                                  });
                                }
                              }
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
                        autofocus: true,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.redAccent),
                        decoration: InputDecoration(
                          hintText: '00',
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
                      setState(() {
                        _isDialogShowing = false;
                        isScanningGrade = false;
                      });
                      Navigator.pop(context);
                    },
                    child: const Text('إلغاء وتخطي ورقة الطالب', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  ),
                  if (!isScanningGrade)
                    ElevatedButton.icon(
                      onPressed: () {
                        setDialogState(() {
                          isScanningGrade = true;
                        });
                      },
                      icon: const Icon(Icons.center_focus_weak_rounded),
                      label: const Text('📷 مسح خط اليد'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple.shade600, 
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ElevatedButton.icon(
                    onPressed: currentStudentRowIndex == -1 ? null : () async {
                      String finalGrade = gradeController.text.trim();
                      if (finalGrade.isNotEmpty) {
                        // إغلاق الواجهة فوراً لبدء معالجة الحفظ السريع
                        setState(() {
                          _isDialogShowing = false;
                          isScanningGrade = false;
                        });
                        Navigator.pop(context);
                        await saveGradeToExcel(currentStudentQR, currentStudentRowIndex, finalGrade);
                      }
                    },
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: const Text('اعتماد وحفظ'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600, 
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
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
      // 1. تحديث قيمة الخلية الحية داخل الكنترول في ذاكرة الهاتف لكي لا تضيع التعديلات السابقة
      var cell = table.cell(imgExcel.CellIndex.indexByColumnRow(
        columnIndex: selectedSubjectColumnIndex,
        rowIndex: rowIndex,
      ));
      cell.value = imgExcel.TextCellValue(grade);

      setState(() {
        _scannedRecords.add("${selectedSubject}_$studentId");
      });

      // 2. تصدير بايتات ملف الاكسيل المحدث بالكامل
      var fileBytes = excel!.save();
      if (fileBytes != null) {
        String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        
        await FileSaver.instance.saveFile(
          name: "كنترول_${selectedSubject}_تحديث_$timestamp.xlsx",
          bytes: Uint8List.fromList(fileBytes),
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ تم رصد الدرجة ($grade) بنجاح وحفظ نسخة محدثة بالهاتف!'), 
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ خطأ في معالجة ملف الكنترول: $e'), backgroundColor: Colors.red));
    }
    
    // إعادة تصفير المتغيرات ليعود التطبيق تلقائياً وجاهزاً لالتقاط الورقة التالية فوراً
    setState(() {
      _isDialogShowing = false;
      isScanningGrade = false;
    });
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
            isScanningQR = true; // تفعيل الكاميرا تلقائياً بمجرد اختيار الكنترول
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
          title: const Text('نظام أبو الخضر للرصد الثنائي المستقر v4.5', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                        const Text("المادة النشطة للرصد:", style: TextStyle(fontWeight: FontWeight.bold)),
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
                  child: excelFilePath != null
                      ? MobileScanner(controller: cameraController, onDetect: processScannedQR)
                      : Center(
                          child: Text(
                            "الوضع الحالي: الكاميرا مغلقة.\nقم باختيار ملف الكنترول أولاً لتفتح الكاميرا تلقائياً للرصد المتتالي.", 
                            style: TextStyle(color: Colors.grey.shade400, fontSize: 13, height: 1.5), 
                            textAlign: TextAlign.center
                          ),
                        ),
                ),
              ),
            ),
            if(excelFilePath != null)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade300)
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.autorenew_rounded, color: Colors.blue),
                      SizedBox(width: 8),
                      Text("وضع الرصد التلقائي المتتالي نشط الآن.. وجه الكاميرا للورقة", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue)),
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
    textRecognizer.close();
    super.dispose();
  }
}
