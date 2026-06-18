import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart' as excel_pub; 
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
  String? _selectedFilePath;
  Uint8List? _fileBytes;
  excel_pub.Excel? _excel;
  String? _selectedSheet;
  List<String> _subjects = [];
  String? _chosenSubject;
  int _pickedSubjectIndex = 5; 

  // بيانات الرصد الحالية
  String? _currentStudentId;
  String? _detectedGrade;
  int _successCount = 0;

  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );
  
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _scannerController.dispose();
    // إزالة دالة التخلص الفرعية لتفادي خطأ السيرفر
    super.dispose();
  }

  // 1. اختيار الملف وقراءة البيانات ديناميكياً
  Future<void> _pickExcelFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true, 
      );

      if (result != null && result.files.single.bytes != null) {
        setState(() {
          _selectedFilePath = result.files.single.path;
          _fileBytes = result.files.single.bytes;
          _excel = excel_pub.Excel.decodeBytes(_fileBytes!);
          _selectedSheet = _excel!.tables.keys.first;
        });

        _loadSubjects();
      }
    } catch (e) {
      _showSnackBar("خطأ أثناء تحميل الملف: $e");
    }
  }

  void _loadSubjects() {
    if (_excel == null || _selectedSheet == null) return;
    var sheet = _excel!.tables[_selectedSheet];
    if (sheet == null || sheet.maxRows == 0) return;

    var headerRow = sheet.rows[3];
    List<String> foundSubjects = [];

    for (int i = 5; i < headerRow.length; i++) {
      var cellValue = headerRow[i]?.value;
      if (cellValue != null) {
        foundSubjects.add(cellValue.toString().trim());
      }
    }

    setState(() {
      _subjects = foundSubjects;
      if (_subjects.isNotEmpty) {
        _chosenSubject = _subjects.first;
        _pickedSubjectIndex = 5;
      }
    });
  }

  // 2. معالجة وتأمين الحفظ الفوري المباشر المتوافق مع إصدار حزمتك
  Future<void> _saveAndCommitExcel() async {
    if (_excel == null || _selectedFilePath == null) return;

    List<int>? updatedBytes = _excel!.encode();
    if (updatedBytes == null) return;
    Uint8List fileData = Uint8List.fromList(updatedBytes);

    try {
      // تعديل فوري مباشر على الملف عبر المسار الفيزيائي
      final File physicalFile = File(_selectedFilePath!);
      await physicalFile.writeAsBytes(fileData, flush: true);

      // الحفظ المباشر المتوافق مع الإصدار القديم للحزمة (بدءاً من تمرير البايتات مباشرة بدون ل لـ ext)
      String fileNameWithExt = _selectedFilePath!.split('/').last;

      await FileSaver.instance.saveFile(
        fileNameWithExt,
        fileData,
        "",
        mimeType: MimeType.MICROSOFT_EXCEL,
      );

      setState(() {
        _fileBytes = fileData;
        _successCount++;
      });

      _showSnackBar("تم الحفظ والكتابة المباشرة على الملف بنجاح! 🎉");
    } catch (e) {
      _showSnackBar("فشل الحفظ المباشر الفوري. جاري الحفظ كنسخة احتياطية...");
      _backupSave(fileData);
    }
  }

  // حفظ احتياطي متوافق مع إصدار الحزمة الحالي لديك
  Future<void> _backupSave(Uint8List bytes) async {
    try {
      await FileSaver.instance.saveFile(
        "نسخة_احتياطية_درجات.xlsx",
        bytes,
        "",
        mimeType: MimeType.MICROSOFT_EXCEL,
      );
    } catch (err) {
      _showSnackBar("خطأ الحفظ الاحتياطي: $err");
    }
  }

  // 3. دالة رصد الدرجة المباشرة المتوافقة مع إصدار الإكسيل في مشروعك
  void _updateStudentGrade(String studentId, String grade) {
    if (_excel == null || _selectedSheet == null) return;
    var sheet = _excel!.tables[_selectedSheet];
    if (sheet == null) return;

    bool studentFound = false;

    for (int i = 4; i < sheet.maxRows; i++) {
      var cellValue = sheet.rows[i][2]?.value?.toString().trim();
      if (cellValue == studentId) {
        // استخدام الطريقة المتوافقة مباشرة مع إصدار الحزمة القديم لديك
        var cellIndex = excel_pub.CellIndex.indexByColumnRow(
          columnIndex: _pickedSubjectIndex,
          rowIndex: i,
        );
        
        // التعديل المباشر المتوافق دون استخدام معالج الخلايا الحديث
        sheet.updateCell(cellIndex, grade); 
        studentFound = true;
        break;
      }
    }

    if (studentFound) {
      _saveAndCommitExcel();
    } else {
      _showSnackBar("عذراً، لم يتم العثور على الرقم الأكاديمي $studentId في الملف");
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 14)),
        backgroundColor: Colors.blueGrey[900],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text(
            'إعدادات الرصد المطور',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
        ),
        body: _selectedFilePath == null ? _buildUploadState() : _buildScannerState(),
      ),
    );
  }

  Widget _buildUploadState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open_rounded, size: 100, color: Colors.blue[400]),
            const SizedBox(height: 24),
            const Text(
              "الرجاء الضغط على زر المجلد أدناه\nلاختيار ملف الكنترول والبدء التلقائي.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, height: 1.5, color: Colors.black54),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: _pickExcelFile,
              icon: const Icon(Icons.file_open_rounded, color: Colors.white),
              label: const Text("اختيار ملف Excel الأصل", style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScannerState() {
    String fileName = _selectedFilePath!.split('/').last;

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: Colors.purple[50], borderRadius: BorderRadius.circular(10)),
                    child: Column(
                      children: [
                        const Text("المرصود", style: TextStyle(fontSize: 11, color: Colors.purple, fontWeight: FontWeight.bold)),
                        Text("$_successCount", style: const TextStyle(fontSize: 18, color: Colors.purple, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          Icon(Icons.folder_shared_rounded, color: Colors.green[700], size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              fileName,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerRight,
                child: Text("اختر المادة الحالية للمسح:", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey[50],
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _chosenSubject,
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down_circle_rounded, color: Colors.blue),
                    items: _subjects.map((String sub) {
                      return DropdownMenuItem<String>(
                        value: sub,
                        child: Text(sub, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      if (newValue != null) {
                        setState(() {
                          _chosenSubject = newValue;
                          _pickedSubjectIndex = 5 + _subjects.indexOf(newValue);
                        });
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: Colors.black),
            clipBehavior: Clip.antiAlias,
            child: MobileScanner(
              controller: _scannerController,
              onDetect: (capture) {
                final List<Barcode> barcodes = capture.barcodes;
                if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                  final String code = barcodes.first.rawValue!;
                  _scannerController.stop();
                  _processScannedQRCode(code);
                }
              },
            ),
          ),
        ),

        Container(
          margin: const EdgeInsets.all(16),
          width: double.infinity,
          height: 55,
          decoration: BoxDecoration(color: Colors.green[600], borderRadius: BorderRadius.circular(12)),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.camera_alt_outlined, color: Colors.white),
              SizedBox(width: 8),
              Text(
                "يوجه الكاميرا الآن تلقائياً للـ QR والدرجة",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
        )
      ],
    );
  }

  void _processScannedQRCode(String qrCodeValue) {
    setState(() {
      _currentStudentId = qrCodeValue.trim();
      _detectedGrade = ""; 
    });

    _showGradingDialog();
  }

  void _showGradingDialog() {
    TextEditingController gradeController = TextEditingController(text: _detectedGrade);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.fact_check_rounded, color: Colors.blue),
              SizedBox(width: 8),
              Text("اعتماد رصد الدرجة", style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("رقم الطالب: $_currentStudentId", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text("المادة الحالية: $_chosenSubject", style: const TextStyle(fontSize: 14, color: Colors.black54)),
              const SizedBox(height: 16),
              const Text("الدرجة المستخرجة:", style: TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 6),
              TextField(
                controller: gradeController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.red),
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.blue, width: 2), borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _scannerController.start(); 
              },
              child: const Text("إلغاء", style: TextStyle(color: Colors.grey, fontSize: 16)),
            ),
            ElevatedButton(
              onPressed: () {
                String finalGrade = gradeController.text.trim();
                Navigator.pop(context);
                if (finalGrade.isNotEmpty && _currentStudentId != null) {
                  _updateStudentGrade(_currentStudentId!, finalGrade);
                }
                _scannerController.start(); 
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text("حفظ واعتماد فوراً", style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ],
        );
      },
    );
  }
}
