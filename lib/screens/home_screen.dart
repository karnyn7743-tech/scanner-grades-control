import 'package:flutter/material.dart';
import 'dart:io';
import 'package:excel/excel.dart'; // تأكد من وجود مكتبة excel في الـ pubspec
import 'package:file_picker/file_picker.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // قائمة المواد أصبحت فارغة في البداية وتنتظر القراءة من ملف الإكسيل
  List<String> subjects = []; 
  String? selectedSubject;
  String? excelFilePath;

  // دالة اختيار ملف الإكسيل وقراءة المواد ديناميكياً من الأعمدة (5 إلى 19)
  Future<void> pickAndLoadExcel() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result != null && result.files.single.path != null) {
        String path = result.files.single.path!;
        var bytes = File(path).readAsBytesSync();
        var excel = Excel.decodeBytes(bytes);

        // قراءة أول ورقة عمل (Sheet) في الملف
        String firstSheet = excel.tables.keys.first;
        var table = excel.tables[firstSheet];

        if (table != null && table.maxRows > 0) {
          // قراءة الصف الأول (العناوين) لمعرفة أسماء المواد
          var firstRow = table.rows.first;
          List<String> extractedSubjects = [];

          // الأعمدة في البرمجة تبدأ من 0:
          // العمود الخامس (E) هو رقم 4 ، والعمود التاسع عشر (S) هو رقم 18
          for (int i = 4; i <= 18; i++) {
            if (i < firstRow.length && firstRow[i] != null) {
              String cellValue = firstRow[i]!.value.toString().trim();
              if (cellValue.isNotEmpty && cellValue != "null") {
                extractedSubjects.add(cellValue);
              }
            }
          }

          // تحديث الواجهة بالقائمة الجديدة التي تم استخراجها من الملف
          setState(() {
            excelFilePath = path;
            subjects = extractedSubjects;
            // اختيار أول مادة تم العثور عليها كخيار افتراضي
            selectedSubject = subjects.isNotEmpty ? subjects.first : null;
          });
        }
      }
    } catch (e) {
      // إظهار تنبيه في حال وجود مشكلة بملف الإكسيل
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("خطأ في قراءة ملف الإكسيل: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('رصد درجات الطلاب'),
          centerTitle: true,
        ),
        body: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // زر اختيار ملف الإكسيل
              ElevatedButton.icon(
                onPressed: pickAndLoadExcel,
                icon: const Icon(Icons.file_upload),
                label: Text(excelFilePath == null ? "اختر ملف إكسيل الكنترول" : "تم اختيار الملف بنجاح"),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(15)),
              ),
              const SizedBox(height: 30),

              // قائمة اختيار المواد (تظهر فقط بعد رفع الملف وقراءته بنجاح)
              if (subjects.isNotEmpty) ...[
                const Text(
                  "اختر المادة المراد رصدها حالياً:",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.color(Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedSubject,
                      isExpanded: true,
                      items: subjects.map((String subject) {
                        return DropdownMenuItem<String>(
                          value: subject,
                          child: Text(subject),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          selectedSubject = newValue;
                        });
                      },
                    ),
                  ),
                ),
              ] else if (excelFilePath != null) ...[
                const Text(
                  "تنبيه: لم يتم العثور على مواد في الأعمدة من E إلى S في هذا الملف.",
                  style: TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
