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
      // 1. التحقق من إذن التخزين
      var status = await Permission.storage.request();
      if (!status.isGranted) {
        print('❌ إذن التخزين مرفوض');
        return;
      }

      // 2. تحميل الخط مع معالجة الأخطاء
      pw.Font? arabicFont;
      try {
        var fontData = await rootBundle.load("assets/fonts/Cairo-Regular.ttf");
        arabicFont = pw.Font.ttf(fontData);
        print('✅ تم تحميل الخط');
      } catch (e) {
        print('⚠️ فشل تحميل الخط، استخدام Helvetica: $e');
        arabicFont = pw.Font.helvetica();
      }

      // 3. قراءة ملف الإكسيل
      var excelFile = await _getExcelFile();
      if (excelFile == null) {
        print('❌ ملف الإكسيل غير موجود');
        return;
      }

      var sheet = excelFile.sheets.values.first;
      if (sheet == null || sheet.maxRows == 0) {
        print('❌ الورقة فارغة');
        return;
      }

      // 4. جمع بيانات الطلاب
      List<Map<String, String>> students = [];
      for (int i = 1; i < sheet.maxRows; i++) {
        try {
          String rowClass = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: i))
              ?.value?.toString()?.trim() ?? '';
          if (rowClass == selectedClass) {
            String id = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: i))
                ?.value?.toString()?.trim() ?? '';
            String name = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: i))
                ?.value?.toString()?.trim() ?? '';
            String subject = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: i))
                ?.value?.toString()?.trim() ?? '';
            if (subject == selectedSubject && id.isNotEmpty && name.isNotEmpty) {
              students.add({'id': id, 'name': name});
            }
          }
        } catch (e) {
          print('⚠️ خطأ في قراءة صف $i: $e');
        }
      }

      if (students.isEmpty) {
        print('❌ لا يوجد طلاب');
        return;
      }

      // 5. استخدام مجلد مؤقت بدلاً من التخزين الخارجي
      final dir = await getTemporaryDirectory();
      String folderPath = '${dir.path}/ExamPapers/$examName';
      final folder = Directory(folderPath);
      if (!await folder.exists()) {
        await folder.create(recursive: true);
      }

      // 6. توليد PDF لكل طالب
      for (var student in students) {
        String studentId = student['id']!;
        String studentName = student['name']!;

        // تحميل صورة QR (إذا وجدت)
        pw.ImageProvider? qrImageProvider;
        String qrPath = '${dir.path}/QR Codes/$studentId.png';
        if (await File(qrPath).exists()) {
          try {
            var qrBytes = await File(qrPath).readAsBytes();
            qrImageProvider = pw.MemoryImage(qrBytes);
          } catch (e) {
            print('⚠️ فشل تحميل QR للطالب $studentId: $e');
          }
        }

        // إنشاء PDF
        final pdf = pw.Document();
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: pw.EdgeInsets.all(20),
            build: (context) => pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text('اسم الطالب: $studentName',
                    style: pw.TextStyle(font: arabicFont, fontSize: 22)),
                pw.SizedBox(height: 30),
                if (qrImageProvider != null)
                  pw.Image(qrImageProvider, width: 200, height: 200),
                pw.SizedBox(height: 30),
                pw.Text('المادة: $selectedSubject',
                    style: pw.TextStyle(font: arabicFont, fontSize: 18)),
                pw.SizedBox(height: 10),
                pw.Text('الامتحان: $examName',
                    style: pw.TextStyle(font: arabicFont, fontSize: 16)),
              ],
            ),
          ),
        );

        // حفظ الملف
        String filePath = '$folderPath/$studentId.pdf';
        await File(filePath).writeAsBytes(await pdf.save());
        print('✅ تم حفظ PDF للطالب $studentId');
      }

      print('🎉 تم توليد ${students.length} ورقة بنجاح');
    } catch (e, stack) {
      print('❌ خطأ غير متوقع: $e');
      print(stack);
    }
  }

  static Future<Excel?> _getExcelFile() async {
    try {
      final dir = await getTemporaryDirectory();
      String excelPath = '${dir.path}/students_data.xlsx';
      var file = File(excelPath);
      if (!await file.exists()) {
        print('❌ ملف الإكسيل غير موجود: $excelPath');
        return null;
      }
      var bytes = await file.readAsBytes();
      return Excel.decodeBytes(bytes);
    } catch (e) {
      print('❌ فشل قراءة الإكسيل: $e');
      return null;
    }
  }
}
