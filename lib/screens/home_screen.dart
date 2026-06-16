import 'package:flutter/material.dart';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'main.dart'; // استيراد الملف الرئيسي للتحكم بالوضع الليلي

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<String> subjects = [];
  String? selectedSubject;
  int selectedSubjectCode = 1;
  String? excelFilePath;
  bool isScanningStarted = false; 
  
  // متحكم الكاميرا والفلاش الاحترافي
  final MobileScannerController cameraController = MobileScannerController();

  // سجل منع التكرار
  final Set<String> _scannedRecords = {};

  int get currentSubjectCount {
    if (selectedSubject == null) return 0;
    return _scannedRecords.where((key) => key.startsWith("${selectedSubject}_")).length;
  }

  void handleStudentGrading(String studentId, String grade) {
    if (selectedSubject == null) return;
    String recordKey = "${selectedSubject}_$studentId";

    if (_scannedRecords.contains(recordKey)) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.amber),
              SizedBox(width: 10),
              Text('تنبيه تكرار الرصد'),
            ],
          ),
          content: Text('الطالب ذو الرقم ($studentId) تم رصد درجته مسبقاً في مادة ($selectedSubject).'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('حسناً'),
            ),
          ],
        ),
      );
    } else {
      setState(() {
        _scannedRecords.add(recordKey);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم رصد درجة الطالب $studentId بنجاح!')),
      );
    }
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
        var excel = Excel.decodeBytes(bytes);

        String firstSheet = excel.tables.keys.first;
        var table = excel.tables[firstSheet];

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
            }
            isScanningStarted = false; 
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
    // معرفة هل التطبيق حالياً في الوضع المظلم أم لا
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('نظام أبو الخضر للرصد الذكي'),
          centerTitle: true,
          elevation: 2,
          actions: [
            // زر علوي حقيقي يحول مظهر التطبيق بالكامل
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
            // ================= القسم العلوي: العداد ورفع الملف =================
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
                  
                  // عداد الطلاب في أعلى اليسار
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
                            color: isDark ? Colors.white70 : Colors.purple.shade900
                          ),
                        ),
                        Text(
                          "$currentSubjectCount",
                          style: TextStyle(
                            fontSize: 18, 
                            fontWeight: FontWeight.bold, 
                            color: isDark ? Colors.amber : Colors.purple.shade700
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ================= قائمة اختيار المادة والكود =================
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
                        const Text("المادة:", style: TextStyle(fontWeight: FontWeight.bold)),
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
                                    selectedSubjectCode = subjects.indexOf(newValue!) + 1;
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
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],

            // ================= القسم الأوسط: شاشة الكاميرا مصغرة للنصف =================
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
                                  String scannedId = barcodes.first.rawValue!;
                                  handleStudentGrading(scannedId, "25");
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
                            // زر الفلاش العائم المربوط بالمتحكم
                            Positioned(
                              top: 10,
                              left: 10,
                              child: CircleAvatar(
                                backgroundColor: Colors.black54,
                                child: IconButton(
                                  icon: ValueListenableBuilder(
                                    valueListenable: cameraController.torchState,
                                    builder: (context, state, child) {
                                      switch (state) {
                                        case TorchState.off:
                                          return const Icon(Icons.flash_off, color: Colors.white);
                                        case TorchState.on:
                                          return const Icon(Icons.flash_on, color: Colors.amber);
                                      }
                                    },
                                  ),
                                  onPressed: () => cameraController.toggleTorch(),
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
                                ? "الرجاء رفع ملف الإكسيل أولاً لتفعيل النظام."
                                : "تم إعداد الكنترول بنجاح.\nاضغط على 'بدء المسح الذكي' بالأسفل لتنشيط الكاميرا.",
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                ),
              ),
            ),

            // ================= القسم السفلي: زر بدء الفحص والمسح =================
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
