import 'package:excel/excel.dart';

class ExcelService {
  final String path;
  late Excel _excel;
  late Sheet _sheet;

  ExcelService(this.path) {
    _loadExcel();
  }

  void _loadExcel() {
    var bytes = File(path).readAsBytesSync();
    _excel = Excel.decodeBytes(bytes);
    _sheet = _excel.tables.keys.first;
    _excel.tables[_sheet]!;
  }

  int? findStudentBySecretCode(String secretCode) {
    // البحث في العمود D (الرقم السري)
    for (int row = 1; row < _sheet.maxRows; row++) {
      // نبدأ من الصف 1 لأن الصف 0 هو العناوين
      final cell = _sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row),
      );
      if (cell.value == secretCode) {
        return row;
      }
    }
    return null;
  }

  Future<void> updateGrade(
    int studentRow,
    String subjectName,
    String grade,
  ) async {
    // العثور على عمود المادة
    int subjectColumn = -1;
    for (int col = 4; col < _sheet.maxColumns; col++) {
      // نبدأ من العمود E (index 4)
      final cell = _sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0),
      );
      if (cell.value == subjectName) {
        subjectColumn = col;
        break;
      }
    }

    if (subjectColumn != -1) {
      // تحديث الخلية
      _sheet
              .cell(
                CellIndex.indexByColumnRow(
                  columnIndex: subjectColumn,
                  rowIndex: studentRow,
                ),
              )
              .value =
          grade;

      // حفظ الملف
      final fileBytes = _excel.encode();
      if (fileBytes != null) {
        await File(path).writeAsBytes(fileBytes);
      }
    }
  }

  List<String> getSubjects() {
    List<String> subjects = [];
    for (int col = 4; col < _sheet.maxColumns; col++) {
      final cell = _sheet.cell(
        Cellindex.indexByColumnRow(columnIndex: col, rowIndex: 0),
      );
      if (cell.value != null) {
        subjects.add(cell.value.toString());
      }
    }
    return subjects;
  }
}
