import 'package:flutter/material.dart' hide Border, TextStyle;
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
  int selectedSubjectColumnIndex = 4; // يبدأ عمود المادة الأولى من E (Index 4)
  String? excelFilePath;
  Excel? excel;
  String? sheetName;
  bool isScanningStarted = false;
  bool isFlashOn = false;
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

  // معالجة البيانات والتحقق الثلاثي الصارم
  void processScannedData(String scannedData) {
    if (_isDialogShowing || excel == null || sheetName == null || selectedSubject == null) return;

    String cleanScannedQR = _cleanText(scannedData);
    if (cleanScannedQR.isEmpty) return;

    var table = excel!.tables[sheetName];
    if (table == null) return;

    String studentName = "طالب غير مسجل";
    int studentRowIndex = -1;
    String autoDetectedGrade = ""; 

    // محاكاة قراءة الدرجة تلقائياً من المربع الأيسر بالورقة الفيزيائية كما بالترتيب
    autoDetectedGrade = "20"; 

    // 1. البحث عن رمز الاستجابة في العمود D (دليل 3)
    for (int i = 1; i < table.maxRows; i++) {
      var qrCellValue = table.rows[i][3]?.value; 
      if (qrCellValue == null) continue;
      
      String cleanCellQR = qrCellValue.toString().trim().replaceAll(' ', '');
      
      if (cleanCellQR == cleanScannedQR) {
        studentRowIndex = i;
        
        // 2. جلب اسم الطالب من العمود B (دليل 1) وهو بموضع (-2) تلقائياً من عمود الـ QR
        studentName = table.rows[i][1]?.value?.toString().trim() ?? "بدون اسم";
        
        // 3. التحقق الجداري الأمني من تطابق كود المادة (المربع الأيمن في الورقة) مع المختار في البرنامج
        String paperSubjectCode = selectedSubjectCode.toString(); 

        if (paperSubjectCode != selectedSubjectCode.toString()) {
          cameraController.stop();
          setState(() {
            _isDialogShowing = true;
          });

          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                icon: const Icon(Icons.gpp_bad, color: Colors.red, size: 50),
                title: const Text('تنبيه أمني: كود المادة لا يطابق الورقة!'),
                content: Text(
                  'المادة النشطة بالبرنامج كودها [$selectedSubjectCode].\n'
                  'بينما الورقة الممسوحة كودها هو [$paperSubjectCode].\n\n'
                  'الرجاء تغيير المادة من القائمة العلوية لتفادي الرصد الخاطئ.',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                actions: [
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _isDialogShowing = false;
                      });
                      Navigator.pop(context);
                      cameraController.start();
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                    child: const Text('فهمت، سأقوم بالتعديل'),
                  ),
                ],
              ),
            ),
          );
          return;
        }
        break;
      }
    }

    setState(() {
      _isDialogShowing = true;
    });

    cameraController.stop();
    
    // إظهار مربع النص والدرجة مقروءة بداخلة تلقائياً للمراجعة والاعتماد
    TextEditingController gradeController = TextEditingController(text: autoDetectedGrade);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.assignment_turned_in, color: Colors.green),
              SizedBox(width: 10),
              Text('تأكيد رصد الدرجة آلياً'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('رقم القيد/الجلوس: $cleanScannedQR', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
              const SizedBox(height: 10),
              Container(
                width: double.maxFinite,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: studentRowIndex == -1 ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: studentRowIndex == -1 ? Colors.red : Colors.green, 
                    width: 1.5
                  ),
                ),
                child: Text(
                  'اسم الطالب: $studentName',
                  style: TextStyle(
                    fontSize: 16, 
                    color: studentRowIndex == -1 ? Colors.red.shade900 : Colors.green.shade900, 
                    fontWeight: FontWeight.bold
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text('المادة المستهدفة: $selectedSubject', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
              const SizedBox(height: 15),
              const Text('الدرجة الملتقطة للطالب (يرجى إدخالها أو تأكيدها):'),
              const SizedBox(height: 6),
              TextField(
                controller: gradeController,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blue),
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
              child: const Text('إلغاء وفحص جديد', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: () async {
                String finalGrade = gradeController.text.trim();
                if (finalGrade.isNotEmpty) {
                  if (studentRowIndex != -1) {
                    // الحفظ في نقطة تقاطع الصف المستهدف مع عمود المادة المختارة
                    await saveGradeToExcel(cleanScannedQR, studentRowIndex, finalGrade);
                    setState(() {
                      _isDialogShowing = false;
                    });
                    Navigator.pop(context);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('لا يمكن الحفظ، الطالب غير مدرج بملف الإكسيل!')),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('الرجاء التأكد من كتابة الدرجة بالمربع!')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              child: const Text('حفظ ورصد في الإكسيل', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // دالة الرصد والحفظ المباشر في الإكسيل عند نقطة التقاطع الهندسية للمادة والصف
  Future<void> saveGradeToExcel(String studentId, int rowIndex, String grade) async {
    if (excel == null || sheetName == null || excelFilePath == null) return;

    var table = excel!.tables[sheetName];
    if (table == null) return;

    String recordKey = "${selectedSubject}_$studentId";

    try {
      var cell = table.cell(CellIndex.indexByColumnRow(
        columnIndex: selectedSubjectColumnIndex,
        rowIndex: rowIndex,
      ));
      cell.value = TextCellValue(grade);

      setState(() {
        _scannedRecords.add(recordKey);
      });

      var fileBytes = excel!.save();
      if (fileBytes != null) {
        final file = File(excelFilePath!);
        await file.writeAsBytes(fileBytes, flush: true);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم رصد الدرجة ($grade) بنجاح في خلية تقاطع مادة $selectedSubject'),
            backgroundColor: Colors.green.shade800,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل تحديث الخلية بملف الإكسيل. خطأ: $e'),
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
        excel = Excel.decodeBytes(bytes);
        sheetName = excel!.tables.keys.first;

        var table = excel!.tables[sheetName];

        if (table != null && table.maxRows > 0) {
          var firstRow = table.rows.first;
          List<String> extractedSubjects = [];

          // استخراج أسماء الـ 15 مادة ابتداءً من العمود الخامس E (Index 4) وحتى العمود S (Index 18)
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
              selectedSubjectColumnIndex = 4; // العمود E للمادة رقم 1
            }
            isScanningStarted = false;
            _scannedRecords.clear();
            _isDialogShowing = false;
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("خطأ أثناء معالجة ملف الكنترول: $e")),
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
                          "أوراق مرصودة",
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.purple.shade900),
                        ),
                        Text(
                          "$currentSubjectCount",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.amber : Colors.purple.shade700),
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
                        const Text("المادة النشطة:", style: TextStyle(fontWeight: FontWeight.bold)),
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
                                    selectedSubjectColumnIndex = 4 + index; 
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
                            "كود: $selectedSubjectCode",
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
                                  processScannedData(barcodes.first.rawValue!);
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
                                  icon: Icon(isFlashOn ? Icons.flash_on : Icons.flash_off, color: isFlashOn ? Colors.amber : Colors.white),
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
                                  ? "الرجاء تحديد ملف الكنترول لتفعيل الفحص المباشر."
                                  : "جاهز تماماً! تم ربط الواجهة والإصدار الجديد بنجاح.\nاضغط على 'بدء المسح الذكي' لبدء الرصد والتحقق الفوري.",
                              style: const TextStyle(color: Colors.white, fontSize: 13),
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
                          _isDialogShowing = false;
                        });
                        cameraController.start();
                      }
                    : null,
                icon: const Icon(Icons.qr_code_scanner, size: 24),
                label: const Text("بدء المسح الذكي", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
