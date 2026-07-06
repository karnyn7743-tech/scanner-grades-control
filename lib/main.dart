import 'dart:io';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';

class ExamGeneratorScreen extends StatefulWidget {
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

  // 1. اختيار ملف الإكسيل وقراءة المواد والصفوف ديناميكياً
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

      var bytes = File(_excelPath!).readAsBytesSync();
      _excelData = Excel.decodeBytes(bytes);
      
      // نأخذ الورقة الأولى من ملف الإكسيل
      String sheetName = _excelData!.tables.keys.first;
      var sheet = _excelData!.tables[sheetName]!;

      // جلب المواد من رؤوس الأعمدة من E إلى S (الأعمدة من 4 إلى 18 في البرمجة)
      var headerRow = sheet.rows.first;
      for (int i = 4; i <= 18; i++) {
        if (i < headerRow.length && headerRow[i] != null) {
          _subjectsList.add(headerRow[i]!.value.toString().strip());
        }
      }

      // جلب الصفوف المتاحة من العمود C (العامود رقم 2 برمجياً) بدون تكرار
      for (int i = 1; i < sheet.maxRows; i++) {
        var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: i));
        if (cell.value != null) {
          String className = cell.value.toString().strip();
          if (!_classesList.contains(className)) {
            _classesList.add(className);
          }
        }
      }

      setState(() {
        _isLoading = false;
      });
    }
  }

  // 2. اختيار مسار مجلد رموز الاستجابة (QR Codes)
  Future<void> _pickQRFolder() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory != null) {
      setState(() {
        _qrFolderPath = selectedDirectory;
      });
    }
  }

  // 3. دالة بدء توليد أوراق الاختبارات بناءً على الحلقة التكرارية
  Future<void> _generateExamPapers() async {
    if (_excelData == null || _selectedClass == null || _selectedSubject == null || _qrFolderPath == null) return;

    setState(() => _isLoading = true);

    final pdf = pw.Document();
    String sheetName = _excelData!.tables.keys.first;
    var sheet = _excelData!.tables[sheetName]!;

    // الحلقة التكرارية على صفوف الطلاب
    for (int i = 1; i < sheet.maxRows; i++) {
      var classCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: i)).value?.toString().strip();
      
      // التصفية بناءً على الصف المختار (العمود C)
      if (classCell == _selectedClass) {
        String studentID = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: i)).value?.toString().strip() ?? ""; // العمود A
        String studentName = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: i)).value?.toString().strip() ?? ""; // العمود B
        
        // مسار صورة الـ QR التي تحمل اسم رقم القيد
        String qrImagePath = "$_qrFolderPath/$studentID.png";
        File qrFile = File(qrImagePath);
        
        pw.MemoryImage? qrImage;
        if (await qrFile.exists()) {
          qrImage = pw.MemoryImage(await qrFile.readAsBytes());
        }

        // بناء صفحة A4 لكل طالب في الحلقة التكرارية
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) {
              return pw.Stack(
                children: [
                  // ١- أعلى يسار الورقة: [اسم الطالب، يليه رقم قيد الطالب]
                  pw.Positioned(
                    top: 20,
                    left: 20,
                    child: pw.Column(
                      cross: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text("Name: $studentName", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 5),
                        pw.Text("ID: $studentID", style: pw.TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),

                  // مساحة منتصف الورقة مخصصة للأسئلة المطبوعة لاحقاً...

                  // ٢- أسفل يسار الورقة: [مربع رقم المادة] يليه [الـ QR] يليه [مربع الدرجة الأزرق الباهت]
                  pw.Positioned(
                    bottom: 40,
                    left: 20,
                    child: pw.Row(
                      cross: pw.CrossAxisAlignment.end,
                      children: [
                        // مربع رقم المادة المختارة
                        pw.Container(
                          width: 60,
                          height: 60,
                          decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 1)),
                          alignment: pw.Alignment.center,
                          child: pw.Text(_selectedSubject!, style: pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.center),
                        ),
                        pw.SizedBox(width: 10),

                        // صورة رمز الاستجابة السريعة (QR)
                        qrImage != null
                            ? pw.Image(qrImage, width: 60, height: 60)
                            : pw.Container(
                                width: 60,
                                height: 60,
                                decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 1)),
                                alignment: pw.Alignment.center,
                                child: pw.Text("Missing QR", style: pw.TextStyle(fontSize: 8)),
                              ),
                        pw.SizedBox(width: 10),

                        // مربع فارغ لونه أزرق باهت جداً لرصد الدرجة يدويًا بخط اليد
                        pw.Container(
                          width: 60,
                          height: 60,
                          decoration: pw.BoxDecoration(
                            color: PdfColor.fromHex("#EBF3F9"), // لون أزرق باهت جداً
                            border: pw.Border.all(color: PdfColors.black, width: 1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      }
    }

    // حفظ ملف الـ PDF في ذاكرة الهاتف
    final output = await getExternalStorageDirectory();
    final file = File("${output!.path}/Exam_Papers_${_selectedClass}_$_selectedSubject.pdf");
    await file.writeAsBytes(await pdf.save());

    setState(() => _isLoading = false);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("تم حفظ ملف PDF في المسار: ${file.path}")),
    );
  }

  @override
  Widget build(BuildContext context) {
    // تفعيل الزر فقط عند اكتمال اختيار جميع المتطلبات
    bool isButtonEnabled = _excelPath != null && _qrFolderPath != null && _selectedClass != null && _selectedSubject != null;

    return Scaffold(
      appBar: AppBar(title: Text("توليد أوراق الاختبارات المأتمتة")),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator())
        : Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(
                  onPressed: _pickExcelFile,
                  child: Text(_excelPath == null ? "1. اختيار ملف الأكسيل" : "تم اختيار ملف الأكسيل"),
                ),
                SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _selectedClass,
                  hint: Text("3. اختر الصف المراد الطباعة له (العمود C)"),
                  items: _classesList.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (val) => setState(() => _selectedClass = val),
                ),
                SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _selectedSubject,
                  hint: Text("2. اختر المادة (من رؤوس الأعمدة E-S)"),
                  items: _subjectsList.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (val) => setState(() => _selectedSubject = val),
                ),
                SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _pickQRFolder,
                  child: Text(_qrFolderPath == null ? "4. اختيار مسار رموز الاستجابة" : "تم اختيار مسار الـ QR"),
                ),
                Spacer(),
                ElevatedButton(
                  onPressed: isButtonEnabled ? _generateExamPapers : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isButtonEnabled ? Colors.green : Colors.grey,
                    padding: EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: Text("بدء توليد أوراق الاختبارات", style: TextStyle(fontSize: 16, color: Colors.white)),
                ),
              ],
            ),
          ),
    );
  }
}

// دالة مساعدة لتنظيف الفراغات حول النصوص
extension StringStrip on String {
  String strip() => this.trim();
}
