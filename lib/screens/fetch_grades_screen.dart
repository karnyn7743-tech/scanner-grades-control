
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:xml/xml.dart';

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

  final numeric = num.tryParse(text);

  if (numeric != null && numeric == numeric.roundToDouble()) {
    return numeric.toInt().toString();
  }

  return text;
}

// ═══════════════════════════════════════════════════════════
// أدوات التعامل مع بنية XLSX الداخلية
// ═══════════════════════════════════════════════════════════

const String _relationshipNamespace =
    'http://schemas.openxmlformats.org/officeDocument/2006/relationships';

String _normalizeZipPath(String path) {
  final parts = <String>[];

  for (final part in path.replaceAll('\\', '/').split('/')) {
    if (part.isEmpty || part == '.') continue;

    if (part == '..') {
      if (parts.isNotEmpty) parts.removeLast();
    } else {
      parts.add(part);
    }
  }

  return parts.join('/');
}

String _resolveWorksheetPath(String target) {
  if (target.startsWith('/')) {
    return _normalizeZipPath(target);
  }

  return _normalizeZipPath('xl/$target');
}

XmlDocument _readXml(Archive archive, String path) {
  final file = archive.findFile(path);

  if (file == null) {
    throw Exception('تعذر العثور على مكون Excel الداخلي: $path');
  }

  final content = file.content;

  if (content is! List<int>) {
    throw Exception('تعذر قراءة مكون Excel الداخلي: $path');
  }

  return XmlDocument.parse(utf8.decode(content));
}

// ═══════════════════════════════════════════════════════════
// استبدال ملف XML داخل الأرشيف
// ═══════════════════════════════════════════════════════════

void _replaceXml(Archive archive, String path, XmlDocument document) {
  final bytes = utf8.encode(
    document.toXmlString(
      pretty: false,
      preserveWhitespace: (node) => true,
    ),
  );

  // قائمة archive.files غير قابلة للتعديل.
  // addFile يستبدل الملف الموجود تلقائياً عند تطابق المسار.
  // لذلك لا نستخدم removeWhere أو أي عملية حذف من القائمة.
  archive.addFile(
    ArchiveFile(path, bytes.length, bytes),
  );
}

XmlElement? _firstElement(XmlNode parent, String localName) {
  for (final child in parent.children) {
    if (child is XmlElement && child.name.local == localName) {
      return child;
    }
  }

  return null;
}

List<XmlElement> _elements(XmlNode parent, String localName) {
  return parent.descendants
      .whereType<XmlElement>()
      .where((element) => element.name.local == localName)
      .toList();
}

String? _attribute(XmlElement element, String name) {
  for (final attribute in element.attributes) {
    if (attribute.name.local == name) {
      return attribute.value;
    }
  }

  return null;
}

String? _relationshipId(XmlElement element) {
  for (final attribute in element.attributes) {
    if (attribute.name.local == 'id' &&
        attribute.name.namespaceUri == _relationshipNamespace) {
      return attribute.value;
    }
  }

  // توافق مع بعض الملفات التي لا تحتفظ ببادئة namespace المتوقعة.
  for (final attribute in element.attributes) {
    if (attribute.name.local == 'id') {
      return attribute.value;
    }
  }

  return null;
}

String _getWorksheetPath(Archive archive, String sheetName) {
  final workbook = _readXml(archive, 'xl/workbook.xml');
  final relationships = _readXml(archive, 'xl/_rels/workbook.xml.rels');

  final sheets = _elements(workbook, 'sheet');

  XmlElement? selectedSheet;

  for (final sheet in sheets) {
    if (_attribute(sheet, 'name') == sheetName) {
      selectedSheet = sheet;
      break;
    }
  }

  if (selectedSheet == null) {
    throw Exception('لم يتم العثور على ورقة العمل ($sheetName).');
  }

  final relationId = _relationshipId(selectedSheet);

  if (relationId == null) {
    throw Exception('تعذر تحديد مسار ورقة العمل ($sheetName).');
  }

  final relations = _elements(relationships, 'Relationship');

  for (final relation in relations) {
    if (_attribute(relation, 'Id') == relationId) {
      final target = _attribute(relation, 'Target');

      if (target == null) break;

      return _resolveWorksheetPath(target);
    }
  }

  throw Exception('تعذر ربط ورقة العمل ($sheetName) بملفها الداخلي.');
}

// ═══════════════════════════════════════════════════════════
// قراءة النصوص المشتركة في XLSX
// ═══════════════════════════════════════════════════════════

List<String> _readSharedStrings(Archive archive) {
  final file = archive.findFile('xl/sharedStrings.xml');

  if (file == null) return [];

  final content = file.content;

  if (content is! List<int>) return [];

  final document = XmlDocument.parse(utf8.decode(content));
  final result = <String>[];

  for (final item in _elements(document, 'si')) {
    final buffer = StringBuffer();

    for (final textElement in _elements(item, 't')) {
      buffer.write(textElement.innerText);
    }

    result.add(buffer.toString());
  }

  return result;
}

// ═══════════════════════════════════════════════════════════
// تحويل مرجع الخلية مثل A1 أو AB25 إلى رقم العمود والصف
// ═══════════════════════════════════════════════════════════

int _columnFromReference(String reference) {
  final match = RegExp(r'^([A-Z]+)').firstMatch(reference.toUpperCase());

  if (match == null) return -1;

  int result = 0;

  for (final code in match.group(1)!.codeUnits) {
    result = result * 26 + code - 64;
  }

  return result - 1;
}

String _columnLetters(int column) {
  int number = column + 1;
  String result = '';

  while (number > 0) {
    final remainder = (number - 1) % 26;
    result = String.fromCharCode(65 + remainder) + result;
    number = (number - 1) ~/ 26;
  }

  return result;
}

String _cellReference(int column, int row) {
  return '${_columnLetters(column)}${row + 1}';
}

// ═══════════════════════════════════════════════════════════
// قراءة قيمة الخلية، بما في ذلك نتيجة المعادلة المحفوظة
// ═══════════════════════════════════════════════════════════

dynamic _readCellValue(
  XmlElement? cell,
  List<String> sharedStrings,
) {
  if (cell == null) return null;

  final type = _attribute(cell, 't');

  if (type == 'inlineStr') {
    final inline = _firstElement(cell, 'is');

    if (inline == null) return null;

    final buffer = StringBuffer();

    for (final textElement in _elements(inline, 't')) {
      buffer.write(textElement.innerText);
    }

    return buffer.toString();
  }

  final valueElement = _firstElement(cell, 'v');

  // إذا كانت الخلية تحتوي على معادلة، فإن v يمثل آخر نتيجة
  // محفوظة بواسطة Excel، وليس نص المعادلة.
  if (valueElement == null) return null;

  final raw = valueElement.innerText.trim();

  if (raw.isEmpty) return null;

  if (type == 's') {
    final index = int.tryParse(raw);

    if (index == null ||
        index < 0 ||
        index >= sharedStrings.length) {
      return null;
    }

    return sharedStrings[index];
  }

  if (type == 'b') {
    return raw == '1';
  }

  if (type == 'str') {
    return raw;
  }

  if (type == 'e') {
    // لا ننقل أخطاء المعادلات إلى ملف الأتمتة.
    return null;
  }

  final number = num.tryParse(raw);

  return number ?? raw;
}

// ═══════════════════════════════════════════════════════════
// تجهيز صفوف وخلايا ورقة العمل
// ═══════════════════════════════════════════════════════════

XmlElement _getSheetData(XmlDocument document) {
  final sheetData = _elements(document, 'sheetData').firstOrNull;

  if (sheetData == null) {
    throw Exception('بنية ورقة العمل غير مكتملة: sheetData.');
  }

  return sheetData;
}

Map<int, XmlElement> _getRows(XmlElement sheetData) {
  final rows = <int, XmlElement>{};

  for (final row in sheetData.children.whereType<XmlElement>()) {
    if (row.name.local != 'row') continue;

    final rowNumber = int.tryParse(_attribute(row, 'r') ?? '');

    if (rowNumber != null && rowNumber > 0) {
      rows[rowNumber - 1] = row;
    }
  }

  return rows;
}

Map<String, XmlElement> _getCells(XmlElement row) {
  final cells = <String, XmlElement>{};

  for (final cell in row.children.whereType<XmlElement>()) {
    if (cell.name.local != 'c') continue;

    final reference = _attribute(cell, 'r');

    if (reference != null) {
      cells[reference.toUpperCase()] = cell;
    }
  }

  return cells;
}

XmlElement? _findCell(
  Map<int, XmlElement> rows,
  int column,
  int rowIndex,
) {
  final row = rows[rowIndex];

  if (row == null) return null;

  final cells = _getCells(row);

  return cells[_cellReference(column, rowIndex).toUpperCase()];
}

dynamic _getValueAt(
  Map<int, XmlElement> rows,
  int column,
  int rowIndex,
  List<String> sharedStrings,
) {
  return _readCellValue(
    _findCell(rows, column, rowIndex),
    sharedStrings,
  );
}

// ═══════════════════════════════════════════════════════════
// كتابة قيمة ثابتة في خلية دون المساس بتنسيقها
// ═══════════════════════════════════════════════════════════

XmlElement _getOrCreateCell(
  XmlElement sheetData,
  Map<int, XmlElement> rows,
  int column,
  int rowIndex,
) {
  final reference = _cellReference(column, rowIndex);

  XmlElement? row = rows[rowIndex];

  if (row == null) {
    row = XmlElement(
      XmlName('row'),
      [
        XmlAttribute(XmlName('r'), (rowIndex + 1).toString()),
      ],
    );

    sheetData.children.add(row);
    rows[rowIndex] = row;
  }

  final cells = _getCells(row);
  final existing = cells[reference.toUpperCase()];

  if (existing != null) return existing;

  final newCell = XmlElement(
    XmlName('c'),
    [
      XmlAttribute(XmlName('r'), reference),
    ],
  );

  row.children.add(newCell);

  return newCell;
}

void _writeConstantValue(
  XmlElement sheetData,
  Map<int, XmlElement> rows,
  int column,
  int rowIndex,
  dynamic value,
) {
  final cell = _getOrCreateCell(
    sheetData,
    rows,
    column,
    rowIndex,
  );

  // حذف محتويات الخلية السابقة فقط، مع الإبقاء على خصائصها
  // مثل style (s) والمرجع (r).
  final oldChildren = cell.children.toList();

  for (final child in oldChildren) {
    cell.children.remove(child);
  }

  final oldType = _attribute(cell, 't');

  if (oldType != null) {
    cell.removeAttribute('t');
  }

  if (value is bool) {
    cell.setAttribute('t', 'b');

    cell.children.add(
      XmlElement(
        XmlName('v'),
        [],
        [XmlText(value ? '1' : '0')],
      ),
    );

    return;
  }

  if (value is num) {
    // الرقم يكتب كقيمة رقمية ثابتة وليس كمعادلة.
    cell.children.add(
      XmlElement(
        XmlName('v'),
        [],
        [XmlText(value.toString())],
      ),
    );

    return;
  }

  // النصوص تكتب بصيغة inlineStr لتجنب تعديل sharedStrings.xml.
  cell.setAttribute('t', 'inlineStr');

  final inline = XmlElement(XmlName('is'));

  inline.children.add(
    XmlElement(
      XmlName('t'),
      [
        XmlAttribute(
          XmlName('space', 'http://www.w3.org/XML/1998/namespace'),
          'preserve',
        ),
      ],
      [XmlText(value.toString())],
    ),
  );

  cell.children.add(inline);
}

// ═══════════════════════════════════════════════════════════
// جلب الدرجات وتحديث ملف الأتمتة مباشرة
// ═══════════════════════════════════════════════════════════

Map<String, dynamic> _fetchGradesIsolate(Map<String, dynamic> args) {
  final String targetPath = args['targetPath'];
  final String sourcePath = args['sourcePath'];
  final String subjectName = args['subjectName'].toString().trim();
  final String mahsalaType = args['mahsalaType'].toString().trim();

  try {
    final targetFile = File(targetPath);
    final sourceFile = File(sourcePath);

    if (!targetFile.existsSync() || !sourceFile.existsSync()) {
      return {
        'success': false,
        'message': 'تعذر العثور على أحد الملفين في مسار التخزين.',
      };
    }

    if (targetPath.toLowerCase().endsWith('.xlsx') == false ||
        sourcePath.toLowerCase().endsWith('.xlsx') == false) {
      return {
        'success': false,
        'message': 'يجب أن يكون الملفان بصيغة XLSX.',
      };
    }

    // قراءة ملفي XLSX كأرشيف ZIP.
    final targetArchive = ZipDecoder().decodeBytes(
      targetFile.readAsBytesSync(),
    );

    final sourceArchive = ZipDecoder().decodeBytes(
      sourceFile.readAsBytesSync(),
    );

    final targetSheetPath = _getWorksheetPath(
      targetArchive,
      'statment',
    );

    final sourceSheetPath = _getWorksheetPath(
      sourceArchive,
      subjectName,
    );

    final targetDocument = _readXml(
      targetArchive,
      targetSheetPath,
    );

    final sourceDocument = _readXml(
      sourceArchive,
      sourceSheetPath,
    );

    final targetSharedStrings = _readSharedStrings(targetArchive);
    final sourceSharedStrings = _readSharedStrings(sourceArchive);

    final targetSheetData = _getSheetData(targetDocument);
    final sourceSheetData = _getSheetData(sourceDocument);

    final targetRows = _getRows(targetSheetData);
    final sourceRows = _getRows(sourceSheetData);

    // إيجاد آخر صف فعلي في كل ورقة.
    final targetMaxRow = targetRows.keys.isEmpty
        ? 0
        : targetRows.keys.reduce((a, b) => a > b ? a : b);

    final sourceMaxRow = sourceRows.keys.isEmpty
        ? 0
        : sourceRows.keys.reduce((a, b) => a > b ? a : b);

    // ملف الأتمتة: أسماء المواد في الصف الثالث (index 2)،
    // بدءاً من العمود E (index 4).
    int targetBaseCol = -1;

    for (int c = 4; c < 500; c++) {
      final value = _getValueAt(
        targetRows,
        c,
        2,
        targetSharedStrings,
      );

      if (value != null && value.toString().trim() == subjectName) {
        targetBaseCol = c;
        break;
      }
    }

    if (targetBaseCol == -1) {
      return {
        'success': false,
        'message':
            'لم يتم العثور على المادة ($subjectName) في الصف الثالث من ورقة statment.',
      };
    }

    // م١ في أول عمود من مجموعة المادة، وم٢ في العمود الثالث.
    final int targetGradeCol = mahsalaType == 'م١'
        ? targetBaseCol
        : targetBaseCol + 2;

    // التحقق من عنوان العمود المستهدف في الصف الخامس.
    final targetSubHeader = _getValueAt(
      targetRows,
      targetGradeCol,
      4,
      targetSharedStrings,
    );

    if (_normalizeHeader(targetSubHeader) !=
        _normalizeHeader(mahsalaType)) {
      return {
        'success': false,
        'message':
            'ترتيب أعمدة المادة في ملف الأتمتة لا يطابق المتوقع: لم يتم العثور على $mahsalaType في موضع اللصق.',
      };
    }

    // البحث عن م١ أو م٢ في الصف الثاني من ورقة المصدر.
    final String wantedHeader = _normalizeHeader(mahsalaType);

    int sourceGradeCol = -1;

    for (int c = 4; c < 500; c++) {
      final value = _getValueAt(
        sourceRows,
        c,
        1,
        sourceSharedStrings,
      );

      if (_normalizeHeader(value) == wantedHeader) {
        sourceGradeCol = c;
        break;
      }
    }

    if (sourceGradeCol == -1) {
      return {
        'success': false,
        'message':
            'لم يتم العثور على عنوان $mahsalaType في الصف الثاني بدءاً من العمود E بورقة ($subjectName).',
      };
    }

    // إنشاء قاموس رقم القيد ← القيمة المحسوبة للدرجة.
    // الصف الرابع هو بداية البيانات (index 3).
    final Map<String, dynamic> gradesMap = {};

    for (int r = 3; r < sourceMaxRow; r++) {
      final seatValue = _getValueAt(
        sourceRows,
        0,
        r,
        sourceSharedStrings,
      );

      final seat = _normalizeSeat(seatValue);

      if (seat.isEmpty) continue;

      final gradeCell = _findCell(
        sourceRows,
        sourceGradeCol,
        r,
      );

      // قراءة <v> المحفوظة حتى إذا كانت الخلية تحتوي على معادلة.
      final grade = _readCellValue(
        gradeCell,
        sourceSharedStrings,
      );

      gradesMap[seat] = grade;
    }

    // المرور على طلاب الأتمتة من الصف السادس (index 5).
    int updatedCount = 0;
    int unmatchedCount = 0;
    int emptyGradeCount = 0;

    for (int r = 5; r < targetMaxRow; r++) {
      final seatValue = _getValueAt(
        targetRows,
        0,
        r,
        targetSharedStrings,
      );

      final seat = _normalizeSeat(seatValue);

      if (seat.isEmpty) continue;

      if (gradesMap.containsKey(seat)) {
        final grade = gradesMap[seat];

        if (grade == null || grade.toString().trim().isEmpty) {
          emptyGradeCount++;
          continue;
        }

        // كتابة الدرجة كقيمة ثابتة فقط، دون نقل المعادلة.
        _writeConstantValue(
          targetSheetData,
          targetRows,
          targetGradeCol,
          r,
          grade,
        );

        updatedCount++;
      } else {
        unmatchedCount++;
      }
    }

    if (updatedCount == 0) {
      return {
        'success': true,
        'count': 0,
        'unmatched': unmatchedCount,
        'sourceGradeColumn': sourceGradeCol + 1,
        'targetGradeColumn': targetGradeCol + 1,
        'emptyGrades': emptyGradeCount,
        'message': 'لم توجد درجات صالحة للتحديث.',
      };
    }

    // استبدال ملف XML الخاص بورقة statment فقط.
    // بقية مكونات المصنف لا يعاد إنشاؤها.
    _replaceXml(
      targetArchive,
      targetSheetPath,
      targetDocument,
    );

    // إعادة ضغط الأرشيف بعد تعديل ورقة العمل المطلوبة.
    final updatedBytes = ZipEncoder().encode(targetArchive);

    if (updatedBytes == null) {
      return {
        'success': false,
        'message': 'تعذر حفظ التغييرات داخل ملف XLSX.',
      };
    }

    // الكتابة مباشرة على مسار ملف الأتمتة المحدد.
    targetFile.writeAsBytesSync(
      updatedBytes,
      flush: true,
    );

    return {
      'success': true,
      'count': updatedCount,
      'unmatched': unmatchedCount,
      'sourceGradeColumn': sourceGradeCol + 1,
      'targetGradeColumn': targetGradeCol + 1,
      'emptyGrades': emptyGradeCount,
    };
  } catch (e) {
    return {
      'success': false,
      'message': 'خطأ تقني أثناء جلب الدرجات: $e',
    };
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

  // ═════════════════════════════════════════════════════════
  // تحديد مجلد درجات الطلاب
  // ═════════════════════════════════════════════════════════

  Future<Directory> _getGradesDirectory() async {
    final externalDir = await getExternalStorageDirectory();

    if (externalDir == null) {
      throw Exception('تعذر الوصول إلى التخزين الداخلي.');
    }

    final paths = externalDir.path.split('/');
    final baseParts = <String>[];

    for (final part in paths) {
      if (part == 'Android') break;
      if (part.isNotEmpty) baseParts.add(part);
    }

    final basePath = '/${baseParts.join('/')}';

    final targetDir = Directory(
      '$basePath/Download/درجات الطلاب',
    );

    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    return targetDir;
  }

  // ═════════════════════════════════════════════════════════
  // وضع الملف في مجلد العمل الدائم
  // ═════════════════════════════════════════════════════════

  Future<String?> _copyToPermanent(
    String sourcePath,
    String originalName,
  ) async {
    final targetDir = await _getGradesDirectory();

    final destination = File(
      '${targetDir.path}/$originalName',
    );

    await destination.writeAsBytes(
      await File(sourcePath).readAsBytes(),
      flush: true,
    );

    return destination.path;
  }

  // ═════════════════════════════════════════════════════════
  // اختيار ملف الأتمتة واستخراج المواد منه
  // ═════════════════════════════════════════════════════════

  Future<void> _pickTargetFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    if (result == null || result.files.single.path == null) return;

    setState(() => _isLoading = true);

    try {
      final cachePath = result.files.single.path!;
      final fileName = result.files.single.name;

      final permanentPath = await _copyToPermanent(
        cachePath,
        fileName,
      );

      if (permanentPath == null) {
        throw Exception('تعذر الوصول إلى مسار التخزين لحفظ الملف.');
      }

      final archive = ZipDecoder().decodeBytes(
        await File(permanentPath).readAsBytes(),
      );

      final sheetPath = _getWorksheetPath(
        archive,
        'statment',
      );

      final document = _readXml(archive, sheetPath);
      final sharedStrings = _readSharedStrings(archive);
      final sheetData = _getSheetData(document);
      final rows = _getRows(sheetData);

      final List<String> tempSubjects = [];

      // جلب أسماء المواد من الصف الثالث.
      for (int c = 4; c < 500; c += 5) {
        final value = _getValueAt(
          rows,
          c,
          2,
          sharedStrings,
        );

        if (value != null &&
            value.toString().trim().isNotEmpty &&
            !value.toString().contains('المجموع')) {
          tempSubjects.add(value.toString().trim());
        }
      }

      if (!mounted) return;

      setState(() {
        _targetPath = permanentPath;
        _targetName = fileName;
        _subjects = tempSubjects;
        _selectedSubject =
            _subjects.isNotEmpty ? _subjects.first : null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم اختيار ملف الأتمتة وجلب المواد بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ═════════════════════════════════════════════════════════
  // اختيار ملف المحرر (المصدر)
  // ═════════════════════════════════════════════════════════

  Future<void> _pickSourceFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    if (result == null || result.files.single.path == null) return;

    setState(() => _isLoading = true);

    try {
      final cachePath = result.files.single.path!;
      final fileName = result.files.single.name;

      final permanentPath = await _copyToPermanent(
        cachePath,
        fileName,
      );

      if (permanentPath == null) {
        throw Exception('تعذر الوصول إلى مسار التخزين لحفظ الملف.');
      }

      if (!mounted) return;

      setState(() {
        _sourcePath = permanentPath;
        _sourceName = fileName;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم اختيار ملف المحرر بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ═════════════════════════════════════════════════════════
  // تنفيذ جلب الدرجات
  // ═════════════════════════════════════════════════════════

  Future<void> _executeFetch() async {
    if (_targetPath == null ||
        _sourcePath == null ||
        _selectedSubject == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'يرجى اختيار كلا الملفين والمادة أولاً',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );

      return;
    }

    if (_targetPath == _sourcePath) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب اختيار ملفين مختلفين للمصدر والهدف.'),
          backgroundColor: Colors.red,
        ),
      );

      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await compute(
        _fetchGradesIsolate,
        {
          'targetPath': _targetPath,
          'sourcePath': _sourcePath,
          'subjectName': _selectedSubject,
          'mahsalaType': _selectedMahsala,
        },
      );

      if (!mounted) return;

      if (result['success'] == true) {
        final count = result['count'] ?? 0;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم لصق ($count) درجة كقيم ثابتة. '
              'أرقام قيد بلا تطابق: (${result['unmatched']})، '
              'ودرجات فارغة: (${result['emptyGrades']}).',
            ),
            backgroundColor: Colors.green.shade800,
            duration: const Duration(seconds: 5),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ ${result['message']}'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ أثناء المعالجة: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ═════════════════════════════════════════════════════════
  // بناء الشاشة
  // ═════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9),
      appBar: AppBar(
        title: const Text(
          'جلب درجات المحصلات',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.white,
          ),
        ),
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

            // 3. اختيار المادة
            const Text(
              '3. المادة (ورقة العمل):',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),

            const SizedBox(height: 8),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade400),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedSubject,
                  isExpanded: true,
                  hint: Text(
                    _targetPath == null
                        ? 'يرجى اختيار ملف الأتمتة أولاً'
                        : 'اختر المادة',
                  ),
                  items: _subjects
                      .map(
                        (subject) => DropdownMenuItem(
                          value: subject,
                          child: Text(
                            subject,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _targetPath == null
                      ? null
                      : (value) {
                          setState(() => _selectedSubject = value);
                        },
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 4. اختيار المحصلة
            const Text(
              '4. المحصلة المطلوب جلبها:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text(
                      'محصلة م١',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    value: 'م١',
                    groupValue: _selectedMahsala,
                    activeColor: const Color(0xFF1B5E20),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedMahsala = value);
                      }
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text(
                      'محصلة م٢',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    value: 'م٢',
                    groupValue: _selectedMahsala,
                    activeColor: const Color(0xFF1B5E20),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedMahsala = value);
                      }
                    },
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.download_done,
                      color: Colors.white,
                    ),
              label: Text(
                _isLoading
                    ? 'جاري المعالجة...'
                    : 'جلب الدرجات ونسخها الآن',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              onPressed: _isLoading ? null : _executeFetch,
            ),
          ],
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════
  // بطاقة اختيار الملف
  // ═════════════════════════════════════════════════════════

  Widget _buildCard({
    required String title,
    required IconData icon,
    required Color color,
    required String fileName,
    VoidCallback? onPressed,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: color,
            ),
          ),

          const SizedBox(height: 12),

          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: Icon(icon, color: Colors.white),
            label: const Text(
              'اختيار الملف',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: onPressed,
          ),

          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.grey.shade300,
              ),
            ),
            child: Text(
              fileName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
