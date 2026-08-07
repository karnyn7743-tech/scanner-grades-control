import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as px;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ScanQRScreen extends StatefulWidget {
  const ScanQRScreen({super.key});

  @override
  State<ScanQRScreen> createState() => _ScanQRScreenState();
}

class _ScanQRScreenState extends State<ScanQRScreen> {
  String? _excelPath;
  px.Excel? _excelInstance;
  Map<String, String> _studentMap = {}; // secretCode -> studentName

  String _secretCode = '';
  String _studentName = '';

  final MobileScannerController _cameraController = MobileScannerController(
    autoStart: false,
    torchEnabled: false,
    returnImage: false,
  );
  bool _isScanning = false;

  // ===================== تحميل آخر ملف مستخدم =====================
  Future<void> _loadLastExcelFile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? lastFile = prefs.getString('last_excel_file');
      if (lastFile != null && await File(lastFile).exists()) {
        _excelPath = lastFile;
        await _loadExcel();
      }
    } catch (e) {
      print('خطأ في تحميل آخر ملف: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _loadLastExcelFile();
  }

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    await Permission.storage.request();
    await Permission.camera.request();
    if (await Permission.manageExternalStorage.request().isGranted) {
      debugPrint("تم الحصول على صلاحية إدارة الملفات الشاملة");
    }
  }

  // ===================== اختيار ملف Excel =====================
  Future<void> _pickExcelFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'xlsm', 'xlsb'],
      );

      if (result != null && result.files.single.path != null) {
        _excelPath = result.files.single.path!;
        // حفظ المسار في SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_excel_file', _excelPath!);
        await _loadExcel();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ تم تحميل ملف الأكسيل بنجاح')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e')),
      );
    }
  }

  // ===================== قراءة ملف Excel =====================
  Future<void> _loadExcel() async {
    if (_excelPath == null) return;
    final bytes = await File(_excelPath!).readAsBytes();
    _excelInstance = px.Excel.decodeBytes(bytes);
    final sheet = _excelInstance!.tables.values.first;

    _studentMap.clear();

    for (int row = 1; row < sheet.maxRows; row++) {
      final cellB = sheet.cell(px.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value;
      final cellD = sheet.cell(px.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value;

      if (cellB != null && cellD != null) {
        _studentMap[cellD.toString().trim()] = cellB.toString().trim();
      }
    }

    setState(() {});
  }

  // ===================== تشغيل/إيقاف الكاميرا =====================
  void _toggleScanning() async {
    if (_excelPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ يرجى اختيار ملف الأكسيل أولاً')),
      );
      return;
    }

    setState(() {
      _isScanning = !_isScanning;
    });

    if (_isScanning) {
      await _cameraController.start();
    } else {
      await _cameraController.stop();
      setState(() {
        _secretCode = '';
        _studentName = '';
      });
    }
  }

  // ===================== معالجة نتيجة المسح =====================
  void _onQRDetected(BarcodeCapture capture) {
    if (capture.barcodes.isEmpty) return;

    final String? code = capture.barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    // إيقاف الكاميرا بعد المسح
    _cameraController.stop();
    setState(() {
      _isScanning = false;
      _secretCode = code;
      _studentName = _studentMap[code] ?? '⚠️ غير موجود';
    });
  }

  // ===================== واجهة المستخدم =====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('قراءة QR Code للطلاب'),
        backgroundColor: Colors.lightBlue.shade300,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: _isScanning ? null : _pickExcelFile,
              icon: const Icon(Icons.folder_open),
              label: const Text('اختيار ملف الأكسيل'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
            ),
            const SizedBox(height: 12),
            if (_excelPath != null)
              Text('📁 ${_excelPath!.split('/').last}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            // حقل الرقم السري
            TextField(
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'الرقم السري',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.qr_code),
              ),
              controller: TextEditingController(text: _secretCode),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // حقل اسم الطالب
            TextField(
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'اسم الطالب',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              controller: TextEditingController(text: _studentName),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // زر المسح
            ElevatedButton.icon(
              onPressed: _toggleScanning,
              icon: Icon(_isScanning ? Icons.stop : Icons.qr_code_scanner),
              label: Text(_isScanning ? 'إيقاف المسح' : 'مسح QR Code'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isScanning ? Colors.red : Colors.green,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
              ),
            ),
            const SizedBox(height: 16),

            // شاشة الكاميرا
            Container(
              height: 250,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _isScanning ? Colors.greenAccent : Colors.grey, width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: _isScanning
                    ? MobileScanner(
                        controller: _cameraController,
                        onDetect: _onQRDetected,
                      )
                    : const Center(
                        child: Text(
                          'اضغط "مسح QR Code" لتشغيل الكاميرا',
                          style: TextStyle(color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
