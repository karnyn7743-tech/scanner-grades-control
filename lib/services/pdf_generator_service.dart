import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfGeneratorService {
  // دالة لتوليد ملف الـ PDF بناءً على حلقة تكرارية للطلاب
  static Future<String> generatePapers({
    required Excel excelData,
    required String qrFolderPath,
    required String selectedClass,
    required String selectedSubject,
    required String outputPath,
  }) async {
    final pdf = pw.Document();
    String sheetName = excelData.tables.keys.first;
    var sheet = excelData.tables[sheetName]!;

    // تحميل الخط العربي لضمان طباعة الأسماء العربية بشكل صحيح داخل الـ PDF
    var arabicFont = pw.Font.ttf(await rootBundle.load("assets/fonts/Cairo-Regular.ttf"));

    // الحلقة التكرارية على صفوف الطلاب (تبدأ من الصف 1 لتجاوز العناوين)
    for (int i = 1; i < sheet.maxRows; i++) {
      var classCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: i)).value?.toString().trim();
      
      // التصفية بناءً على الصف المختار (العمود C)
      if (classCell == selectedClass) {
        String studentID = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: i)).value?.toString().trim() ?? "";   // العمود A
        String studentName = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: i)).value?.toString().trim() ?? ""; // العمود B
        
        // جلب صورة الـ QR التي تطابق رقم القيد
        String qrImagePath = "$qrFolderPath/$studentID.png";
        File qrFile = File(qrImagePath);
        
        pw.MemoryImage? qrImage;
        if (await qrFile.exists()) {
          qrImage = pw.MemoryImage(await qrFile.readAsBytes());
        }

        // بناء صفحة A4 مخصصة لكل طالب في الحلقة
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) {
              return pw.Directionality(
                textDirection: pw.TextDirection.rtl, // لدعم المحاذاة العربية
                child: pw.Stack(
                  children: [
                    // أعلى يسار الورقة: [اسم الطالب، يليه رقم قيد الطالب]
                    pw.Positioned(
                      top: 20,
                      left: 20,
                      child: pw.Column(
                        cross: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text("الطالب: $studentName", style: pw.TextStyle(font: arabicFont, fontSize: 14, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 5),
                          pw.Text("رقم القيد: $studentID", style: pw.TextStyle(font: arabicFont, fontSize: 12)),
                        ],
                      ),
                    ),

                    // أسفل يسار الورقة: منطقة الكنترول والأتمتة
                    pw.Positioned(
                      bottom: 40,
                      left: 20,
                      child: pw.Row(
                        cross: pw.CrossAxisAlignment.end,
                        children: [
                          // المربع الأول: مربع رقم/اسم المادة المختارة
                          pw.Container(
                            width: 60,
                            height: 60,
                            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 1)),
                            alignment: pw.Alignment.center,
                            child: pw.Text(selectedSubject, style: pw.TextStyle(font: arabicFont, fontSize: 10), textAlign: pw.TextAlign.center),
                          ),
                          pw.SizedBox(width: 10),

                          // المربع الثاني: صورة الـ QR
                          qrImage != null
                              ? pw.Image(qrImage, width: 60, height: 60)
                              : pw.Container(
                                  width: 60,
                                  height: 60,
                                  decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 1)),
                                  alignment: pw.Alignment.center,
                                  child: pw.Text("QR مفقود", style: pw.TextStyle(font: arabicFont, fontSize: 8)),
                                ),
                          pw.SizedBox(width: 10),

                          // المربع الثالث: مربع فارغ أزرق باهت جداً لرصد الدرجة بخط اليد
                          pw.Container(
                            width: 60,
                            height: 60,
                            decoration: pw.BoxDecoration(
                              color: PdfColor.fromHex("#EBF3F9"), // أزرق باهت جداً
                              border: pw.Border.all(color: PdfColors.black, width: 1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      }
    }

    // حفظ الملف النهائي
    final file = File("$outputPath/Exam_Papers_${selectedClass}_$selectedSubject.pdf");
    await file.writeAsBytes(await pdf.save());
    return file.path;
  }
}

