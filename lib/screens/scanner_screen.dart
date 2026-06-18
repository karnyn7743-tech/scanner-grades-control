import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart' as imgExcel;
import 'package:file_picker/file_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:file_saver/file_saver.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  List<String> subjects = [];
  String? selectedSubject;
  int selectedSubjectColumnIndex = 4;
  String? excelFilePath;
  String? excelFileName;
  imgExcel.Excel? excel;
  String? sheetName;

  bool _isDialogShowing = false;
  final Set<String> _scannedRecords = {};

  // إعداد متحكم الكاميرا الحديث المستقر
  final MobileScannerController cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
    returnImage: true,
  );

  // كاشف النصوص الذكي المتوافق مع التحديث الأخير
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

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

  String _extractGradeFromText(String text) {
    final RegExp numRegExp = RegExp(r'\b\d{1,2}\b'); 
    final Iterable<Match> matches = numRegExp.allMatches(text);
    if (matches.isNotEmpty) {
      return matches.first.group(0) ?? "0";
    }
    return "0";
  }

  // دالة الالتقاط الذكي المحدثة بالكامل لحل مشكلة الأبعاد في الإصدار الأخير بالسيرفر
  void onCameraDetectHandler(BarcodeCapture capture) async {
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

    String autoDetectedGrade = "0";
    
    // الحل الجذري الحديث: جلب الأبعاد مباشرة من كائن capture.size المعتمد بالسيرفر
    if (capture.image != null && capture.size != null) {
      try {
        final Uint8List bytes = capture.image!;
        final double imageWidth = capture.size!.width;
        final double imageHeight = capture.size!.height;

        final InputImage inputImage = InputImage.fromBytes(
          bytes: bytes,
          metadata: InputImageMetadata(
            size: Size(imageWidth, imageHeight),
            rotation: InputImageRotation.rotation0deg,
            format: InputImageFormat.nv21,
            bytesPerRow: imageWidth.toInt(),
          ),
        );
        final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
        autoDetectedGrade = _extractGradeFromText(recognizedText.text);
      } catch (_) {
        autoDetectedGrade = "0"; 
      }
    }

    setState(() {
      _isDialogShowing = true;
      currentStudentQR = cleanScannedQR;
      currentStudentName = studentName;
      currentStudentRowIndex = studentRowIndex;
      gradeController.text = autoDetectedGrade == "0" ? "" : autoDetectedGrade;
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
            title: const Row(
              children: [
                Icon(Icons.verified_user_rounded, color: Colors.blue, size: 28),
                SizedBox(width: 10),
                Text('نافذة الرصد والاعتماد', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('رقم الجلوس (QR): ', style: TextStyle(color: Colors.grey, fontSize: 13)),
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
                  const Text('الالتقاط الذكي (أو أدخلها يدوياً):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: gradeController,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.redAccent),
                    decoration: InputDecoration(
                      hintText: 'أدخل الدرجة',
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
                  if (enteredGrade.isEmpty) enteredGrade = "0";
                  Navigator.pop(context);
                  await saveGradeToExcel(currentStudentQR, currentStudentRowIndex, enteredGrade);
                },
                icon: const Icon(Icons.save_rounded),
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
      },
    );
  }

  // دالة الحفظ الاحتياطي المحدثة بالكامل لتتوافق مع معاملات السيرفر الجديدة لـ FileSaver
  Future<void> saveGradeToExcel(String studentId, int rowIndex, String grade) async {
    if (excel == null || sheetName == null || excelFilePath == null) return;
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
        final File originalFile = File(excelFilePath!);
        await originalFile.writeAsBytes(fileBytes, flush: true);

        String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        
        // التحديث النهائي: تمرير المعاملات بالشكل الحديث المقبول في السيرفر دون قيود المايم
        await FileSaver.instance.saveFile(
          name: "Backup_${selectedSubject}_$timestamp.xlsx",
          bytes: Uint8List.fromList(fileBytes),
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ تم حفظ الدرجة ($grade) بنجاح!'),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ فشل الكتابة المباشرة: $e'), backgroundColor: Colors.red)
      );
    }

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
        excelFilePath = result.files.single.path;
        excelFileName = result.files.single.name;
        var bytes = File(excelFilePath!).readAsBytesSync();
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
          title: const Text('إعدادات الرصد المطور', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          centerTitle: true,
          elevation: 2,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            // أيقونة الرفع العلوي لملف الإكسيل في رأس الشاشة مباشرة كما في طلبك
            IconButton(
              icon: const Icon(Icons.file_upload_outlined, size: 26),
              tooltip: 'اختيار ملف الإكسيل الرئيسي',
              onPressed: pickAndLoadExcel,
            ),
          ],
        ),
        body: excelFilePath == null
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_upload_outlined, size: 80, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        "الرجاء الضغط على أيقونة الرفع الموجودة في رأس الشاشة لاختيار ملف الكنترول والبدء.",
                        style: TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            : Column(
                children: [
                  // 1. حاوية اسم الملف وبجانبها مربع العداد الأرجواني المنبثق
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.green.shade300, width: 1),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.description, color: Colors.green, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    excelFileName ?? "ملف الكنترول الرئيسي",
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.purple.withOpacity(0.2) : Colors.purple.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.purple.shade300, width: 1.2),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text("المرصود", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.purple)),
                              Text("$currentSubjectCount", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.purple)),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                  
                  // 2. كارد قائمة المواد المستخرجة ديناميكياً
                  if (subjects.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(right: 4.0, bottom: 4.0),
                            child: Text("اختر المادة الحالية للمسح:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                          Card(
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
                        ],
                      ),
                    ),

                  // 3. مساحة تشغيل الكاميرا الحية والمسح المستقر تلقائياً
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
                        child: MobileScanner(
                          controller: cameraController, 
                          onDetect: onCameraDetectHandler,
                        ),
                      ),
                    ),
                  ),

                  // 4. الزر والشريط السفلي المثبت لبدء الرصد
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      width: double.infinity,
                      decoration: BoxDecoration(
                          color: Colors.green.shade600,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))
                          ]
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.play_circle_filled_rounded, color: Colors.white, size: 22),
                          SizedBox(width: 8),
                          Text(
                            "بدء الرصد (وجه الكاميرا الآن تلقائياً)",
                            style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
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
    _textRecognizer.close();
    super.dispose();
  }
}
