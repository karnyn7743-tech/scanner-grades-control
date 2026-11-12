import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as px;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
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
  String? _selectedFilePath;
  
  // خريطة لتخزين اسم المادة والعمود الأساسي لها
  final Map<String, int> _subjectBaseColumns = {};
  List<String> _subjects = [];
  String? _selectedSubject;
  
  // اختيار الفصل الدراسي: 1 = الفصل الأول، 2 = الفصل الثاني
  int _selectedSemester = 1;

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

  Future<void> _requestPermissions() async {
    await Permission.storage.request();
    await Permission.camera.request();
    if (await Permission.manageExternalStorage.request().isGranted) {
      debugPrint("تم الحصول على صلاحية إدارة الملفات الشاملة");
    }
  }

  /// استخراج المسار العام المباشر للملف في ذاكرة الهاتف (Download/درجات الطلاب)
  Future<File> _getPublicExcelFile(String originalFileName, String sourceCachePath) async {
    Directory? externalDir = await getExternalStorageDirectory();
    String newPath = "";
    List<String> paths = externalDir!.path.split("/");
    for (int x = 1; x < paths.length; x++) {
      String folder = paths[x];
      if (folder != "Android") {
        newPath += "/$folder";
      } else {
        break;
      }
    }

    Directory targetDir = Directory("$newPath/Download/درجات الطلاب");
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    File destinationFile = File("${targetDir.path}/$originalFileName");
    
    if (!await destinationFile.exists()) {
      final sourceBytes = await File(sourceCachePath).readAsBytes();
      await destinationFile.writeAsBytes(sourceBytes, flush: true);
    }

    return destinationFile;
  }

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
      debugPrint('خطأ في تحميل آخر ملف: $e');
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

  /// قراءة ورقة statment واستخراج أسماء المواد ومواقع الأعمدة بدءاً من الصف 3
  Future<void> _parseExcelFile(String filePath) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      _excelInstance = px.Excel.decodeBytes(bytes);

      if (_excelInstance!.tables.isNotEmpty) {
        // استهداف ورقة statment حصراً
        var sheet = _excelInstance!.tables['statment'] ?? _excelInstance!.tables.values.first;

        Map<String, int> tempSubjectsMap = {};
        List<String> tempSubjectsList = [];

        // الصف الثالث في الإكسيل (rowIndex = 2) يحتوي على أسماء المواد بدءاً من العمود E (columnIndex = 4)
        const int subjectRowIndex = 2;
        if (sheet.maxRows > subjectRowIndex) {
          var row = sheet.rows[subjectRowIndex];
          for (int c = 4; c < sheet.maxColumns && c < row.length; c += 5) {
            var val = row[c]?.value?.toString().trim();
            if (val != null && val.isNotEmpty && !val.contains("المجموع")) {
              val = val.replaceAll(RegExp(r'\s+'), ' ');
              if (!tempSubjectsMap.containsKey(val)) {
                tempSubjectsMap[val] = c;
                tempSubjectsList.add(val);
              }
            }
          }
        }

        // حساب عدد الطلاب الفعلي من الصف 6 (rowIndex = 5) حيث يوجد الرقم السري في العمود D (index = 3)
        int studentsCount = 0;
        for (int r = 5; r < sheet.maxRows; r++) {
          var secVal = sheet.cell(px.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: r)).value;
          if (secVal != null && secVal.toString().trim().isNotEmpty) {
            studentsCount++;
          }
        }

        setState(() {
          _subjectBaseColumns.clear();
          _subjectBaseColumns.addAll(tempSubjectsMap);
          _subjects = tempSubjectsList;
          _totalStudents = studentsCount;
          _fileName = filePath.split('/').last;
          _selectedFilePath = filePath;
          if (_subjects.isNotEmpty && _selectedSubject == null) {
            _selectedSubject = _subjects.first;
          }
        });

        _updateGradedCount();
      }
    } catch (e) {
      _showSnackBar("خطأ في قراءة ملف الكشوفات: $e");
      setState(() {
        _fileName = "فشل في قراءة ملف الأكسيل";
        _subjects = [];
        _totalStudents = 0;
        _gradedStudents = 0;
      });
    }
  }

  /// تحديث عدد الطلاب المرصود لهم وفق المادة والفصل المحددين
  void _updateGradedCount() {
    if (_excelInstance == null || _selectedSubject == null) return;
    var sheet = _excelInstance!.tables['statment'] ?? _excelInstance!.tables.values.first;

    int? baseCol = _subjectBaseColumns[_selectedSubject!];
    if (baseCol == null) return;

    // الفصل الأول: اختبار 1 (baseCol + 1) | الفصل الثاني: اختبار 2 (baseCol + 3)
    int targetCol = baseCol + (_selectedSemester == 1 ? 1 : 3);

    int count = 0;
    for (int r = 5; r < sheet.maxRows; r++) {
      var val = sheet.cell(px.CellIndex.indexByColumnRow(columnIndex: targetCol, rowIndex: r)).value;
      if (val != null && val.toString().trim().isNotEmpty) {
        count++;
      }
    }

    setState(() {
      _gradedStudents = count;
    });
  }

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

      final String cachePath = result.files.single.path!;
      final String originalFileName = result.files.single.name;

      final File publicFile = await _getPublicExcelFile(originalFileName, cachePath);

      await _parseExcelFile(publicFile.path);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_excel_file', publicFile.path);

      _showSnackBar('✅ تم تحميل ورقة (statment) بنجاح');
    } catch (e) {
      _showSnackBar("حدث خطأ أثناء المعالجة: $e");
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  /// تحويل شامل لكافة الأرقام الهندية والمشرقية إلى إنجليزية
  String _convertArabicHindiDigits(String input) {
    const digitsMap = {
      '٠': '0', '١': '1', '٢': '2', '٣': '3', '٤': '4',
      '٥': '5', '٦': '6', '٧': '7', '٨': '8', '٩': '9',
      '۰': '0', '۱': '1', '۲': '2', '۳': '3', '۴': '4',
      '۵': '5', '۶': '6', '۷': '7', '۸': '8', '۹': '9',
    };
    String output = input;
    digitsMap.forEach((k, v) {
      output = output.replaceAll(k, v);
    });
    return output;
  }

  String _extractNumber(String text) {
    final converted = _convertArabicHindiDigits(text);
    final match = RegExp(r'\d+').firstMatch(converted);
    return match?.group(0) ?? '';
  }

  /// معالجة مسبقة تعزز وضوح الخط الأحمر والتباين البصري للأرقام المكتوبة يدوياً
  img.Image _preprocessImageForOcr(img.Image src) {
    final processed = img.Image.from(src);
    for (int y = 0; y < processed.height; y++) {
      for (int x = 0; x < processed.width; x++) {
        final pixel = processed.getPixel(x, y);
        final num r = pixel.r;
        final num g = pixel.g;
        final num b = pixel.b;

        // اكتشاف اللون الأحمر وتحويله إلى خط أسود ناصع
        if (r > 90 && (r - g) > 25 && (r - b) > 25) {
          processed.setPixelRgb(x, y, 0, 0, 0);
        }
      }
    }
    return processed;
  }

  /// قص الأقسام الثلاثة مع مراعاة الورقة المفتوحة بدون حدود مربعات
  Future<_ImageRegions?> _cropImageRegions(Uint8List imageBytes, Size imageSize) async {
    try {
      img.Image? fullImage = img.decodeImage(imageBytes);
      if (fullImage == null) return null;

      fullImage = img.bakeOrientation(fullImage);

      final int width = fullImage.width;
      final int height = fullImage.height;
      final int regionWidth = width ~/ 3;

      var leftImg = img.copyCrop(fullImage, x: 0, y: 0, width: regionWidth, height: height);
      var centerImg = img.copyCrop(fullImage, x: regionWidth, y: 0, width: regionWidth, height: height);
      var rightImg = img.copyCrop(fullImage, x: regionWidth * 2, y: 0, width: regionWidth, height: height);

      // تطبيق تعزيز الحبر لليمين واليسار
      leftImg = _preprocessImageForOcr(leftImg);
      rightImg = _preprocessImageForOcr(rightImg);

      return _ImageRegions(
        leftRegion: Uint8List.fromList(img.encodePng(leftImg)),
        centerRegion: Uint8List.fromList(img.encodePng(centerImg)),
        rightRegion: Uint8List.fromList(img.encodePng(rightImg)),
      );
    } catch (e) {
      debugPrint('خطأ في القص: $e');
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
      debugPrint('خطأ في OCR: $e');
      return '';
    }
  }

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
      debugPrint('📚 رقم المادة المقروء: $subjectCode (النص الأصلي: $rightText)');
    }

    String gradeText = '';
    if (regions.leftRegion != null) {
      final leftText = await _recognizeTextFromBytes(regions.leftRegion!);
      gradeText = _extractNumber(leftText);
      debugPrint('⭐ الدرجة المقروءة: $gradeText (النص الأصلي: $leftText)');
    }

    if (_selectedSubject == null) {
      _showSnackBar("⚠️ يرجى اختيار المادة أولاً");
      if (_isScanningActive) await _cameraController.start();
      return;
    }

    int currentSubjectIndex = _subjects.indexOf(_selectedSubject!) + 1;

    // تدقيق كود المادة: التنبيه حال عدم القراءة أو عدم التطابق
    if (subjectCode.isEmpty) {
      _showDialogAlert(
        title: "⚠️ تعذر قراءة كود المادة",
        message: "لم يتم التعرف على كود المادة في يمين الورقة. تأكد من وضوح الرقم ($currentSubjectIndex).",
        shouldCloseCamera: false,
      );
      return;
    }

    if (subjectCode != currentSubjectIndex.toString()) {
      _showDialogAlert(
        title: "⚠️ تنبيه: عدم تطابق المادة",
        message: "رقم المادة المقروء في الورقة ($subjectCode) لا يطابق المادة المختارة (${_selectedSubject} - رقم $currentSubjectIndex)\n\nتم إيقاف العملية لحماية الكنترول.",
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

  /// حفظ الدرجة مباشرة في كشف statment في عمود الاختبار المناسب للفصل المحدد
  Future<void> _saveGradeToExcel() async {
    if (_excelInstance == null || _selectedFilePath == null || _selectedSubject == null) {
      _showSnackBar("⚠️ خطأ: لم يتم تحميل ملف إكسيل أو تحديد المادة بعد!");
      return;
    }

    setState(() { _isLoading = true; });

    try {
      // استهداف ورقة statment حصراً
      var sheet = _excelInstance!.tables['statment'] ?? _excelInstance!.tables.values.first;
      
      int? baseCol = _subjectBaseColumns[_selectedSubject!];
      if (baseCol == null) {
        _showSnackBar("❌ تعذر تحديد عمود المادة!");
        setState(() { _isLoading = false; });
        return;
      }

      // تحديد عمود الرصد بناءً على الفصل الدراسي
      // الفصل الأول: اختبار 1 (baseCol + 1)
      // الفصل الثاني: اختبار 2 (baseCol + 3)
      int targetCol = baseCol + (_selectedSemester == 1 ? 1 : 3);

      bool targetFound = false;

      // البحث عن الرقم السري في العمود D (columnIndex = 3) بدءاً من الصف 6 (rowIndex = 5)
      for (int rowIndex = 5; rowIndex < sheet.maxRows; rowIndex++) {
        var cellD = sheet.cell(px.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex)).value;

        if (cellD != null && cellD.toString().trim() == _secretIdResult.trim()) {
          targetFound = true;

          // التحقق من الرصد المسبق في نفس الاختبار
          var existingValue = sheet.cell(px.CellIndex.indexByColumnRow(
            columnIndex: targetCol,
            rowIndex: rowIndex
          )).value;

          if (existingValue != null && existingValue.toString().trim().isNotEmpty) {
            setState(() { _isLoading = false; });
            _showDialogAlert(
              title: "⚠️ تنبيه: رصد مسبق!",
              message: "هذا الطالب (الرقم السري: $_secretIdResult) تم رصد درجته مسبقاً في ${_selectedSemester == 1 ? 'اختبار الفصل الأول' : 'اختبار الفصل الثاني'} لمادة ($_selectedSubject) وهي (${existingValue.toString()}).",
              shouldCloseCamera: false,
            );
            return;
          }

          // معالجة القيمة وحفظها كـ رقم بدلاً من نص
          final rawGradeStr = _convertArabicHindiDigits(_gradeController.text.trim());
          final int? intGrade = int.tryParse(rawGradeStr);
          final double? doubleGrade = double.tryParse(rawGradeStr);

          px.CellValue cellValueToSave;
          if (intGrade != null) {
            cellValueToSave = px.IntCellValue(intGrade);
          } else if (doubleGrade != null) {
            cellValueToSave = px.DoubleCellValue(doubleGrade);
          } else {
            cellValueToSave = px.TextCellValue(_gradeController.text.trim());
          }

          sheet.cell(px.CellIndex.indexByColumnRow(
            columnIndex: targetCol,
            rowIndex: rowIndex
          )).value = cellValueToSave;
          break;
        }
      }

      if (!targetFound) {
        _showSnackBar("❌ لم يتم العثور على الرقم السري ($_secretIdResult) في العمود D بكشف statment!");
        setState(() { _isLoading = false; });
        return;
      }

      final List<int>? fileBytesList = _excelInstance!.encode();
      if (fileBytesList == null) {
        _showSnackBar("❌ فشل في ترميز الملف");
        setState(() { _isLoading = false; });
        return;
      }
      final Uint8List fileBytes = Uint8List.fromList(fileBytesList);

      final String currentPath = _selectedFilePath!;
      final File targetFile = File(currentPath);

      // الكتابة المباشرة وتحديث الملف الأصلي في ذاكرة الهاتف
      await targetFile.writeAsBytes(fileBytes, flush: true);

      if (await targetFile.exists() && await targetFile.length() > 0) {
        setState(() {
          _secretIdResult = "سيظهر هنا الرقم السري";
          _gradeController.clear();
          _isScanningActive = false;
        });
        _updateGradedCount();
        _showSnackBar("✅ تم رصد الدرجة بنجاح في كشف statment");
      } else {
        _showSnackBar("❌ فشل حفظ الملف!");
      }

    } catch (e) {
      _showSnackBar("❌ خطأ في الحفظ: $e");
      debugPrint('خطأ الحفظ: $e');
    } finally {
      setState(() { _isLoading = false; });
    }
  }

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
                  : const Text("اختر ملف الأكسيل (الكشوفات)", style: TextStyle(fontSize: 18, color: Colors.white)),
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

            // اختيار الفصل الدراسي
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Center(
                      child: Text("اختبار الفصل الأول", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    selected: _selectedSemester == 1,
                    selectedColor: Colors.blueAccent,
                    labelStyle: TextStyle(
                      color: _selectedSemester == 1 ? Colors.white : Colors.black87,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() { _selectedSemester = 1; });
                        _updateGradedCount();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ChoiceChip(
                    label: const Center(
                      child: Text("اختبار الفصل الثاني", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    selected: _selectedSemester == 2,
                    selectedColor: Colors.teal,
                    labelStyle: TextStyle(
                      color: _selectedSemester == 2 ? Colors.white : Colors.black87,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() { _selectedSemester = 2; });
                        _updateGradedCount();
                      }
                    },
                  ),
                ),
              ],
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
                    _updateGradedCount();
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
