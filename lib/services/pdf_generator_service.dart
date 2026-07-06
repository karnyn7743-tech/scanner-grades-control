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

    // الحل البديل والمضمون للخط العربي: تحميل خط Arial أو الخط الافتراضي المدعوم للعربية
    // سنقوم بجلب الخط من الـ Google Fonts المدمجة أو عبر الـ Network/Assets بأسلوب آمن
    final fontData = await rootBundle.load("assets/fonts/Amiri_Regular.ttf");
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
          pageFormat: PdfPageFormat.a4.copyWith(
            marginTop: 4 * PdfPageFormat.mm,
            marginBottom: 4 * PdfPageFormat.mm,
            marginLeft: 4 * PdfPageFormat.mm,
            marginRight: 4 * PdfPageFormat.mm,
          ),
          // إجبار الثيم كاملاً بكل تفرعاته على استخدام الخط العربي
          theme: pw.ThemeData.withFont(
            base: ttfFont,
            bold: ttfFont,
            italic: ttfFont,
          ).copyWith(
            defaultTextStyle: pw.TextStyle(font: ttfFont, fontSize: 14),
          ),
          build: (pw.Context context) {
            return pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  // ====== أعلى يسار الصفحة ======
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.start,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey400, width: 1),
                        ),
                        child: pw.Row(
                          children: [
                            // تمرير مخصّص للخط في كل قطعة نصية لحماية النص من التلف
                            pw.Text("اسم الطالب: $studentName", style: pw.TextStyle(font: ttfFont, fontSize: 14)),
                            pw.SizedBox(width: 25),
                            pw.Text("رقم القيد: $studentId", style: pw.TextStyle(font: ttfFont, fontSize: 14)),
                          ],
                        ),
                      ),
                    ],
                  ),

                  pw.Spacer(),

                  // ====== أسفل الصفحة ======
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
                            decoration: pw.BoxDecoration(
                              border: pw.Border.all(color: PdfColors.black, width: 1.5),
                            ),
                            child: pw.Text(
                              selectedSubject,
                              style: pw.TextStyle(font: ttfFont, fontSize: 16, fontWeight: pw.FontWeight.bold),
                            ),
                          ),
                          pw.SizedBox(width: 10),

                          // 2. [رمز الاستجابة السريعة QR]
                          pw.Container(
                            width: 40,
                            height: 40,
                            decoration: pw.BoxDecoration(
                              border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                            ),
                            child: qrImage != null
                                ? pw.Image(qrImage, fit: pw.BoxFit.cover)
                                : pw.SizedBox(), 
                          ),
                          pw.SizedBox(width: 10),

                          // 3. [مربع رصد الدرجة]
                          pw.Container(
                            width: 40,
                            height: 40,
                            decoration: pw.BoxDecoration(
                              color: const PdfColor.fromInt(0xFFEBF3F9),
                              border: pw.Border.all(color: PdfColors.blueAccent, width: 1.5),
                            ),
                            child: pw.SizedBox(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
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
