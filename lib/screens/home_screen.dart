import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import 'scanner_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _excelPath;
  String? _selectedSubject;
  List<String> _subjects = [];

  Future<void> _pickExcelFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
    );

    if (result != null) {
      setState(() {
        _excelPath = result.files.single.path;
      });

      // قراءة أسماء المواد من الملف
      await _loadSubjects();
    }
  }

  Future<void> _loadSubjects() async {
    if (_excelPath == null) return;

    try {
      final bytes = await File(_excelPath!).readAsBytes();
      final excel = Excel.decodeBytes(bytes);
      final sheet = excel.tables.values.first;

      final subjects = <String>[];
      for (int col = 4; col < sheet.maxColumns; col++) {
        final cell = sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
        if (cell.value != null && cell.value.toString().isNotEmpty) {
          subjects.add(cell.value.toString());
        }
      }

      setState(() {
        _subjects = subjects;
      });
    } catch (e) {
      print('Error loading subjects: $e');
    }
  }

  void _startScanning() {
    if (_excelPath == null || _selectedSubject == null) {
      _showWarning('⚠️ يرجى اختيار ملف Excel والمادة أولاً');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScannerScreen(
          selectedSubject: _selectedSubject!,
          excelPath: _excelPath!,
        ),
      ),
    );
  }

  void _showWarning(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.orange),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('نظام إدخال الدرجات بواسطة qr_code'),
        centerTitle: true,
      ),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      '📂 ملف الدرجات',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: _pickExcelFile,
                      icon: Icon(Icons.folder_open),
                      label: Text('اختيار ملف Excel'),
                      style: ElevatedButton.styleFrom(
                          minimumSize: Size(double.infinity, 50)),
                    ),
                    if (_excelPath != null)
                      Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: Text('✅ ${_excelPath!.split('/').last}',
                            style: TextStyle(color: Colors.green)),
                      ),
                  ],
                ),
              ),
            ),
            if (_subjects.isNotEmpty)
              Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        '📚 اختيار المادة',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: _selectedSubject,
                        items: _subjects.map((subject) {
                          return DropdownMenuItem(
                              value: subject, child: Text(subject));
                        }).toList(),
                        onChanged: (value) =>
                            setState(() => _selectedSubject = value),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'اختر المادة',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Spacer(),
            ElevatedButton.icon(
              onPressed: _startScanning,
              icon: Icon(Icons.camera_alt, size: 30),
              label: Text('بدء المسح', style: TextStyle(fontSize: 20)),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 60),
                backgroundColor: Colors.green,
              ),
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
