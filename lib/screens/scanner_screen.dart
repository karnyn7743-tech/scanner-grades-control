import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:google_ml_kit/google_ml_kit.dart';hide Barcode;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart';
import '../utils/grade_parser.dart';

// تعريف منطقة المسح
class ScanZone {
  final String name;
  final String type; // 'subject_id', 'qr', 'grade'
  Rect rect;

  ScanZone({
    required this.name,
    required this.type,
    required this.rect,
  });
}

class Rect {
  double left;
  double top;
  double width;
  double height;

  Rect({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });
}

class ScannerScreen extends StatefulWidget {
  final String selectedSubject;
  final String excelPath;

  const ScannerScreen({
    Key? key,
    required this.selectedSubject,
    required this.excelPath,
  }) : super(key: key);

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isReady = false;
  bool _isProcessing = false;
  bool _isPaused = false; // للإيقاف المؤقت بعد المسح الناجح

  // المناطق الثابتة (من اليسار إلى اليمين: رقم المادة | QR | الدرجة)
  late List<ScanZone> scanZones;

  // OCR processor
  late TextRecognizer _textRecognizer;

  // قائمة QR الممسوحة (لمنع التكرار)
  Set<String> scannedQRCodes = {};

  // قائمة الملاحظات
  List<Map<String, String>> notes = [];

  // آخر درجة تم تأكيدها
  String? _lastRecognizedGrade;

  // آخر رقم مادة تم قراءته
  String? _lastSubjectId;

  // ملف Excel المحمل
  Excel? _excel;
  Sheet? _sheet;

  // متغيرات لمنع التكرار السريع
  DateTime? _lastProcessTime;
  String? _lastProcessedQR;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initScanZones();
    _initOCR();
    _initCamera();
    _loadExcel();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startCamera();
    } else if (state == AppLifecycleState.paused) {
      _stopCamera();
    }
  }

  void _initScanZones() {
    scanZones = [
      ScanZone(name: '📝 رقم المادة', type: 'subject_id', rect: Rect(left: 0, top: 0, width: 0, height: 0)),
      ScanZone(name: '📱 QR Code', type: 'qr', rect: Rect(left: 0, top: 0, width: 0, height: 0)),
      ScanZone(name: '⭐ الدرجة', type: 'grade', rect: Rect(left: 0, top: 0, width: 0, height: 0)),
    ];
  }

  void _initOCR() async {
    try {
      // استخدام النموذج الافتراضي للغة العربية
      final options = TextRecognizerOptions(
        language: TextRecognitionLanguage.arabic,
      );
      _textRecognizer = GoogleMlKit.vision.textRecognizer(options);
    } catch (e) {
      print('Error initializing OCR: $e');
      // محاولة استخدام النموذج الافتراضي
      _textRecognizer = GoogleMlKit.vision.textRecognizer();
    }
  }

  Future<void> _loadExcel() async {
    try {
      final bytes = await File(widget.excelPath).readAsBytes();
      _excel = Excel.decodeBytes(bytes);
      if (_excel != null && _excel!.tables.isNotEmpty) {
        _sheet = _excel!.tables[_excel!.tables.keys.first];
      }
    } catch (e) {
      print('Error loading Excel: $e');
      _addNote('خطأ', 'فشل في تحميل ملف Excel: $e');
    }
  }

  Future<void> _saveExcel() async {
    if (_excel == null) return;
    try {
      final bytes = _excel!.encode();
      if (bytes != null) {
        await File(widget.excelPath).writeAsBytes(bytes);
      }
    } catch (e) {
      print('Error saving Excel: $e');
      _addNote('خطأ', 'فشل في حفظ ملف Excel: $e');
    }
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        _cameraController = CameraController(
          _cameras![0],
          ResolutionPreset.medium, // استخدام Medium لتحسين الأداء
          enableAudio: false,
          imageFormatGroup: ImageFormatGroup.yuv420,
        );
        await _cameraController!.initialize();
        await _startCamera();

        // تحديث إحداثيات المناطق بعد الحصول على حجم الشاشة
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _updateScanZonesPosition();
        });
      }
    } catch (e) {
      print('Error initializing camera: $e');
      _showErrorDialog('خطأ في الكاميرا', 'يرجى التأكد من أذونات الكاميرا وإعادة تشغيل التطبيق');
    }
  }

  Future<void> _startCamera() async {
    if (_cameraController != null && !_cameraController!.value.isInitialized) {
      await _cameraController!.initialize();
    }
    if (_cameraController != null && !_cameraController!.value.isStreamingImages) {
      await _cameraController!.startImageStream(_processCameraImage);
    }
    setState(() {
      _isReady = true;
      _isPaused = false;
    });
  }

  Future<void> _stopCamera() async {
    if (_cameraController != null && _cameraController!.value.isStreamingImages) {
      await _cameraController!.stopImageStream();
    }
  }

  void _updateScanZonesPosition() {
    final screenSize = MediaQuery.of(context).size;
    final zoneWidth = screenSize.width / 3;
    final zoneHeight = screenSize.height * 0.25; // 25% من ارتفاع الشاشة
    final topPosition = screenSize.height * 0.7; // في أسفل الشاشة

    setState(() {
      scanZones[0].rect = Rect(left: 0, top: topPosition, width: zoneWidth, height: zoneHeight);
      scanZones[1].rect = Rect(left: zoneWidth, top: topPosition, width: zoneWidth, height: zoneHeight);
      scanZones[2].rect = Rect(left: zoneWidth * 2, top: topPosition, width: zoneWidth, height: zoneHeight);
    });
  }

  void _processCameraImage(CameraImage image) async {
    if (_isProcessing || _isPaused || !_isReady) return;

    // منع المعالجة المتكررة بسرعة كبيرة (كل ثانية واحدة على الأقل)
    if (_lastProcessTime != null &&
        DateTime.now().difference(_lastProcessTime!) < Duration(milliseconds: 800)) {
      return;
    }

    _isProcessing = true;
    _lastProcessTime = DateTime.now();

    try {
      await _processFrame(image);
    } catch (e) {
      print('Error processing frame: $e');
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _processFrame(CameraImage image) async {
    // معالجة كل منطقة حسب نوعها
    for (var zone in scanZones) {
      if (zone.type == 'qr') {
        await _processQRZone(image, zone);
      } else {
        await _processTextZone(image, zone);
      }
    }
  }

  Future<void> _processQRZone(CameraImage cameraImage, ScanZone zone) async {
    try {
      // تحويل CameraImage إلى صورة قابلة للقص
      final croppedImage = await _cropImageFromCamera(cameraImage, zone.rect);
      if (croppedImage == null) return;

      // حفظ الصورة المقصوصة مؤقتاً
      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/qr_${DateTime.now().millisecondsSinceEpoch}.png';
      await File(tempPath).writeAsBytes(croppedImage);

      // استخدام mobile_scanner لقراءة QR
      final qrResult = await _scanQRFromFile(tempPath);

      // حذف الملف المؤقت
      await File(tempPath).delete();

      if (qrResult != null && qrResult.isNotEmpty) {
        // منع التكرار السريع لنفس QR
        if (_lastProcessedQR == qrResult) return;
        _lastProcessedQR = qrResult;

        if (scannedQRCodes.contains(qrResult)) {
          // QR مكرر
          _addNote('⚠️ تكرار', 'الطالب بالرقم السري $qrResult تم إدخال درجته مسبقاً');
          _showWarning('QR مكرر', 'تم إدخال درجة هذا الطالب مسبقاً!');
        } else {
          scannedQRCodes.add(qrResult);
          await _findAndUpdateStudent(qrResult);
        }
      }
    } catch (e) {
      print('Error processing QR zone: $e');
    }
  }

  Future<Uint8List?> _cropImageFromCamera(CameraImage cameraImage, Rect rect) async {
    try {
      // تحويل CameraImage (YUV420) إلى RGB
      final rgbImage = await _convertYUV420ToRGB(cameraImage);
      if (rgbImage == null) return null;

      // تحويل إلى صورة قابلة للمعالجة
      img.Image? originalImage = img.decodeImage(rgbImage);
      if (originalImage == null) return null;

      // الحصول على أبعاد الصورة الفعلية
      final screenWidth = MediaQuery.of(context).size.width;
      final screenHeight = MediaQuery.of(context).size.height;

      // حساب موقع القص بناءً على نسبة الشاشة
      final scaleX = originalImage.width / screenWidth;
      final scaleY = originalImage.height / screenHeight;

      final cropX = (rect.left * scaleX).toInt().clamp(0, originalImage.width - 1);
      final cropY = (rect.top * scaleY).toInt().clamp(0, originalImage.height - 1);
      final cropWidth = (rect.width * scaleX).toInt().clamp(1, originalImage.width - cropX);
      final cropHeight = (rect.height * scaleY).toInt().clamp(1, originalImage.height - cropY);

      // قص الصورة
      final croppedImage = img.copyCrop(
        originalImage,
        x: cropX,
        y: cropY,
        width: cropWidth,
        height: cropHeight,
      );

      // تحويل إلى PNG bytes
      return Uint8List.fromList(img.encodePng(croppedImage));
    } catch (e) {
      print('Error cropping image: $e');
      return null;
    }
  }

  Future<Uint8List?> _convertYUV420ToRGB(CameraImage image) async {
    try {
      final int width = image.width;
      final int height = image.height;

      // إنشاء مصفوفة للصورة النهائية RGB
      final Uint8List rgbBytes = Uint8List(width * height * 3);

      // استخراج Y, U, V planes
      final Uint8List yPlane = image.planes[0].bytes;
      final Uint8List uPlane = image.planes[1].bytes;
      final Uint8List vPlane = image.planes.length > 2 ? image.planes[2].bytes : uPlane;

      int uvIndex = 0;
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final int yIndex = y * width + x;
          final int yValue = yPlane[yIndex] & 0xFF;

          final int uvX = x ~/ 2;
          final int uvY = y ~/ 2;
          final int uvOffset = uvY * (width ~/ 2) + uvX;

          final int uValue = uPlane[uvOffset] & 0xFF;
          final int vValue = vPlane[uvOffset] & 0xFF;

          // تحويل YUV إلى RGB
          int r = (yValue + 1.402 * (vValue - 128)).round();
          int g = (yValue - 0.344 * (uValue - 128) - 0.714 * (vValue - 128)).round();
          int b = (yValue + 1.772 * (uValue - 128)).round();

          r = r.clamp(0, 255);
          g = g.clamp(0, 255);
          b = b.clamp(0, 255);

          final int rgbIndex = (y * width + x) * 3;
          rgbBytes[rgbIndex] = r;
          rgbBytes[rgbIndex + 1] = g;
          rgbBytes[rgbIndex + 2] = b;
        }
      }

      return rgbBytes;
    } catch (e) {
      print('Error converting YUV to RGB: $e');
      return null;
    }
  }

  Future<String?> _scanQRFromFile(String filePath) async {
    try {
      final Barcode? result = await MobileScanner.scanFile(File(filePath));
      return result?.rawValue;
    } catch (e) {
      print('QR scan error: $e');
      return null;
    }
  }

  Future<void> _processTextZone(CameraImage cameraImage, ScanZone zone) async {
    try {
      final croppedImage = await _cropImageFromCamera(cameraImage, zone.rect);
      if (croppedImage == null) return;

      // حفظ مؤقت
      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/text_${DateTime.now().millisecondsSinceEpoch}.png';
      await File(tempPath).writeAsBytes(croppedImage);

      // التعرف على النص
      final inputImage = InputImage.fromFilePath(tempPath);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      // حذف الملف المؤقت
      await File(tempPath).delete();

      if (recognizedText.text.isNotEmpty) {
        final cleanedText = recognizedText.text.trim();

        if (zone.type == 'subject_id') {
          final subjectId = GradeParser.extractGrade(cleanedText);
          if (subjectId.isNotEmpty && subjectId != _lastSubjectId) {
            _lastSubjectId = subjectId;
            await _checkSubjectId(subjectId);
          }
        } else if (zone.type == 'grade') {
          final grade = GradeParser.extractGrade(cleanedText);
          if (grade.isNotEmpty && GradeParser.isValidGrade(grade)) {
            // إيقاف المعالجة مؤقتاً لعرض مربع الحوار
            setState(() {
              _isPaused = true;
            });
            _showGradeConfirmation(grade);
          } else if (grade.isNotEmpty) {
            _showWarning('درجة غير صالحة', 'الدرجة المقروءة ($grade) يجب أن تكون بين 0 و 100');
          }
        }
      }
    } catch (e) {
      print('Error processing text zone: $e');
    }
  }

  Future<void> _checkSubjectId(String subjectId) async {
    print('رقم المادة المقروء: $subjectId');
    // هنا يمكنك إضافة منطق للتحقق من تطابق رقم المادة مع المادة المختارة
    // إذا كان لديك map يربط أسماء المواد بأرقامها
  }

  Future<void> _findAndUpdateStudent(String qrCode) async {
    if (_sheet == null) {
      _addNote('خطأ', 'لم يتم تحميل ملف Excel بشكل صحيح');
      return;
    }

    try {
      // البحث عن الطالب في العمود D (الرقم السري)
      int studentRow = -1;
      String studentName = '';

      for (int row = 1; row < _sheet!.maxRows; row++) {
        final cell = _sheet!.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row));
        if (cell.value != null && cell.value.toString() == qrCode) {
          studentRow = row;
          // قراءة اسم الطالب من العمود B
          final nameCell = _sheet!.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row));
          studentName = nameCell.value?.toString() ?? 'غير معروف';
          break;
        }
      }

      if (studentRow != -1) {
        if (_lastRecognizedGrade != null && _lastRecognizedGrade!.isNotEmpty) {
          // العثور على عمود المادة المختارة
          int subjectColumn = -1;
          for (int col = 4; col < _sheet!.maxColumns; col++) {
            final cell = _sheet!.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
            if (cell.value != null && cell.value.toString() == widget.selectedSubject) {
              subjectColumn = col;
              break;
            }
          }

          if (subjectColumn != -1) {
            // تحديث الدرجة
            _sheet!.cell(CellIndex.indexByColumnRow(
                columnIndex: subjectColumn,
                rowIndex: studentRow
            )).value = _lastRecognizedGrade;

            await _saveExcel();

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('✅ تم تحديث درجة الطالب $studentName: $_lastRecognizedGrade'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2),
                ),
              );
            }

            _addNote('✅ نجاح', 'تم تحديث درجة $studentName: $_lastRecognizedGrade');

            // إعادة التعيين للورقة التالية
            _resetForNextSheet();
          } else {
            _addNote('خطأ', 'لم يتم العثور على عمود للمادة: ${widget.selectedSubject}');
          }
        }
      } else {
        _addNote('⚠️ غير موجود', 'لم يتم العثور على طالب بالرقم السري: $qrCode');
        _showWarning('خطأ', 'لم يتم العثور على الطالب بالرقم السري: $qrCode');
      }
    } catch (e) {
      print('Error finding/updating student: $e');
      _addNote('❌ خطأ', 'خطأ في معالجة الرقم السري $qrCode: $e');
    }
  }

  void _resetForNextSheet() {
    _lastRecognizedGrade = null;
    _lastSubjectId = null;
    _lastProcessedQR = null;

    setState(() {
      _isPaused = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('📄 جاهز للورقة التالية... امسح الورقة التالية'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  void _showGradeConfirmation(String recognizedGrade) {
    final TextEditingController controller = TextEditingController(text: recognizedGrade);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.edit, color: Colors.orange),
            SizedBox(width: 10),
            Text('تأكيد الدرجة'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('الدرجة المقروءة من الورقة:'),
            SizedBox(height: 15),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'الدرجة',
                prefixIcon: Icon(Icons.grade),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showWarning('تم الإلغاء', 'يمكنك إعادة مسح الورقة');
              setState(() {
                _isPaused = false;
              });
            },
            child: Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              final finalGrade = controller.text.trim();
              if (GradeParser.isValidGrade(finalGrade)) {
                _lastRecognizedGrade = finalGrade;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('تم حفظ الدرجة: $finalGrade'),
                    backgroundColor: Colors.blue,
                    duration: Duration(seconds: 1),
                  ),
                );
                // استمرار المعالجة
                setState(() {
                  _isPaused = false;
                });
              } else {
                _showWarning('درجة غير صالحة', 'يجب أن تكون الدرجة بين 0 و 100');
              }
            },
            child: Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _addNote(String type, String message) {
    setState(() {
      notes.add({
        'type': type,
        'message': message,
        'time': DateTime.now().toString().substring(11, 19),
      });
    });
  }

  void _showWarning(String title, String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ $title: $message'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('حسنًا'),
          ),
        ],
      ),
    );
  }

  void _showNotesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.note, color: Colors.blue),
            SizedBox(width: 10),
            Text('قائمة الملاحظات (${notes.length})'),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          height: 400,
          child: notes.isEmpty
              ? Center(child: Text('لا توجد ملاحظات'))
              : ListView.builder(
            itemCount: notes.length,
            itemBuilder: (context, index) {
              final note = notes[index];
              return Card(
                child: ListTile(
                  leading: Icon(
                    note['type']?.contains('✅') == true ? Icons.check_circle :
                    note['type']?.contains('⚠️') == true ? Icons.warning :
                    Icons.error,
                    color: note['type']?.contains('✅') == true ? Colors.green :
                    note['type']?.contains('⚠️') == true ? Colors.orange :
                    Colors.red,
                  ),
                  title: Text(note['type'] ?? ''),
                  subtitle: Text(note['message'] ?? ''),
                  trailing: Text(note['time'] ?? '', style: TextStyle(fontSize: 12)),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                notes.clear();
              });
              Navigator.pop(context);
            },
            child: Text('مسح الكل', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('كيفية المسح'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('1. ضع ورقة الاختبار أمام الكاميرا'),
            SizedBox(height: 10),
            Text('2. اجعل المنطقة السفلية (رقم المادة - QR - الدرجة) داخل الإطارات الزرقاء'),
            SizedBox(height: 10),
            Text('3. سيقوم البرنامج تلقائياً بقراءة البيانات'),
            SizedBox(height: 10),
            Text('4. تأكد من الدرجة ثم اضغط حفظ'),
            SizedBox(height: 10),
            Text('5. انتقل للورقة التالية'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('فهمت'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('مسح الدرجات - ${widget.selectedSubject}'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.help_outline),
            onPressed: _showHelpDialog,
            tooltip: 'مساعدة',
          ),
          IconButton(
            icon: Icon(Icons.note),
            onPressed: _showNotesDialog,
            tooltip: 'الملاحظات (${notes.length})',
          ),
        ],
      ),
      body: _isReady && _cameraController != null && _cameraController!.value.isInitialized
          ? Stack(
        children: [
          // معاينة الكاميرا
          CameraPreview(_cameraController!),

          // إطارات المناطق الثلاث
          ...scanZones.map((zone) => Positioned(
            left: zone.rect.left,
            top: zone.rect.top,
            child: Container(
              width: zone.rect.width,
              height: zone.rect.height,
              decoration: BoxDecoration(
                border: Border.all(
                  color: zone.type == 'subject_id' ? Colors.orange :
                  zone.type == 'qr' ? Colors.blue :
                  Colors.green,
                  width: 3,
                ),
                color: (zone.type == 'subject_id' ? Colors.orange :
                zone.type == 'qr' ? Colors.blue :
                Colors.green).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    zone.name,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          )).toList(),

          // شريط الحالة
          Positioned(
            top: 20,
            left: 0,
            right: 0,
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 20),
              padding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'المادة: ${widget.selectedSubject}',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      Text(
                        'تم إدخال: ${scannedQRCodes.length} طالب',
                        style: TextStyle(color: Colors.green, fontSize: 12),
                      ),
                    ],
                  ),
                  if (_isPaused)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Text(
                        'بانتظار التأكيد',
                        style: TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // زر إيقاف مؤقت
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton(
              mini: true,
              onPressed: () {
                setState(() {
                  _isPaused = !_isPaused;
                });
                _showWarning('تم ${_isPaused ? 'إيقاف' : 'استئناف'} المسح',
                    _isPaused ? 'المسح متوقف مؤقتاً' : 'المسح مستمر');
              },
              child: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
              backgroundColor: _isPaused ? Colors.green : Colors.orange,
            ),
          ),

          // زر خروج
          Positioned(
            bottom: 20,
            left: 20,
            child: FloatingActionButton(
              mini: true,
              onPressed: () {
                _stopCamera();
                Navigator.pop(context);
              },
              child: Icon(Icons.close),
              backgroundColor: Colors.red,
            ),
          ),
        ],
      )
          : Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text('جاري تجهيز الكاميرا...'),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopCamera();
    _cameraController?.dispose();
    _textRecognizer.close();
    super.dispose();
  }
}
