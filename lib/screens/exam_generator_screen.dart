import 'dart:io';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../services/pdf_generator_service.dart'; // استيراد خدمة توليد الـ PDF

class ExamGeneratorScreen extends StatefulWidget {
  const ExamGeneratorScreen({Key? key}) : super(key: key);

  @override
  _ExamGeneratorScreenState createState() => _ExamGeneratorScreenState();
}

class _ExamGeneratorScreenState extends State<ExamGeneratorScreen> {
  String? _excelPath;
  String? _qrFolderPath;
  String? _selectedClass;
  String? _selectedSubject;

  List<String> _classesList = [];
  List<String> _subjectsList = [];
  Excel? _excelData;
  bool _isLoading = false;

  // 1. دالة اختيار ملف الإكسيل وقراءة البيانات ديناميكياً
  Future<void> _pickExcelFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _excelPath = result.files.single.path;
        _isLoading = true;
        _classesList.clear();
        _subjectsList.clear();
        _selectedClass = null;
        _selectedSubject = null;
      });

      try {
        var bytes = File(_excelPath!).readAsBytesSync();
        _excelData = Excel.decodeBytes(bytes);

        String sheetName = _excelData!.tables.keys.first;
        var sheet = _excelData!.tables[sheetName]!;

        // قراءة رؤوس الأعمدة من E إلى S (برمجياً الفهرس من 4 إلى 18) لتعبئة قائمة المواد
        var headerRow = sheet.rows.first;
        for (int i = 4; i <= 18; i++) {
          if (i < headerRow.length && headerRow[i] != null) {
            String subjectName = headerRow[i]!.value.toString().trim();
            if (subjectName.isNotEmpty && subjectName != 'null') {
              _subjectsList.add(subjectName);
            }
          }
        }

        // قراءة الصفوف المتاحة من العمود C (الفهرس 2 برمجياً) بدون تكرار
        for (int i = 1; i < sheet.maxRows; i++) {
          var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: i));
          if (cell.value != null) {
            String className = cell.value.toString().trim();
            if (className.isNotEmpty && className != 'null' && !_classesList.contains(className)) {
              _classesList.add(className);
            }
          }
        }
      } catch (e) {
        _showSnackBar("حدث خطأ أثناء قراءة ملف الإكسيل: $e");
      }

      setState(() => _isLoading = false);
    }
  }

  // 2. دالة اختيار مجلد صور الـ QR من ذاكرة الهاتف
  Future<void> _pickQRFolder() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory != null) {
      setState(() {
        _qrFolderPath = selectedDirectory;
      });
    }
  }

  // 3. دالة استدعاء المعالجة وتوليد الملف
  Future<void> _startGeneration() async {
    if (_excelData == null || _qrFolderPath == null || _selectedClass == null || _selectedSubject == null) return;

    setState(() => _isLoading = true);

    try {
      // الحصول على مسار التخزين الخارجي في الهاتف لحفظ الـ PDF الناتج فيه
      final outputDir = await getExternalStorageDirectory();
      String outputPath = outputDir!.path;

      // استدعاء الخدمة وتشغيل الحلقة التكرارية لإنشاء الصفحات
      String finalPath = await PdfGeneratorService.generatePapers(
        excelData: _excelData!,
        qrFolderPath: _qrFolderPath!,
        selectedClass: _selectedClass!,
        selectedSubject: _selectedSubject!,
        outputPath: outputPath,
      );

      _showSnackBar("تم توليد الملف بنجاح في: $finalPath", isSuccess: true);
    } catch (e) {
      _showSnackBar("خطأ أثناء توليد أوراق الاختبارات: $e");
    }

    setState(() => _isLoading = false);
  }

  void _showSnackBar(String message, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Cairo'), textDirection: TextDirection.rtl),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // التحقق من استيفاء كافة الشروط لتفعيل زر البدء تلقائياً
    bool isButtonEnabled = _excelPath != null && _qrFolderPath != null && _selectedClass != null && _selectedSubject != null;

    return Scaffold(
      backgroundColor: const Color(0xffeef7fe),
      appBar: AppBar(
        title: const Text('إعداد وتوليد أوراق الاختبارات'),
        backgroundColor: const Color(0xff029ae4),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // الخطوة 1: اختيار ملف الإكسيل
                    ElevatedButton.icon(
                      onPressed: _pickExcelFile,
                      icon: const Icon(Icons.file_present, color: Colors.white),
                      label: Text(_excelPath == null ? "1. اختيار ملف الأكسيل المفهرس" : "تم تحميل ملف الأكسيل بنجاح"),
                      style: ElevatedButton.styleFrom(backgroundColor: _excelPath == null ? const Color(0xff029ae4) : Colors.blueGrey),
                    ),
                    const SizedBox(height: 20),

                    // الخطوة 2: اختيار الصف (العمود C)
                    DropdownButtonFormField<String>(
                      value: _selectedClass,
                      hint: const Text("3. اختر الصف المستهدف للطباعة (العمود C)"),
                      items: _classesList.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (val) => setState(() => _selectedClass = val),
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 20),

                    // الخطوة 3: اختيار المادة من (E إلى S)
                    DropdownButtonFormField<String>(
                      value: _selectedSubject,
                      hint: const Text("2. اختر مادة الاختبار (رؤوس الأعمدة E-S)"),
                      items: _subjectsList.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      onChanged: (val) => setState(() => _selectedSubject = val),
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 20),

                    // الخطوة 4: تحديد مسار صور الـ QR
                    ElevatedButton.icon(
                      onPressed: _pickQRFolder,
                      icon: const Icon(Icons.folder, color: Colors.white),
                      label: Text(_qrFolderPath == null ? "4. حدد مجلد رموز الاستجابة (QR Codes)" : "تم تحديد مسار مجلد الـ QR"),
                      style: ElevatedButton.styleFrom(backgroundColor: _qrFolderPath == null ? const Color(0xff029ae4) : Colors.blueGrey),
                    ),
                    
                    const Spacer(),

                    // الزر النهائي الذي يعتمد على الحلقات التكرارية الذكية
                    ElevatedButton(
                      onPressed: isButtonEnabled ? _startGeneration : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isButtonEnabled ? const Color(0xff00a65a) : Colors.grey,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        "بدء توليد أوراق الاختبارات",
                        style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

