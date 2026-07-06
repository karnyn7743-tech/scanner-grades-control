import 'dart:io';
import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

class PdfGeneratorService {
  static Future<void> generateExamPapers({
    required String selectedClass,
    required String selectedSubject,
    required String examName,
  }) async {
    try {
      // 1. طلب إذن التخزين
      var status = await Permission.storage.request();
      if (!status.isGranted) {
        print('❌ إذن التخزين مرفوض');
        return;
      }

      // 2. تحميل الخط العربي مع معالجة الأخطاء
      pw.Font? arabicFont;
      try {
        var fontData = await rootBundle.load("assets/fonts/Cairo-Regular.ttf");
        arabicFont = pw.Font.ttf(fontData);
        print('✅ تم تحميل الخط العربي بنجاح');
      } catch (e) {
        print('⚠️ فشل تحميل الخط العربي، سيتم استخدام Helvetica بدلاً منه: $e');
        arabicFont = pw.Font.helvetica();
      }

      // 3. قراءة ملف الإكسيل
      var excelFile = await _getExcelFile();
      if (excelFile == null) {
        print('❌ ملف الإكسيل غير موجود في المسار المتوقع');
        return;
      }

      var sheets = excelFile.sheets;
      if (sheets.isEmpty) {
        print('❌ لا توجد أوراق في ملف الإكسيل');
        return;
      }

      var sheet = sheets.values.first;
      if (sheet == null || sheet.maxRows == 0) {
        print('❌ الورقة فارغة أو غير موجودة');
        return;
      }

      // 4. جمع بيانات الطلاب للصف والمادة المطلوبين
      List<Map<String, String>> students = [];
      for (int i = 1; i < sheet.maxRows; i++) {
        var classCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: i));
        var rowClass = classCell?.value?.toString()?.trim() ?? '';
        if (rowClass == selectedClass) {
          var idCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: i));
          var nameCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: i));
          var subjectCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: i));
          String id = idCell?.value?.toString()?.trim() ?? '';
          String name = nameCell?.value?.toString()?.trim() ?? '';
          String subject = subjectCell?.value?.toString()?.trim() ?? '';
          if (subject == selectedSubject && id.isNotEmpty && name.isNotEmpty) {
            students.add({'id': id, 'name': name});
          }
        }
      }

      if (students.isEmpty) {
        print('❌ لا يوجد طلاب بهذه المواصفات (الصف: $selectedClass، المادة: $selectedSubject)');
        return;
      }

      print('✅ تم العثور على ${students.length} طالب');

      // 5. تحديد مجلد الحفظ
      final dir = await getExternalStorageDirectory();
      if (dir == null) {
        print('❌ لا يمكن الوصول إلى التخزين الخارجي');
        return;
      }
      String folderPath = '${dir.path}/ExamPapers/$examName';
      final folder = Directory(folderPath);
      if (!await folder.exists()) {
        await folder.create(recursive: true);
        print('✅ تم إنشاء المجلد: $folderPath');
      }

      // 6. توليد ملف PDF لكل طالب
      for (var student in students) {
        String studentId = student['id']!;
        String studentName = student['name']!;

        // تحميل صورة QR إذا وجدت
        pw.ImageProvider? qrImageProvider;
        String qrPath = '${dir.path}/QR Codes/$studentId.png';
        if (await File(qrPath).exists()) {
          try {
            var qrBytes = await File(qrPath).readAsBytes();
            qrImageProvider = pw.MemoryImage(qrBytes);  // التغيير هنا
          } catch (e) {
            print('⚠️ فشل قراءة صورة QR للطالب $studentId: $e');
          }
        } else {
          print('⚠️ صورة QR غير موجودة للطالب $studentId في المسار: $qrPath');
        }

        // إنشاء مستند PDF
        final pdf = pw.Document();
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: pw.EdgeInsets.all(20),
            build: (context) {
              return pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    'اسم الطالب: $studentName',
                    style: pw.TextStyle(font: arabicFont, fontSize: 22),
                  ),
                  pw.SizedBox(height: 30),
                  if (qrImageProvider != null)
                    pw.Image(qrImageProvider, width: 200, height: 200),  // التغيير هنا
                  pw.SizedBox(height: 30),
                  pw.Text(
                    'المادة: $selectedSubject',
                    style: pw.TextStyle(font: arabicFont, fontSize: 18),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    'الامتحان: $examName',
                    style: pw.TextStyle(font: arabicFont, fontSize: 16),
                  ),
                ],
              );
            },
          ),
        );

        // حفظ الملف
        String filePath = '$folderPath/$studentId.pdf';
        final file = File(filePath);
        await file.writeAsBytes(await pdf.save());
        print('✅ تم حفظ PDF للطالب $studentId في: $filePath');
      }

      print('🎉 تم توليد جميع الأوراق بنجاح (${students.length})');
    } catch (e, stack) {
      print('❌ خطأ غير متوقع أثناء توليد PDF: $e');
      print(stack);
    }
  }

  // دالة مساعدة لقراءة ملف الإكسيل من المسار الثابت
  static Future<Excel?> _getExcelFile() async {
    try {
      final dir = await getExternalStorageDirectory();
      if (dir == null) return null;
      String excelPath = '${dir.path}/students_data.xlsx';
      var file = File(excelPath);
      if (!await file.exists()) {
        print('❌ ملف الإكسيل غير موجود: $excelPath');
        return null;
      }
      var bytes = await file.readAsBytes();
      return Excel.decodeBytes(bytes);
    } catch (e) {
      print('❌ فشل قراءة ملف الإكسيل: $e');
      return null;
    }
  }
}
