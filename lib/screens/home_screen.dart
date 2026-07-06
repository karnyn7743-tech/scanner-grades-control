import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import 'dart:io';
import '../services/pdf_generator_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? super.key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Excel? _excelData;
  String? _excelPath;
  String? _qrFolderPath;
  
  // قائمة الصفوف المتاحة
  final List<String> _classes = ["رابع", "خامس", "سادس", "سابع", "ثامن", "تاسع"];
  String? _selectedClass;

  // قائمة المواد الترتيبية (سيتم تمرير رقم ترتيب المادة تلقائياً للـ PDF)
  final List<String> _subjects = [
    "القرآن الكريم", // رقم الترتيب: 1
    "التربية الإسلامية", // رقم الترتيب: 2
    "اللغة العربية",
    "اللغة الإنجليزية"
    "الرياضيات",
    "العلوم",
    "الاجتماعيات"
    "الفيزياء"
    "الكيمياء "
    "الأحياء "
    "الجغرافيا "
    "التااريخ "
    "المجتمع "
  ];
  String? _selectedSubject;

  bool _isGenerating = false;

  // دالة اختيار ملف الإكسيل
  Future<void> _pickExcelFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'xlsm', 'xlsb'],
    );

    if (result != null && result.files.single.path != null) {
      var bytes = File(result.files.single.path!).readAsBytesSync();
      setState(() {
        _excelPath = result.files.single.path;
        _excelData = Excel.decodeBytes(bytes);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("تم تحميل ملف الأكسيل بنجاح", textAlign: TextAlign.center)),
      );
    }
  }

  // دالة اختيار مجلد الـ QR
  Future<void> _pickQrFolder() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

    if (selectedDirectory != null) {
      setState(() {
        _qrFolderPath = selectedDirectory;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("تم تحديد مسار مجلد الـ QR بنجاح", textAlign: TextAlign.center)),
      );
    }
  }

  // دالة بدء التوليد
  Future<void> _startPdfGeneration() async {
    if (_excelData == null || _qrFolderPath == null || _selectedClass == null || _selectedSubject == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("الرجاء إدخال واختيار جميع البيانات المطلوبة", textAlign: TextAlign.center), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
    });

    try {
      // جلب رقم ترتيب المادة (index + 1) لإرساله كمربع المادة في الأسفل
      int subjectIndex = _subjects.indexOf(_selectedSubject!) + 1;
      
      // اختيار مجلد حفظ ملف الـ PDF النهائي
      String? outputDirectory = await FilePicker.platform.getDirectoryPath();
      
      if (outputDirectory != null) {
        String resultPath = await PdfGeneratorService.generatePapers(
          excelData: _excelData!,
          qrFolderPath: _qrFolderPath!,
          selectedClass: _selectedClass!,
          selectedSubject: subjectIndex.toString(), // نمرر الرقم الترتيبي للمادة هنا كـ String
          outputPath: outputDirectory,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("تم توليد وحفظ الملف بنجاح في:\n$resultPath", textAlign: TextAlign.center), backgroundColor: Colors.green),
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
              
              // زر اختيار ملف الإكسيل
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

              // قائمة اختيار الصف
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: "اختر الصف الدراسي", border: OutlineInputBorder()),
                value: _selectedClass,
                items: _classes.map((String value) {
                  return DropdownMenuItem<String>(value: value, child: Text(value));
                }).toList(),
                onChanged: (value) => setState(() => _selectedClass = value),
              ),

              const SizedBox(height: 20),

              // قائمة اختيار المادة
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: "اختر المادة الدراسية", border: OutlineInputBorder()),
                value: _selectedSubject,
                items: _subjects.map((String value) {
                  return DropdownMenuItem<String>(value: value, child: Text(value));
                }).toList(),
                onChanged: (value) => setState(() => _selectedSubject = value),
              ),

              const SizedBox(height: 20),

              // زر تحديد مجلد الـ QR
              ElevatedButton.icon(
                onPressed: _pickQrFolder,
                icon: const Icon(Icons.folder),
                label: Text(_qrFolderPath == null ? "تحديد مسار مجلد رموز الـ QR" : "تم تحديد مسار مجلد الـ QR"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _qrFolderPath == null ? Colors.blueGrey : Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),

              const SizedBox(height: 40),

              // زر التوليد النهائي
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
