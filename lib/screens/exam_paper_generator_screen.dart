import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../services/pdf_generator_service.dart';

class ExamPaperGeneratorScreen extends StatefulWidget {
  const ExamPaperGeneratorScreen({super.key});

  @override
  State<ExamPaperGeneratorScreen> createState() => _ExamPaperGeneratorScreenState();
}

class _ExamPaperGeneratorScreenState extends State<ExamPaperGeneratorScreen> {
  String? _excelPath;
  String? _qrFolderPath;

  final List<String> _classes = [
    "ثالث", "رابع", "خامس", "سادس", "سابع", "ثامن", "تاسع", "أول ثانوي", "ثاني ثانوي", "ثالث ثانوي"
  ];
  String? _selectedClass;

  List<String> _subjects = [];
  String? _selectedSubject;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await Permission.storage.request();
    await Permission.manageExternalStorage.request();
  }

  Future<Directory> _getPublicDirectory() async {
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
    return targetDir;
  }

  Future<void> _pickExcelFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xlsm', 'xlsb', 'xls'],
    );

    if (result != null && result.files.single.path != null) {
      final String cachePath = result.files.single.path!;
      final String fileName = result.files.single.name;

      final Directory publicDir = await _getPublicDirectory();
      final File destinationFile = File("${publicDir.path}/$fileName");

      if (!await destinationFile.exists()) {
        final sourceBytes = await File(cachePath).readAsBytes();
        await destinationFile.writeAsBytes(sourceBytes, flush: true);
      }

      final File originalFile = File(cachePath);
      final String parentDirPath = originalFile.parent.path;
      final String detectedQrPath = "$parentDirPath/qr_pict";

      var bytes = await destinationFile.readAsBytes();
      var excel = Excel.decodeBytes(bytes);
      String sheetName = excel.tables.keys.first;
      var sheet = excel.tables[sheetName]!;

      List<String> extractedSubjects = [];

      if (sheet.maxRows > 0) {
        var firstRow = sheet.rows.first;
        int endColumn = sheet.maxColumns < 19 ? sheet.maxColumns : 19;

        for (int i = 4; i < endColumn; i++) {
          var cellValue = firstRow[i]?.value?.toString().trim();
          if (cellValue != null && cellValue.isNotEmpty) {
            extractedSubjects.add(cellValue);
          }
        }
      }

      setState(() {
        _excelPath = destinationFile.path;
        _qrFolderPath = detectedQrPath;
        _subjects = extractedSubjects;
        _selectedSubject = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("تم تحميل ملف الأكسيل بنجاح وجلب مسار الصور", textAlign: TextAlign.center),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _startPdfGeneration() async {
    if (_excelPath == null || _selectedClass == null || _selectedSubject == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("الرجاء إدخال واختيار جميع البيانات المطلوبة", textAlign: TextAlign.center),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
    });

    try {
      int subjectOrderNumber = _subjects.indexOf(_selectedSubject!) + 1;
      final fontData = await rootBundle.load("assets/fonts/Amiri_Regular.ttf");

      String resultPath = await PdfGeneratorService.generatePapersInIsolate(
        excelPath: _excelPath!,
        qrFolderPath: _qrFolderPath ?? "",
        selectedClass: _selectedClass!,
        selectedSubject: subjectOrderNumber.toString(),
        fontData: fontData,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("✅ تم توليد وحفظ أوراق الاختبار بنجاح:\n$resultPath", textAlign: TextAlign.center),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("خطأ أثناء توليد أوراق الاختبارات: ${e.toString().replaceAll('Exception: ', '')}", textAlign: TextAlign.center),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("توليد أوراق الاختبارات", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: ListView(
            children: [
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _pickExcelFile,
                icon: const Icon(Icons.attach_file, color: Colors.white),
                label: Text(
                  _excelPath == null ? "تحميل ملف الأكسيل للطلاب" : "تم تحميل ملف الأكسيل بنجاح",
                  style: const TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _excelPath == null ? Colors.blueGrey : Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: "اختر الصف الدراسي", border: OutlineInputBorder()),
                value: _selectedClass,
                items: _classes.map((String value) {
                  return DropdownMenuItem<String>(value: value, child: Text(value));
                }).toList(),
                onChanged: (value) => setState(() => _selectedClass = value),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: "اختر المادة الدراسية",
                  hintText: "يرجى رفع ملف الأكسيل أولاً لتظهر المواد",
                  border: OutlineInputBorder(),
                ),
                value: _selectedSubject,
                items: _subjects.map((String value) {
                  return DropdownMenuItem<String>(value: value, child: Text(value));
                }).toList(),
                onChanged: (value) => setState(() => _selectedSubject = value),
              ),
              const SizedBox(height: 40),
              _isGenerating
                  ? const Center(
                      child: Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 10),
                          Text("جاري توليد ملف الـ PDF... يرجى الانتظار"),
                        ],
                      ),
                    )
                  : ElevatedButton(
                      onPressed: _startPdfGeneration,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                      ),
                      child: const Text(
                        "ابدأ توليد وحفظ أوراق الاختبار (PDF)",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

