import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import 'dart:io';
import '../services/pdf_generator_service.dart';

class HomeScreen extends StatefulWidget {
  // تم الإصلاح هنا: صيغة مفتاح السوبر الصحيحة والحديثة
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Excel? _excelData;
  String? _excelPath;
  String? _qrFolderPath;
  
  final List<String> _classes =["ثالث", "رابع", "خامس", "سادس", "سابع", "ثامن", "تاسع", "اول ثانوي", "ثاني ثانوي"];
  String? _selectedClass;

  List<String> _subjects = [];
  String? _selectedSubject;

  bool _isGenerating = false;

  Future<void> _pickExcelFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'xlsm', 'xlsb'],
    );

    if (result != null && result.files.single.path != null) {
      var bytes = File(result.files.single.path!).readAsBytesSync();
      var excel = Excel.decodeBytes(bytes);
      String sheetName = excel.tables.keys.first;
      var sheet = excel.tables[sheetName]!;

      List<String> extractedSubjects = [];
      
      if (sheet.maxRows > 0) {
        var firstRow = sheet.rows.first;
        // تم الإصلاح هنا: تحويل maxCols إلى maxColumns لتتوافق مع إصدار الحزمة الحديث
        int endColumn = sheet.maxColumns < 19 ? sheet.maxColumns : 19; 
        
        for (int i = 4; i < endColumn; i++) {
          var cellValue = firstRow[i]?.value?.toString().trim();
          if (cellValue != null && cellValue.isNotEmpty) {
            extractedSubjects.add(cellValue);
          }
        }
      }

      setState(() {
        _excelPath = result.files.single.path;
        _excelData = excel;
        _subjects = extractedSubjects;
        _selectedSubject = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("تم تحميل ملف الأكسيل واستخراج المواد بنجاح", textAlign: TextAlign.center)),
      );
    }
  }

  Future<void> _pickQrFolder() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

    if (selectedDirectory != null) {
      String autoTargetFolder = "$selectedDirectory/qr_pict";
      
      setState(() {
        _qrFolderPath = autoTargetFolder;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("تم ربط مسار رموز الـ QR بمجلد qr_pict بنجاح", textAlign: TextAlign.center)),
      );
    }
  }

  Future<void> _startPdfGeneration() async {
    if (_excelData == null || _qrFolderPath == null || _selectedClass == null || _selectedSubject == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("الرجاء إدخال واختيار جميع البيانات المطلوبة", textAlign: TextAlign.center), backgroundColor: Colors.orange),
      );
      return;
    }

    if (!await Directory(_qrFolderPath!).exists()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("خطأ: لم يتم العثور على مجلد اسمه 'qr_pict' في المسار المحدد!", textAlign: TextAlign.center), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
    });

    try {
      int subjectOrderNumber = _subjects.indexOf(_selectedSubject!) + 1;
      
      String? outputDirectory = await FilePicker.platform.getDirectoryPath();
      
      if (outputDirectory != null) {
        String resultPath = await PdfGeneratorService.generatePapers(
          excelData: _excelData!,
          qrFolderPath: _qrFolderPath!,
          selectedClass: _selectedClass!,
          selectedSubject: subjectOrderNumber.toString(),
          outputPath: outputDirectory,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("تم توليد وحفظ أوراق الاختبار بنجاح:\n$resultPath", textAlign: TextAlign.center), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("خطأ أثناء توليد أوراق الاختبارات: $e", textAlign: TextAlign.center), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("إعداد وتوليد أوراق الاختبارات", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
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
                icon: const Icon(Icons.attach_file),
                label: Text(_excelPath == null ? "تحميل ملف الأكسيل للطلاب" : "تم تحميل ملف الأكسيل بنجاح"),
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
                  border: OutlineInputBorder()
                ),
                value: _selectedSubject,
                items: _subjects.map((String value) {
                  return DropdownMenuItem<String>(value: value, child: Text(value));
                }).toList(),
                onChanged: (value) => setState(() => _selectedSubject = value),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _pickQrFolder,
                icon: const Icon(Icons.folder_shared),
                label: Text(_qrFolderPath == null ? "تحديد المجلد الرئيسي (المحتوي على qr_pict)" : "تم ربط مجلد qr_pict الفعلي"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _qrFolderPath == null ? Colors.blueGrey : Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
              const SizedBox(height: 40),
              _isGenerating
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _startPdfGeneration,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                      ),
                      child: const Text("ابدأ توليد وحفظ أوراق الاختبار (PDF)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
