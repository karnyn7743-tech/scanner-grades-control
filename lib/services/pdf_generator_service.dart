import 'dart:io';
import 'package:flutter/services.dart';
import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfGeneratorService {
  static Future<String> generatePapers({
    required Excel excelData,
    required String qrFolderPath,
    required String selectedClass,
    required String selectedSubject,
    required String outputPath,
  }) async {
    final pdf = pw.Document();

    // تحميل خط القاهرة بالاسم الصحيح
    final fontData = await rootBundle.load("assets/fonts/Cairo_Regular.ttf");
    final ttfFont = pw.Font.ttf(fontData);

    String sheetName = excelData.tables.keys.first;
    var sheet = excelData.tables[sheetName]!;

    for (int i = 1; i < sheet.maxRows; i++) {
      var row = sheet.rows[i];
      if (row.isEmpty || row[0]?.value == null) continue;

      String studentName = row[0]?.value?.toString().trim() ?? "طالب مجهول";
      String studentId = row[1]?.value?.toString().trim() ?? "0000";

      final qrFile = File("$qrFolderPath/$studentId.png");
      pw.MemoryImage? qrImage;
      if (await qrFile.exists()) {
        qrImage = pw.MemoryImage(await qrFile.readAsBytes());
      }

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          theme: pw.ThemeData.withFont(base: ttfFont),
          build: (pw.Context context) {
            return pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Container(
                padding: const pw.EdgeInsets.all(20),
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    // ====== أعلى يسار الصفحة ======
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.start,
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.all(8),
                          border: pw.Border.all(color: PdfColors.grey300, width: 1),
                          child: pw.Row(
                            children: [
                              pw.Text("اسم الطالب: $studentName", style: const pw.TextStyle(fontSize: 12)),
                              pw.SizedBox(width: 20),
                              pw.Text("رقم القيد: $studentId", style: const pw.TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),

                    pw.Spacer(),

                    // ====== أسفل الصفحة أقصى اليسار بالترتيب المعتمد ======
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.start,
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            // 1. [رقم المادة الترتيبي]
                            pw.Container(
                              width: 40,
                              height: 40,
                              alignment: pw.Alignment.center,
                              border: pw.Border.all(color: PdfColors.black, width: 1.5),
                              child: pw.Text(
                                selectedSubject,
                                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                              ),
                            ),
                            pw.SizedBox(width: 10),

                            // 2. [رمز الاستجابة السريعة QR]
                            pw.Container(
                              width: 60,
                              height: 60,
                              border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                              child: qrImage != null
                                  ? pw.Image(qrImage, fit: pw.BoxFit.cover)
                                  : pw.Center(child: pw.Text("لا يوجد\nQR", style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center)),
                            ),
                            pw.SizedBox(width: 10),

                            // 3. [مربع رصد الدرجة الأزرق الفاتح جداً] - تم إصلاح الصياغة هنا باستخدام BoxDecoration
                            pw.Container(
                              width: 70,
                              height: 60,
                              decoration: pw.BoxDecoration(
                                color: const PdfColor.fromInt(0xFFEBF3F9),
                                border: pw.Border.all(color: PdfColors.blueAccent, width: 1.5),
                              ),
                              child: pw.Center(
                                child: pw.Text(
                                  "الدرجة",
                                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }

    final String finalFileName = "$outputPath/امتحانات_$selectedClass.pdf";
    final file = File(finalFileName);
    await file.writeAsBytes(await pdf.save());

    return finalFileName;
  }
}
