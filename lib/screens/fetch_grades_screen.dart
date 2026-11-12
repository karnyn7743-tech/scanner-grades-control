import 'dart:io';
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

// ═══════════════════════════════════════════════════════════
// أدوات توحيد القيم قبل المطابقة
// ═══════════════════════════════════════════════════════════
String _normalizeHeader(dynamic value) {
  if (value == null) return '';
  return value.toString()
      .trim()
      .replaceAll(RegExp(r'\s+'), '')
      .replaceAll('١', '1')
      .replaceAll('٢', '2')
      .replaceAll('۳', '3')
      .replaceAll('٣', '3');
}

String _normalizeSeat(dynamic value) {
  if (value == null) return '';
  String text = value.toString().trim().replaceAll(',', '');
  // توحيد رقم القيد إذا قرأه Excel كرقم عشري مثل 123.0
  final numeric = num.tryParse(text);
  if (numeric != null && numeric == numeric.roundToDouble()) {
    return numeric.toInt().toString();
  }
  return text;
}

// ═══════════════════════════════════════════════════════════
// جلب الدرجات في Isolate مع مطابقة رقم القيد (VLOOKUP)
// ═══════════════════════════════════════════════════════════
Map<String, dynamic> _fetchGradesIsolate(Map<String, dynamic> args) {
  final String targetPath = args['targetPath'];
  final String sourcePath = args['sourcePath'];
  final String subjectName = args['subjectName'].toString().trim();
  final String mahsalaType = args['mahsalaType'].toString().trim(); // م١ أو م٢

  try {
    final targetFile = File(targetPath);
    final sourceFile = File(sourcePath);
    if (!targetFile.existsSync() || !sourceFile.existsSync()) {
      return {'success': false, 'message': 'تعذر العثور على أحد الملفين في مسار التخزين.'};
    }

    final targetExcel = Excel.decodeBytes(targetFile.readAsBytesSync());
    final sourceExcel = Excel.decodeBytes(sourceFile.readAsBytesSync());

    // لا نسمح بالكتابة في ورقة بديلة عن statment بالخطأ.
    final targetSheet = targetExcel.tables['statment'];
    if (targetSheet == null) {
      return {'success': false, 'message': 'لم يتم العثور على ورقة العمل statment في ملف الأتمتة.'};
    }

    // ورقة المصدر تحمل اسم المادة نفسها.
    final sourceSheet = sourceExcel.tables[subjectName];
    if (sourceSheet == null) {
      return {'success': false, 'message': 'ورقة المادة ($subjectName) غير موجودة في ملف أعمال السنة.'};
    }

    // ملف الأتمتة: أسماء المواد في الصف الثالث (index 2)، بدءاً من E (index 4).
    int targetBaseCol = -1;
    for (int c = 4; c < targetSheet.maxColumns; c++) {
      final value = targetSheet
          .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 2))
          .value;
      if (value != null && value.toString().trim() == subjectName) {
        targetBaseCol = c;
        break;
      }
    }
    if (targetBaseCol == -1) {
      return {'success': false, 'message': 'لم يتم العثور على المادة ($subjectName) في الصف الثالث من ورقة statment.'};
    }

    // في ملف الأتمتة: م١ في أول عمود من مجموعة المادة، وم٢ في العمود الثالث.
    final int targetGradeCol = mahsalaType == 'م١'
        ? targetBaseCol
        : targetBaseCol + 2;

    // تحقق من عنوان العمود المستهدف في الصف الخامس حتى لا نكتب في عمود خاطئ.
    final targetSubHeader = targetSheet
        .cell(CellIndex.indexByColumnRow(columnIndex: targetGradeCol, rowIndex: 4))
        .value;
    if (_normalizeHeader(targetSubHeader) != _normalizeHeader(mahsalaType)) {
      return {
        'success': false,
        'message': 'ترتيب أعمدة المادة في ملف الأتمتة لا يطابق المتوقع: لم يتم العثور على $mahsalaType في موضع اللصق.'
      };
    }

    // ملف أعمال السنة: البحث عن م١ أو م٢ في الصف الثاني (index 1)،
    // ويبدأ البحث من العمود E (index 4). لا نفترض موضعاً ثابتاً للمحصلة.
    final String wantedHeader = _normalizeHeader(mahsalaType);
    int sourceGradeCol = -1;
    for (int c = 4; c < sourceSheet.maxColumns; c++) {
      final value = sourceSheet
          .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 1))
          .value;
      if (_normalizeHeader(value) == wantedHeader) {
        sourceGradeCol = c;
        break;
      }
    }
    if (sourceGradeCol == -1) {
      return {
        'success': false,
        'message': 'لم يتم العثور على عنوان $mahsalaType في الصف الثاني بدءاً من العمود E بورقة ($subjectName).'
      };
    }

    // إنشاء قاموس رقم القيد ← الدرجة من المصدر. تبدأ البيانات من الصف الرابع (index 3).
    final Map<String, dynamic> gradesMap = {};
    for (int r = 3; r < sourceSheet.maxRows; r++) {
      final seatValue = sourceSheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r))
          .value;
      final seat = _normalizeSeat(seatValue);
      if (seat.isEmpty) continue;

      final grade = sourceSheet
          .cell(CellIndex.indexByColumnRow(columnIndex: sourceGradeCol, rowIndex: r))
          .value;
      // لا نضيف الدرجة الفارغة حتى لا نمسح درجة موجودة في ملف الأتمتة.
      // نحفظ المفتاح حتى نميز بين رقم قيد غير موجود ودرجة فارغة.
      gradesMap[seat] = grade;
    }

    // المرور على طلاب الأتمتة، وتبدأ بياناتهم من الصف السادس (index 5).
    int updatedCount = 0;
    int unmatchedCount = 0;
    int emptyGradeCount = 0;
    for (int r = 5; r < targetSheet.maxRows; r++) {
      final seatValue = targetSheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r))
          .value;
      final seat = _normalizeSeat(seatValue);
      if (seat.isEmpty) continue;

      if (gradesMap.containsKey(seat)) {
        final grade = gradesMap[seat];
        if (grade == null || grade.toString().trim().isEmpty) {
          emptyGradeCount++;
          continue;
        }
        targetSheet
            .cell(CellIndex.indexByColumnRow(columnIndex: targetGradeCol, rowIndex: r))
            .value = grade;
        updatedCount++;
      } else {
        unmatchedCount++;
      }
    }

    final updatedBytes = targetExcel.encode();
    if (updatedBytes == null) {
      return {'success': false, 'message': 'تعذر إنشاء نسخة Excel بعد تحديث الدرجات.'};
    }

    targetFile.writeAsBytesSync(updatedBytes, flush: true);
    return {
      'success': true,
      'count': updatedCount,
      'unmatched': unmatchedCount,
      'sourceGradeColumn': sourceGradeCol + 1,
      'targetGradeColumn': targetGradeCol + 1,
      'emptyGrades': emptyGradeCount,
    };
  } catch (e) {
    return {'success': false, 'message': 'خطأ تقني أثناء جلب الدرجات: $e'};
  }
}

// ═══════════════════════════════════════════════════════════
// واجهة الشاشة
// ═══════════════════════════════════════════════════════════
class FetchGradesScreen extends StatefulWidget {
  const FetchGradesScreen({super.key});

  @override
  State<FetchGradesScreen> createState() => _FetchGradesScreenState();
}

class _FetchGradesScreenState extends State<FetchGradesScreen> {
  String? _targetPath;
  String? _targetName;
  
  String? _sourcePath;
  String? _sourceName;
  
  List<String> _subjects = [];
  String? _selectedSubject;
  String _selectedMahsala = 'م١';
  
  bool _isLoading = false;

  Future<String?> _copyToPermanent(String sourcePath, String originalName) async {
    Directory? externalDir = await getExternalStorageDirectory();
    if (externalDir == null) return null;

    String basePath = "";
    List<String> paths = externalDir.path.split("/");
    for (int x = 1; x < paths.length; x++) {
      if (paths[x] != "Android") {
        basePath += "/${paths[x]}";
      } else {
        break;
      }
    }
    Directory targetDir = Directory("$basePath/Download/درجات الطلاب");
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }
    File destination = File("${targetDir.path}/$originalName");
    // استبدال النسخة السابقة دائماً؛ حتى لا تتم معالجة ملف قديم بالاسم نفسه.
    await destination.writeAsBytes(
      await File(sourcePath).readAsBytes(),
      flush: true,
    );
    return destination.path;
  }

  // 1. اختيار ملف الأتمتة واستخراج المواد منه
  Future<void> _pickTargetFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['xlsx', 'xls']);
    if (result != null && result.files.single.path != null) {
      setState(() => _isLoading = true);
      try {
        final cachePath = result.files.single.path!;
        final fileName = result.files.single.name;
        final permPath = await _copyToPermanent(cachePath, fileName);
        
        if (permPath == null) {
          throw Exception("تعذر الوصول إلى مسار التخزين لحفظ الملف.");
        }

        final bytes = await File(permPath).readAsBytes();
        final excel = Excel.decodeBytes(bytes);
        final sheet = excel.tables['statment'];
        if (sheet == null) {
          throw Exception('لم يتم العثور على ورقة العمل statment في ملف الأتمتة.');
        }

        // جلب أسماء المواد من الصف الثالث بدءاً من العمود E
        List<String> tempSubjects = [];
        for (int c = 4; c < sheet.maxColumns; c += 5) {
          var val = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 2)).value;
          if (val != null && val.toString().trim().isNotEmpty && !val.toString().contains('المجموع')) {
            tempSubjects.add(val.toString().trim());
          }
        }
        
        setState(() {
          _targetPath = permPath;
          _targetName = fileName;
          _subjects = tempSubjects;
          _selectedSubject = _subjects.isNotEmpty ? _subjects.first : null;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم اختيار ملف الأتمتة وجلب المواد بنجاح'), backgroundColor: Colors.green));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  // 2. اختيار ملف المحرر (المصدر)
  Future<void> _pickSourceFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['xlsx', 'xls']);
    if (result != null && result.files.single.path != null) {
      setState(() => _isLoading = true);
      try {
        final cachePath = result.files.single.path!;
        final fileName = result.files.single.name;
        final permPath = await _copyToPermanent(cachePath, fileName);
        
        if (permPath == null) {
          throw Exception("تعذر الوصول إلى مسار التخزين لحفظ الملف.");
        }

        setState(() {
          _sourcePath = permPath;
          _sourceName = fileName;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم اختيار ملف المحرر بنجاح'), backgroundColor: Colors.green));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _executeFetch() async {
    if (_targetPath == null || _sourcePath == null || _selectedSubject == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى اختيار كلا الملفين والمادة أولاً', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await compute(_fetchGradesIsolate, {
        'targetPath': _targetPath,
        'sourcePath': _sourcePath,
        'subjectName': _selectedSubject,
        'mahsalaType': _selectedMahsala,
      });

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ تم لصق (${result['count']}) درجة. أرقام قيد بلا تطابق: (${result['unmatched']})، ودرجات فارغة: (${result['emptyGrades']}).'),
            backgroundColor: Colors.green.shade800,
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ ${result['message']}'), backgroundColor: Colors.red.shade800),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ أثناء المعالجة: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9),
      appBar: AppBar(
        title: const Text('جلب درجات المحصلات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
        backgroundColor: const Color(0xFF1B5E20),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. ملف الأتمتة (الهدف)
            _buildCard(
              title: '1. ملف الأتمتة (الذي ستُكتب فيه الدرجات)',
              icon: Icons.file_copy_outlined,
              color: Colors.blueAccent,
              fileName: _targetName ?? 'لم يتم اختيار ملف',
              onPressed: _isLoading ? null : _pickTargetFile,
            ),
            const SizedBox(height: 16),

            // 2. ملف المحرر (المصدر)
            _buildCard(
              title: '2. ملف المحرر (الذي ستُجلب منه الدرجات)',
              icon: Icons.file_open_outlined,
              color: Colors.orangeAccent,
              fileName: _sourceName ?? 'لم يتم اختيار ملف',
              onPressed: _isLoading ? null : _pickSourceFile,
            ),
            const SizedBox(height: 24),

            // 3. اختيار المادة (يُجلب من ملف الهدف)
            const Text('3. المادة (ورقة العمل):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade400)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedSubject,
                  isExpanded: true,
                  hint: Text(_targetPath == null ? 'يرجى اختيار ملف الأتمتة أولاً' : 'اختر المادة'),
                  items: _subjects.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
                  onChanged: _targetPath == null ? null : (v) => setState(() => _selectedSubject = v),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 4. اختيار المحصلة
            const Text('4. المحصلة المطلوب جلبها:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('محصلة م١', style: TextStyle(fontWeight: FontWeight.bold)),
                    value: 'م١',
                    groupValue: _selectedMahsala,
                    activeColor: const Color(0xFF1B5E20),
                    onChanged: (v) => setState(() => _selectedMahsala = v!),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('محصلة م٢', style: TextStyle(fontWeight: FontWeight.bold)),
                    value: 'م٢',
                    groupValue: _selectedMahsala,
                    activeColor: const Color(0xFF1B5E20),
                    onChanged: (v) => setState(() => _selectedMahsala = v!),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // 5. زر التنفيذ
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B5E20),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: _isLoading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.download_done, color: Colors.white),
              label: Text(_isLoading ? 'جاري المعالجة...' : 'جلب الدرجات ونسخها الآن', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              onPressed: _isLoading ? null : _executeFetch,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({required String title, required IconData icon, required Color color, required String fileName, VoidCallback? onPressed}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.5)), boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: color, padding: const EdgeInsets.symmetric(vertical: 12)),
            icon: Icon(icon, color: Colors.white),
            label: const Text('اختيار الملف', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: onPressed,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
            child: Text(fileName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
