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
  
  // قائمة الصفوف المتاحة (ثابتة بحسب المراحل)
  final List<String> _classes = ["رابع", "خامس", "سادس", "سابع", "ثامن", "تاسع"];
  String? _selectedClass;

  // قائمة المواد ستصبح ديناميكية تتغير بحسب ملف الأكسيل
  List<String> _subjects = [];
  String? _selectedSubject;

  bool _isGenerating = false;

  // دالة اختيار ملف الإكسيل وقراءة أسماء المواد ديناميكياً
  Future<void> _pickExcelFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
    );

    if (result != null && result.files.single.path != null) {
      var bytes = File(result.files.single.path!).readAsBytesSync();
      var excel = Excel.decodeBytes(bytes);
      String sheetName = excel.tables.keys.first;
      var sheet = excel.tables[sheetName]!;

      List<String> extractedSubjects = [];
      
      // قراءة الصف الأول (رؤوس الأعمدة) من العمود E (مؤشر 4) إلى العمود S (مؤشر 18)
      if (sheet.maxRows > 0) {
        var firstRow = sheet.rows.first;
        int endColumn = sheet.maxCols < 19 ? sheet.maxCols : 19; // لضمان عدم تجاوز حدود الملف
        
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
        _selectedSubject = null; // إعادة تعيين المادة المختارة عند رفع ملف جديد
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("تم تحميل ملف الأكسيل واستخراج المواد بنجاح", textAlign: TextAlign.center)),
      );
    }
  }

  // دالة اختيار المجلد وتوجيهه تلقائياً إلى مجلد "qr_pict"
  Future<void> _pickQrFolder() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

    if (selectedDirectory != null) {
      // دمج المسار المختار مع اسم المجلد الثابت qr_pict ليتوافق مع تطبيقك الآخر
      String autoTargetFolder = "$selectedDirectory/qr_pict";
      
      setState(() {
        _qrFolderPath = autoTargetFolder;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("تم ربط مسار رموز الـ QR بمجلد qr_pict بنجاح", textAlign: TextAlign.center)),
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

    // التحقق من وجود مجلد qr_pict فعلياً لتفادي توقف التطبيق
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
      // جلب رقم ترتيب المادة بناءً على موقعها المكتشف من الإكسيل (index + 1)
      int subjectOrderNumber = _subjects.indexOf(_selectedSubject!) + 1;
      
      // اختيار مجلد حفظ ملف الـ PDF النهائي
      String? outputDirectory = await FilePicker.platform.getDirectoryPath();
      
      if (outputDirectory != null) {
        String resultPath = await PdfGeneratorService.generatePapers(
          excelData: _excelData!,
          qrFolderPath: _qrFolderPath!,
          selectedClass: _selectedClass!,
          selectedSubject: subjectOrderNumber.toString(), // نمرر الرقم الترتيبي للمادة هنا (1، 2، 3...)
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
    } final {
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

              // قائمة اختيار المادة (تظهر خياراتها ديناميكياً بعد رفع الإكسيل)
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

              // زر تحديد المجلد الذي يحتوي على qr_pict
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
