import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:excel/excel.dart' as my_excel;
import 'package:file_picker/file_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:file_saver/file_saver.dart'; 
import 'package:path_provider/path_provider.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  String? _excelPath;
  Uint8List? _excelBytes; 
  String? _originalFileName; // 1. متغير جديد للاحتفاظ باسم الملف الأصلي
  String? _scannedSecretCode;
  String? _studentName;

  List<String> _dynamicSubjects = [];
  String? _selectedSubject;
  int _selectedSubjectIndexInFile = -1;
  int _scannedRecordsCount = 0;

  final TextEditingController _gradeController = TextEditingController();
  
  final MobileScannerController cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
    returnImage: true, 
  );

  final TextRecognizer _textRecognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  @override
  void dispose() {
    _gradeController.dispose();
    cameraController.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  void _pickExcelFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (result != null && result.files.single.path != null) {
        String path = result.files.single.path!;
        
        // التقاط اسم الملف الأصلي بدون الامتداد
        String fileNameWithExtension = result.files.single.name;
        String fileNameOnly = fileNameWithExtension.split('.').first;

        var bytes = File(path).readAsBytesSync();
        var excel = my_excel.Excel.decodeBytes(bytes);
        String sheetName = excel.tables.keys.first;
        var sheet = excel.tables[sheetName]!;

        List<String> extractedSubjects = [];
        if (sheet.maxRows > 0) {
          var headerRow = sheet.rows[0];
          for (int i = 4; i < headerRow.length; i++) {
            var cellValue = headerRow[i]?.value?.toString();
            if (cellValue != null && cellValue.trim().isNotEmpty) {
              extractedSubjects.add(cellValue.trim());
            }
          }
        }

        if (!mounted) return;

        setState(() {
          _excelPath = path;
          _excelBytes = bytes; 
          _originalFileName = fileNameOnly; // حفظ اسم الملف المختار
          _dynamicSubjects = extractedSubjects;
          if (extractedSubjects.isNotEmpty) {
            _selectedSubject = extractedSubjects.first;
            _selectedSubjectIndexInFile = 1;
          }
          _scannedRecordsCount = 0; 
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('✅ تم قراءة كشف الكنترول وتنشيط الرصد بنجاح!'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ خطأ في قراءة ملف الإكسيل: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _onBarcodeDetected(BarcodeCapture capture) async {
    if (_excelBytes == null || _selectedSubject == null || _scannedSecretCode != null) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty || barcodes.first.rawValue == null) return;

    String secretCode = barcodes.first.rawValue!.trim().replaceAll(' ', '');
    if (secretCode.isEmpty) return;

    String detectedSubjectNumber = "";
    String detectedGrade = "";

    if (capture.image != null) {
      try {
        final Uint8List imgBytes = capture.image!;
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/ocr_shot.png');
        await tempFile.writeAsBytes(imgBytes, flush: true);

        final InputImage inputImage = InputImage.fromFile(tempFile);
        final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

        RegExp regExp = RegExp(r'[0-9٠-٩]+');
        Iterable<Match> matches = regExp.allMatches(recognizedText.text);
        List<String> foundNumbers = [];

        for (Match match in matches) {
          foundNumbers.add(_convertHindiToArabicDigits(match.group(0) ?? ""));
        }

        if (foundNumbers.length >= 2) {
          detectedSubjectNumber = foundNumbers.first;
          detectedGrade = foundNumbers.last;
        } else if (foundNumbers.length == 1) {
          detectedGrade = foundNumbers.first;
        }
        
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (_) {}
    }

    _verifyThreeZones(secretCode, detectedSubjectNumber, detectedGrade);
  }

  String _convertHindiToArabicDigits(String input) {
    var hindiDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    var englishDigits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    for (int i = 0; i < hindiDigits.length; i++) {
      input = input.replaceAll(hindiDigits[i], englishDigits[i]);
    }
    return input.trim();
  }

  void _verifyThreeZones(String secretCode, String subjectNum, String grade) {
    if (subjectNum.isNotEmpty && subjectNum != _selectedSubjectIndexInFile.toString()) {
      _showSecurityWarningDialog(subjectNum);
      return;
    }

    var excel = my_excel.Excel.decodeBytes(_excelBytes!);
    String sheetName = excel.tables.keys.first;
    var sheet = excel.tables[sheetName]!;

    bool found = false;
    String name = "";

    for (int i = 1; i < sheet.maxRows; i++) {
      var row = sheet.rows[i];
      if (row.length > 3 && row[3]?.value?.toString().trim() == secretCode) {
        name = row[1]?.value?.toString() ?? 'اسم غير معروف';
        found = true;
        break;
      }
    }

    if (found) {
      setState(() {
        _scannedSecretCode = secretCode;
        _studentName = name;
        _gradeController.text = grade;
      });

      _showConfirmationForm();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ الرقم السري ($secretCode) غير مدرج بملف الكنترول!'),
          backgroundColor: Colors.orange.shade700,
        ),
      );
    }
  }

  void _showSecurityWarningDialog(String wrongNum) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.gpp_bad, color: Colors.red),
              SizedBox(width: 8),
              Text('تنبيه أمني: تعارض مادة الرصد!')
            ],
          ),
          content: Text(
              'الورقة الممسوحة تتبع مادة رقم ($wrongNum)، بينما الكنترول مضبوط حالياً على مادة "$_selectedSubject" رقم ($_selectedSubjectIndexInFile).\n\nيرجى تعديل المادة النشطة من القائمة أولاً لضمان سلامة البيانات.'),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context),
              child: const Text('فهمت، تراجع', style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }

  void _showConfirmationForm() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
              child: const Row(
                children: [
                  Icon(Icons.edit_note, color: Colors.blue, size: 28),
                  SizedBox(width: 10),
                  Text('فورم مراجعة واعتماد الدرجة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('👤 الاسم: $_studentName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Text('📚 المادة: $_selectedSubject (رقم: $_selectedSubjectIndexInFile)', style: const TextStyle(color: Colors.blueGrey, fontSize: 12)),
                const Divider(),
                const Text('الدرجة الملتقطة ذكياً (يمكنك التعديل يدوياً):', style: TextStyle(fontSize: 13)),
                const SizedBox(height: 10),
                TextField(
                  controller: _gradeController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  autofocus: true,
                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.blue),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    fillColor: Colors.grey[50],
                    filled: true,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                child: const Text('إلغاء وتخطي', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                onPressed: () {
                  Navigator.of(context).pop();
                  setState(() { _scannedSecretCode = null; });
                },
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.save_rounded, color: Colors.white),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600),
                label: const Text('اعتماد وحفظ للكنترول', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: () {
                  Navigator.of(context).pop();
                  _executeSaveIntoExcel();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _executeSaveIntoExcel() async {
    if (_excelBytes == null || _selectedSubject == null || _scannedSecretCode == null) return;

    try {
      var excel = my_excel.Excel.decodeBytes(_excelBytes!);
      String sheetName = excel.tables.keys.first;
      var sheet = excel.tables[sheetName]!;

      int subjectColumnIndex = 4 + _dynamicSubjects.indexOf(_selectedSubject!);
      bool updated = false;

      for (int i = 1; i < sheet.maxRows; i++) {
        var row = sheet.rows[i];
        if (row.length > 3 && row[3]?.value?.toString().trim() == _scannedSecretCode) {
          var cell = sheet.cell(my_excel.CellIndex.indexByColumnRow(
            columnIndex: subjectColumnIndex, 
            rowIndex: i
          ));
          cell.value = my_excel.TextCellValue(_gradeController.text.trim().isEmpty ? "0" : _gradeController.text.trim());
          updated = true;
          break;
        }
      }

      if (updated) {
        var fileBytes = excel.save();
        if (fileBytes != null) {
          _excelBytes = Uint8List.fromList(fileBytes);

          // 💡 التعديل المضمون: الحفظ التفاعلي عبر نظام أندرويد ليتيح لك اختيار المجلد
          // واسم الملف سيكون نفس الاسم الأصلي الذي اخترته تماماً
          String finalName = _originalFileName ?? "Control_Sheet";

          await FileSaver.instance.saveAs(
            name: finalName,
            bytes: _excelBytes!,
            ext: "xlsx",
            mimeType: MimeType.microsoftExcel,
          );

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ تم تعديل الدرجة بنجاح! يرجى اختيار مكان الحفظ في النافذة الظاهرة.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 4),
            ),
          );

          setState(() {
            _scannedRecordsCount++;
            _scannedSecretCode = null;
            _studentName = null;
            _gradeController.clear();
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ فشل حفظ البيانات: $e'), backgroundColor: Colors.red),
      );
      setState(() { _scannedSecretCode = null; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('نظام أبو الخضر للرصد المستقر', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          centerTitle: true,
          backgroundColor: Colors.blue[800],
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.file_open_rounded),
              onPressed: _pickExcelFile,
              tooltip: 'تحميل ملف الإكسيل',
            )
          ],
        ),
        body: Column(
          children: [
            if (_excelBytes == null)
              Container(
                color: Colors.red[50],
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.red),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: _pickExcelFile,
                      child: const Text(
                        'الرجاء تحميل ملف إكسيل الكنترول لتنشيط الكاميرا وفحص المواد',
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              flex: 4,
              child: Stack(
                children: [
                  MobileScanner(
                    controller: cameraController,
                    onDetect: _onBarcodeDetected,
                  ),
                  Center(
                    child: Container(
                      width: 320,
                      height: 120,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.blue.shade600, width: 3),
                        borderRadius: const BorderRadius.all(Radius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      if (_dynamicSubjects.isNotEmpty)
                        Row(
                          children: [
                            const Text('المادة الحالية: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _selectedSubject,
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                items: _dynamicSubjects.map((String sub) {
                                  return DropdownMenuItem<String>(value: sub, child: Text(sub, style: const TextStyle(fontSize: 13)));
                                }).toList(),
                                onChanged: (val) {
                                  setState(() {
                                    _selectedSubject = val;
                                    _selectedSubjectIndexInFile = _dynamicSubjects.indexOf(val!) + 1;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(color: Colors.blue[100], borderRadius: BorderRadius.circular(20)),
                              child: Text(
                                'كود: $_selectedSubjectIndexInFile',
                                style: TextStyle(color: Colors.blue[900], fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(color: Colors.purple.shade100, borderRadius: BorderRadius.circular(20)),
                              child: Text(
                                'مرصود: $_scannedRecordsCount',
                                style: TextStyle(color: Colors.purple.shade900, fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            ),
                          ],
                        )
                      else
                        const Center(
                          child: Text('قم برفع ملف الكنترول لتنشيط عداد ومواد الفحص الذكي.',
                              style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
