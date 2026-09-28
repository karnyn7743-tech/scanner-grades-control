import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';

class PdfGeneratorService {
  
  static Future<String> _getPublicFolderPath() async {
    Directory? externalDir = await getExternalStorageDirectory();
    String newPath = "";
    List<String> paths = externalDir!.path.split("/");
    for (int x = 1; x < paths.length; x++) {
      String folder = paths[x];
      if (folder != "Android") {
        newPath += "/$folder";
      } else {
        break;
      }
    }

    Directory targetDir = Directory("$newPath/Download/درجات الطلاب");
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }
    return targetDir.path;
  }

  static Future<String> generatePapersInIsolate({
    required String excelPath,       
    required String qrFolderPath,    
    required String selectedClass,
    required String selectedSubject, 
    required ByteData fontData,
  }) async {
    
    final String folderPath = await _getPublicFolderPath();

    final Map<String, dynamic> result = await compute(_heavyPdfGenerationTask, {
      'excelPath': excelPath,
      'qrFolderPath': qrFolderPath,
      'selectedClass': selectedClass,
      'selectedSubject': selectedSubject,
    });

    if (result['success'] == false) {
      throw Exception(result['error'] ?? "حدث خطأ غير معروف أثناء التوليد");
    }

    final List<Map<String, dynamic>> studentsList = List<Map<String, dynamic>>.from(result['studentsList']);
    final String subjectNameString = result['subjectNameString'];

    if (studentsList.isEmpty) {
      throw Exception("لا يوجد طلاب مسجلين في هذا الصف المختار!");
    }

    final pdf = pw.Document();
    final ttfFont = pw.Font.ttf(fontData);

    for (var student in studentsList) {
      pw.MemoryImage? qrImageProvider;
      if (student['qrImageBytes'] != null) {
        qrImageProvider = pw.MemoryImage(student['qrImageBytes'] as Uint8List);
      }

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.only(
            top: 1 * PdfPageFormat.mm,
            bottom: 2 * PdfPageFormat.mm,
            left: 35,
            right: 35,
          ),
          theme: pw.ThemeData.withFont(base: ttfFont),
          build: (pw.Context context) {
            return pw.Directionality(
              textDirection: pw.TextDirection.rtl, 
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  // ---- الهيدر العلوي: نصوص حرة بدون أي حاويات أو إطارات مخفية ----
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 1 * PdfPageFormat.mm),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          "اسم الطالب: ${student['studentName']}", 
                          style: pw.TextStyle(font: ttfFont, fontSize: 11, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(
                          "رقم الجلوس: ${student['studentId']}", 
                          style: pw.TextStyle(font: ttfFont, fontSize: 11, fontWeight: pw.FontWeight.bold),
                        ),
                      ],
                    ),
                  ),

                  pw.Spacer(), 

                  // ---- الفوتر السفلي: مساحات حرة ومفتوحة بدون حدود مربعات ----
                  pw.Directionality(
                    textDirection: pw.TextDirection.ltr,
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.start,
                      children: [
                        // 1. مساحة رصد الدرجة (أبيض ناصع بدون أي خطوط حدودية)
                        pw.SizedBox(
                          width: 45,
                          height: 45,
                        ),

                        pw.SizedBox(width: 15),

                        // 2. رمز الاستجابة السريعة QR في المنتصف (بدون أي إطار)
                        pw.SizedBox(
                          width: 45,
                          height: 45,
                          child: qrImageProvider != null
                              ? pw.Image(qrImageProvider, fit: pw.BoxFit.fill)
                              : pw.BarcodeWidget( 
                                  barcode: pw.Barcode.qrCode(),
                                  data: student['qrData']!,
                                  drawText: false,
                                ),
                        ),

                        pw.SizedBox(width: 15),

                        // 3. كود المادة (مطبوع مباشرة على بياض الورقة بدون أي إطار)
                        pw.SizedBox(
                          width: 45,
                          height: 45,
                          child: pw.Center(
                            child: pw.Text(
                              selectedSubject,
                              style: pw.TextStyle(
                                font: ttfFont, 
                                fontSize: 18, 
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
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

    final String cleanSubject = subjectNameString.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final String finalFilePath = "$folderPath/امتحانات_${selectedClass}_$cleanSubject.pdf";
    
    final file = File(finalFilePath);
    await file.writeAsBytes(await pdf.save(), flush: true);

    return finalFilePath;
  }

  static Map<String, dynamic> _heavyPdfGenerationTask(Map<String, dynamic> params) {
    try {
      final String excelPath = params['excelPath'];
      final String qrFolderPath = params['qrFolderPath'];
      final String selectedClass = params['selectedClass'];
      final String selectedSubject = params['selectedSubject'];

      var bytes = File(excelPath).readAsBytesSync();
      var excel = Excel.decodeBytes(bytes);
      String sheetName = excel.tables.keys.first;
      var sheet = excel.tables[sheetName]!;

      List<Map<String, dynamic>> studentsList = [];
      String subjectNameString = "مادة_$selectedSubject";

      int targetSubjectColumn = 4 + (int.parse(selectedSubject) - 1);

      if (sheet.maxRows > 0 && targetSubjectColumn < sheet.maxColumns) {
        var headerValue = sheet.rows.first[targetSubjectColumn]?.value;
        if (headerValue != null && headerValue.toString().trim().isNotEmpty) {
          subjectNameString = headerValue.toString().trim();
        }
      }

      int rowsCount = sheet.rows.length;
      for (int i = 1; i < rowsCount; i++) {
        var row = sheet.rows[i];
        
        if (row == null || row.isEmpty) continue;

        String seatNumber = (row.length > 0 && row[0]?.value != null) ? row[0]!.value.toString().trim() : ""; 
        String studentName = (row.length > 1 && row[1]?.value != null) ? row[1]!.value.toString().trim() : ""; 
        String className = (row.length > 2 && row[2]?.value != null) ? row[2]!.value.toString().trim() : ""; 
        String secretNumber = (row.length > 3 && row[3]?.value != null) ? row[3]!.value.toString().trim() : "";

        if (seatNumber.isEmpty && studentName.isEmpty && className.isEmpty) {
          break; 
        }

        if (className != selectedClass || seatNumber.isEmpty) continue;

        Uint8List? qrImageBytes;
        File qrFile = File("$qrFolderPath/$seatNumber.png");
        if (!qrFile.existsSync()) {
          qrFile = File("$qrFolderPath/$seatNumber.jpg");
        }

        if (qrFile.existsSync()) {
          qrImageBytes = qrFile.readAsBytesSync();
        }

        studentsList.add({
          'studentId': seatNumber,
          'studentName': studentName,
          'qrData': secretNumber,
          'qrImageBytes': qrImageBytes, 
        });
      }

      return {
        'success': true,
        'studentsList': studentsList,
        'subjectNameString': subjectNameString,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
}
