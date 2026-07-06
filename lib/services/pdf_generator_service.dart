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
    required String selectedSubject, // يستقبل رقم المادة الترتيبي كنص (مثل "1"، "2"...)
    required String outputPath,
  }) async {
    final pdf = pw.Document();

    // تحميل خط القاهرة بالاسم الجديد والشرطة السفلية لضمان عمله في كود ماجيك
    final fontData = await rootBundle.load("assets/fonts/Cairo_Regular.ttf");
    final ttfFont = pw.Font.ttf(fontData);

    String sheetName = excelData.tables.keys.first;
    var sheet = excelData.tables[sheetName]!;

    // تجاوز الصف الأول (رؤوس الأعمدة) والبدء في قراءة بيانات الطلاب
    for (int i = 1; i < sheet.maxRows; i++) {
      var row = sheet.rows[i];
      if (row.isEmpty || row[0]?.value == null) continue;

      // سحب بيانات الطالب (افترضنا العمود A للاسم والعمود B لرقم القيد)
      String studentName = row[0]?.value?.toString().trim() ?? "طالب مجهول";
      String studentId = row[1]?.value?.toString().trim() ?? "0000";

      // تجهيز مسار صورة الـ QR الفردية للطالب من داخل مجلد qr_pict الثابت
      final qrFile = File("$qrFolderPath/$studentId.png");
      pw.MemoryImage? qrImage;
      if (await qrFile.exists()) {
        qrImage = pw.MemoryImage(await qrFile.readAsBytes());
      }

      // إضافة صفحة مستقلة بحجم A4 لكل طالب في الحلقة التكرارية
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
                  main pw.MainAxisAlignment.spaceBetween,
                  children: [
                    // ====== أولاً: أعلى يسار الصفحة (اسم الطالب ورقم القيد متجاورين) ======
                    pw.Row(
                      main pw.MainAxisAlignment.start,
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

                    // مساحة فارغة لمحتوى أسئلة الامتحان
                    pw.Spacer(),

                    // ====== ثانياً: أسفل الصفحة أقصى اليسار بالترتيب المطلوب ======
                    pw.Row(
                      main pw.MainAxisAlignment.start,
                      cross pw.CrossAxisAlignment.end,
                      children: [
                        pw.Row(
                          cross pw.CrossAxisAlignment.end,
                          children: [
                            // 1. [رقم المادة] - مربع صغير يحتوي على الترتيب الرقمي للمادة
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

                            // 2. [رمز الاستجابة السريعة] - الـ QR الخاص بالطالب
                            pw.Container(
                              width: 60,
                              height: 60,
                              border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                              child: qrImage != null
                                  ? pw.Image(qrImage, fit: pw.BoxFit.cover)
                                  : pw.Center(child: pw.Text("لا يوجد\nQR", style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center)),
                            ),
                            pw.SizedBox(width: 10),

                            // 3. [مربع أزرق فاتح جداً وفارغ] - مخصص لرصد الدرجة مستقبلاً من المصحح
                            pw.Container(
                              width: 70,
                              height: 60,
                              border: pw.Border.all(color: PdfColors.blueAccent, width: 1.5),
                              color: const PdfColor.fromInt(0xFFEBF3F9), // اللون الأزرق الفاتح جداً المطلبو
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

    // حفظ ملف الـ PDF النهائي في المسار المحدد
    final String finalFileName = "$outputPath/امتحانات_$selectedClass.pdf";
    final file = File(finalFileName);
    await file.writeAsBytes(await pdf.save());

    return finalFileName;
  }
}
