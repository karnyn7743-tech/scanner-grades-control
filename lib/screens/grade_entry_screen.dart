import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as px;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

class _ImageRegions {
  final Uint8List? leftRegion;
  final Uint8List? centerRegion;
  final Uint8List? rightRegion;
  _ImageRegions({this.leftRegion, this.centerRegion, this.rightRegion});
}

class GradeEntryScreen extends StatefulWidget {
  const GradeEntryScreen({super.key});

  @override
  State<GradeEntryScreen> createState() => _GradeEntryScreenState();
}

class _GradeEntryScreenState extends State<GradeEntryScreen> {
  String _fileName = "لم يتم اختيار ملف الكنترول بعد";
  String? _selectedFilePath; // المسار الحقيقي للملف المختار
  List<String> _subjects = [];
  String? _selectedSubject;
  bool _isLoading = false;

  String _secretIdResult = "سيظهر هنا الرقم السري";
  final TextEditingController _gradeController = TextEditingController();

  int _totalStudents = 0;
  int _gradedStudents = 0;

  final MobileScannerController _cameraController = MobileScannerController(
    autoStart: false,
    torchEnabled: false,
    returnImage: true,
  );
  bool _isScanningActive = false;
  bool _isTorchOn = false;

  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  px.Excel? _excelInstance;

  // ===================== دوال الصلاحيات =====================
  Future<void> _requestPermissions() async {
    await Permission.storage.request();
    await Permission.camera.request();
    if (await Permission.manageExternalStorage.request().isGranted) {
      debugPrint("تم الحصول على صلاحية إدارة الملفات الشاملة");
    }
  }

  // ===================== تحميل آخر ملف مستخدم =====================
  Future<void> _loadLastExcelFile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? lastFile = prefs.getString('last_excel_file');
      if (lastFile != null && await File(lastFile).exists()) {
        setState(() {
          _selectedFilePath = lastFile;
          _fileName = lastFile.split('/').last;
        });
        await _parseExcelFile(lastFile);
      }
    } catch (e) {
      print('خطأ في تحميل آخر ملف: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _loadLastExcelFile();
  }

  @override
  void dispose() {
    _gradeController.dispose();
    _cameraController.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  // ===================== قراءة ملف Excel =====================
  Future<void> _parseExcelFile(String filePath) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      _excelInstance = px.Excel.decodeBytes(bytes);

      if (_excelInstance!.tables.isNotEmpty) {
        var sheet = _excelInstance!.tables.values.first;
        List<String> tempSubjects = [];

        if (sheet.maxRows > 0) {
          var row = sheet.rows.first;
          for (int i = 4; i <= 18; i++) {
            if (i < row.length && row[i] != null) {
              tempSubjects.add(row[i]!.value.toString());
            }
          }
        }

        setState(() {
          _subjects = tempSubjects;
          _totalStudents = sheet.maxRows > 1 ? sheet.maxRows - 1 : 0;
          _gradedStudents = 0;
          _fileName = filePath.split('/').last;
          _selectedFilePath = filePath;
        });
      }
    } catch (e) {
      _showSnackBar("خطأ في قراءة الملف: $e");
      setState(() {
        _fileName = "فشل في قراءة ملف الأكسيل";
        _subjects = [];
        _totalStudents = 0;
      });
    }
  }

  // ===================== اختيار ملف Excel (بدون نسخ) =====================
  Future<void> _pickAndParseExcel() async {
    await _requestPermissions();
    setState(() { _isLoading = true; });

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'xlsm', 'xlsb'],
      );

      if (result == null || result.files.single.path == null) {
        _showSnackBar('لم يتم اختيار ملف');
        return;
      }

      final String sourcePath = result.files.single.path!;

      // استخدم الملف في مكانه الأصلي مباشرة (بدون نسخ)
      await _parseExcelFile(sourcePath);

      // حفظ المسار في SharedPreferences للاستخدام لاحقاً
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_excel_file', sourcePath);

      _showSnackBar('✅ تم اختيار الملف من: $sourcePath');
    } catch (e) {
      _showSnackBar("حدث خطأ أثناء المعالجة: $e");
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  // ===================== معالجة الأرقام العربية =====================
  String _convertArabicHindiDigits(String input) {
    const arabicDigits = {
      '٠': '0', '١': '1', '٢': '2', '٣': '3', '٤': '4',
      '٥': '5', '٦': '6', '٧': '7', '٨': '8', '٩': '9',
    };
    String output = input;
    arabicDigits.forEach((arabic, english) {
      output = output.replaceAll(arabic, english);
    });
    return output.replaceAll(RegExp(r'[^0-9.]'), '');
  }

  String _extractNumber(String text) {
    final converted = _convertArabicHindiDigits(text);
    final match = RegExp(r'\d+').firstMatch(converted);
    return match?.group(0) ?? '';
  }

  // ===================== قص الصورة إلى مناطق =====================
  Future<_ImageRegions?> _cropImageRegions(Uint8List imageBytes, Size imageSize) async {
    try {
      final img.Image? fullImage = img.decodeImage(imageBytes);
      if (fullImage == null) return null;

      final int width = fullImage.width;
      final int height = fullImage.height;
      final int regionWidth = width ~/ 3;

      final leftRegionImg = img.copyCrop(fullImage, x: 0, y: 0, width: regionWidth, height: height);
      final centerRegionImg = img.copyCrop(fullImage, x: regionWidth, y: 0, width: regionWidth, height: height);
      final rightRegionImg = img.copyCrop(fullImage, x: regionWidth * 2, y: 0, width: regionWidth, height: height);

      return _ImageRegions(
        leftRegion: Uint8List.fromList(img.encodePng(leftRegionImg)),
        centerRegion: Uint8List.fromList(img.encodePng(centerRegionImg)),
        rightRegion: Uint8List.fromList(img.encodePng(rightRegionImg)),
      );
    } catch (e) {
      print('خطأ في القص: $e');
      return null;
    }
  }

  Future<String> _recognizeTextFromBytes(Uint8List bytes) async {
    try {
      final tempDir = await Directory.systemTemp.createTemp('ocr_');
      final tempFile = File('${tempDir.path}/image.png');
      await tempFile.writeAsBytes(bytes);

      final inputImage = InputImage.fromFile(tempFile);
      final RecognizedText recognized = await _textRecognizer.processImage(inputImage);

      await tempFile.delete();
      await tempDir.delete();

      return recognized.text.trim();
    } catch (e) {
      print('خطأ في OCR: $e');
      return '';
    }
  }

  // ===================== معالجة الصورة الملتقطة =====================
  Future<void> _processCapturedImage(BarcodeCapture capture) async {
    if (capture.barcodes.isEmpty || capture.barcodes.first.rawValue == null) return;

    final String qrValue = capture.barcodes.first.rawValue!;

    await _cameraController.stop();

    setState(() {
      _secretIdResult = qrValue;
      _gradeController.clear();
    });

    if (capture.image == null) {
      _showSnackBar("⚠️ لم يتم التقاط الصورة، حاول مجدداً");
      return;
    }

    final regions = await _cropImageRegions(capture.image!, capture.size);
    if (regions == null) {
      _showSnackBar("⚠️ فشل في قص الصورة");
      return;
    }

    String subjectCode = '';
    if (regions.rightRegion != null) {
      final rightText = await _recognizeTextFromBytes(regions.rightRegion!);
      subjectCode = _extractNumber(rightText);
      print('📚 رقم المادة المقروء: $subjectCode');
    }

    String gradeText = '';
    if (regions.leftRegion != null) {
      final leftText = await _recognizeTextFromBytes(regions.leftRegion!);
      gradeText = _extractNumber(leftText);
      print('⭐ الدرجة المقروءة: $gradeText');
    }

    if (_selectedSubject == null) {
      _showSnackBar("⚠️ يرجى اختيار المادة أولاً");
      if (_isScanningActive) await _cameraController.start();
      return;
    }

    int currentSubjectIndex = _subjects.indexOf(_selectedSubject!) + 1;

    if (subjectCode.isNotEmpty && subjectCode != currentSubjectIndex.toString()) {
      _showDialogAlert(
        title: "⚠️ تنبيه: عدم تطابق المادة",
        message: "رقم المادة المقروء ($subjectCode) لا يطابق المادة المختارة (${_selectedSubject} - رقم $currentSubjectIndex)\n\nتم إيقاف العملية لحماية الكنترول.",
        shouldCloseCamera: true,
      );
      return;
    }

    if (gradeText.isNotEmpty) {
      setState(() {
        _gradeController.text = gradeText;
      });
      _showSnackBar("✅ تم قراءة الدرجة: $gradeText");
    } else {
      _showSnackBar("ℹ️ لم يتم التعرف على الدرجة، أدخلها يدوياً");
    }

    if (_isScanningActive) {
      await _cameraController.start();
    }
  }

  // ===================== حفظ الدرجة في Excel (كتابة مباشرة على الملف الأصلي) =====================
  Future<void> _saveGradeToExcel() async {
    if (_excelInstance == null || _selectedFilePath == null) {
      _showSnackBar("⚠️ خطأ: لم يتم تحميل ملف إكسيل بعد!");
      return;
    }

    setState(() { _isLoading = true; });

    try {
      var sheet = _excelInstance!.tables.values.first;
      bool targetFound = false;
      int subjectColumnIndex = 4 + _subjects.indexOf(_selectedSubject!);

      // البحث عن الطالب في العمود D
      for (int rowIndex = 1; rowIndex < sheet.maxRows; rowIndex++) {
        var cellD = sheet.cell(px.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex)).value;

        if (cellD.toString().trim() == _secretIdResult.trim()) {
          targetFound = true;

          var existingValue = sheet.cell(px.CellIndex.indexByColumnRow(
            columnIndex: subjectColumnIndex,
            rowIndex: rowIndex
          )).value;

          if (existingValue != null && existingValue.toString().trim().isNotEmpty) {
            setState(() { _isLoading = false; });
            _showDialogAlert(
              title: "⚠️ تنبيه: رصد مسبق!",
              message: "هذا الطالب (الرقم السري: $_secretIdResult) تم رصد درجته مسبقاً في هذه المادة وهي (${existingValue.toString()}).",
              shouldCloseCamera: false,
            );
            return;
          }

          sheet.cell(px.CellIndex.indexByColumnRow(
            columnIndex: subjectColumnIndex,
            rowIndex: rowIndex
          )).value = px.TextCellValue(_gradeController.text);
          break;
        }
      }

      if (!targetFound) {
        _showSnackBar("❌ لم يتم العثور على الرقم السري ($_secretIdResult) في الملف!");
        setState(() { _isLoading = false; });
        return;
      }

      // ترميز الملف
      final List<int>? fileBytesList = _excelInstance!.encode();
      if (fileBytesList == null) {
        _showSnackBar("❌ فشل في ترميز الملف");
        setState(() { _isLoading = false; });
        return;
      }
      final Uint8List fileBytes = Uint8List.fromList(fileBytesList);

      // ===== الكتابة مباشرة على الملف الأصلي =====
      final String currentPath = _selectedFilePath!;
      final File targetFile = File(currentPath);

      bool saved = false;

      try {
        // محاولة الكتابة المباشرة
        if (await targetFile.exists()) {
          await targetFile.writeAsBytes(fileBytes, flush: true);
          saved = true;
        } else {
          _showSnackBar("❌ الملف غير موجود في المسار المحدد!");
          setState(() { _isLoading = false; });
          return;
        }
      } catch (e) {
        print('فشلت الكتابة المباشرة: $e');
        // إذا فشلت الكتابة المباشرة، نستخدم FilePicker كحل احتياطي
        try {
          final String? newPath = await FilePicker.platform.saveFile(
            dialogTitle: 'حفظ ملف الأكسيل المحدث',
            fileName: currentPath.split('/').last,
            bytes: fileBytes,
          );
          if (newPath != null) {
            // تحديث المسار إلى الموقع الجديد
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('last_excel_file', newPath);
            setState(() {
              _selectedFilePath = newPath;
              _fileName = newPath.split('/').last;
            });
            saved = true;
            _showSnackBar("✅ تم حفظ الدرجة في موقع جديد: $newPath");
          } else {
            _showSnackBar("❌ تم إلغاء الحفظ");
          }
        } catch (e2) {
          _showSnackBar("❌ فشل حفظ الملف حتى بالطريقة الاحتياطية: $e2");
        }
      }

      if (saved) {
        setState(() {
          _gradedStudents += 1;
          _secretIdResult = "سيظهر هنا الرقم السري";
          _gradeController.clear();
          _isScanningActive = false;
        });
        // إذا تم الحفظ بنجاح (بالمباشرة أو الاحتياطي)
        if (!saved) {
          // تم التعامل مع الفشل أعلاه
        } else {
          _showSnackBar("✅ تم حفظ الدرجة بنجاح في: $currentPath");
        }
      }

    } catch (e) {
      _showSnackBar("❌ خطأ في الحفظ: $e");
      print('خطأ الحفظ: $e');
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  // ===================== دوال مساعدة =====================
  void _showDialogAlert({required String title, required String message, required bool shouldCloseCamera}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          content: Text(message),
          actions: [
            TextButton(
              child: const Text("حسناً"),
              onPressed: () {
                Navigator.of(context).pop();
                if (shouldCloseCamera) {
                  setState(() { _isScanningActive = false; });
                } else {
                  if (_isScanningActive) _cameraController.start();
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _toggleScanning() async {
    if (_selectedSubject == null) {
      _showSnackBar("يرجى اختيار المادة المراد رصدها أولاً قبل بدء المسح!");
      return;
    }

    setState(() { _isScanningActive = !_isScanningActive; });

    if (_isScanningActive) {
      await _cameraController.start();
      if (_isTorchOn) await _cameraController.toggleTorch();
    } else {
      await _cameraController.stop();
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // ===================== واجهة المستخدم =====================
  @override
  Widget build(BuildContext context) {
    Color appBarColor = Colors.lightBlue.shade300;
    Color backgroundColor = Colors.lightBlue.shade50;
    Color fieldColor = Colors.white;
    Color textColor = Colors.black87;

    bool isSaveButtonEnabled = _secretIdResult != "سيظهر هنا الرقم السري" && !_isLoading;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text("إدخال الدرجات من أوراق الإجابة"),
        centerTitle: true,
        backgroundColor: appBarColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: _pickAndParseExcel,
            tooltip: 'اختيار ملف Excel',
          ),
          IconButton(
            icon: Icon(_isTorchOn ? Icons.flash_on : Icons.flash_off),
            onPressed: () async {
              setState(() { _isTorchOn = !_isTorchOn; });
              if (_isScanningActive) await _cameraController.toggleTorch();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                minimumSize: const Size.fromHeight(50),
              ),
              onPressed: _isLoading ? null : _pickAndParseExcel,
              child: _isLoading
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("اختر ملف الأكسيل", style: TextStyle(fontSize: 18, color: Colors.white)),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: fieldColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.withOpacity(0.3)),
              ),
              child: Text(_fileName, style: TextStyle(color: textColor), textAlign: TextAlign.center),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Text("اختر المادة :", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: fieldColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.withOpacity(0.3)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  dropdownColor: fieldColor,
                  isExpanded: true,
                  hint: const Text("انقر لتحديد المادة", style: TextStyle(color: Colors.grey)),
                  value: _selectedSubject,
                  items: _subjects.isEmpty
                      ? null
                      : _subjects.map((sub) {
                          return DropdownMenuItem(
                            value: sub,
                            child: Text(sub, style: TextStyle(color: textColor)),
                          );
                        }).toList(),
                  onChanged: (val) {
                    setState(() { _selectedSubject = val; });
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Text("الرقم السري :", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: fieldColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.withOpacity(0.3)),
              ),
              child: Text(
                _secretIdResult,
                style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text("الدرجة :", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _gradeController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          fillColor: fieldColor,
                          filled: true,
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text("العداد :", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: fieldColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade500),
                        ),
                        child: Text(
                          "$_gradedStudents / $_totalStudents",
                          style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isScanningActive ? Colors.red : Colors.green,
                minimumSize: const Size.fromHeight(50),
              ),
              onPressed: _toggleScanning,
              child: Text(
                _isScanningActive ? "إيقاف المسح" : "ابدأ المسح",
                style: const TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                minimumSize: const Size.fromHeight(50),
              ),
              onPressed: isSaveButtonEnabled ? _saveGradeToExcel : null,
              child: _isLoading
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white))
                  : const Text(
                      "تأكيد وحفظ الدرجة",
                      style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              height: 250,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _isScanningActive ? Colors.greenAccent : Colors.grey, width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: _isScanningActive
                    ? MobileScanner(
                        controller: _cameraController,
                        onDetect: (capture) {
                          _processCapturedImage(capture);
                        },
                      )
                    : const Center(
                        child: Text(
                          "اضغط 'ابدأ المسح' لتشغيل الكاميرا",
                          style: TextStyle(color: Colors.white70),
                          textAlign: TextAlign.center,
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
