import 'dart:io';
import 'dart:typed_data';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class OCRService {
  late TextRecognizer _textRecognizer;
  bool _isInitialized = false;

  OCRService() {
    _initRecognizer();
  }

  Future<void> _initRecognizer() async {
    try {
      // محاولة استخدام النموذج العربي
      final options = TextRecognizerOptions(
        language: TextRecognitionLanguage.arabic,
      );
      _textRecognizer = GoogleMlKit.vision.textRecognizer(options);
    } catch (e) {
      // استخدام النموذج الافتراضي
      _textRecognizer = GoogleMlKit.vision.textRecognizer();
    }
    _isInitialized = true;
  }

  /// التعرف على النص من ملف صورة
  Future<String?> recognizeTextFromFile(String filePath) async {
    if (!_isInitialized) await _initRecognizer();

    try {
      final inputImage = InputImage.fromFilePath(filePath);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      return recognizedText.text.trim();
    } catch (e) {
      print('OCR from file error: $e');
      return null;
    }
  }

  /// التعرف على النص من Uint8List
  Future<String?> recognizeTextFromBytes(Uint8List imageBytes) async {
    if (!_isInitialized) await _initRecognizer();

    try {
      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/ocr_${DateTime.now().millisecondsSinceEpoch}.png';
      await File(tempPath).writeAsBytes(imageBytes);

      final result = await recognizeTextFromFile(tempPath);

      await File(tempPath).delete();

      return result;
    } catch (e) {
      print('OCR from bytes error: $e');
      return null;
    }
  }

  /// التعرف على النص من img.Image
  Future<String?> recognizeTextFromImage(img.Image image) async {
    final bytes = Uint8List.fromList(img.encodePng(image));
    return await recognizeTextFromBytes(bytes);
  }

  /// التعرف على الأرقام فقط من الصورة (مخصص للدرجات)
  Future<String?> recognizeGradeFromImage(img.Image image) async {
    final text = await recognizeTextFromImage(image);
    if (text == null) return null;

    // استخراج الأرقام من النص
    final regex = RegExp(r'[\d\u0660-\u0669\u06F0-\u06F9]+(?:[.,]\d+)?');
    final match = regex.firstMatch(text);

    if (match != null) {
      String grade = match.group(0)!;
      // تحويل الأرقام العربية إلى إنجليزية
      grade = _convertArabicNumbers(grade);
      // استبدال الفاصلة بنقطة
      grade = grade.replaceAll(',', '.');
      return grade;
    }

    return null;
  }

  /// التعرف على رقم المادة
  Future<String?> recognizeSubjectIdFromImage(img.Image image) async {
    final text = await recognizeTextFromImage(image);
    if (text == null) return null;

    // استخراج الأرقام من النص
    final regex = RegExp(r'\d+');
    final match = regex.firstMatch(text);

    if (match != null) {
      return _convertArabicNumbers(match.group(0)!);
    }

    return null;
  }

  /// تحويل الأرقام العربية إلى إنجليزية
  String _convertArabicNumbers(String input) {
    const arabicNumbers = {
      '٠': '0', '١': '1', '٢': '2', '٣': '3', '٤': '4',
      '٥': '5', '٦': '6', '٧': '7', '٨': '8', '٩': '9',
      '۰': '0', '۱': '1', '۲': '2', '۳': '3', '۴': '4',
      '۵': '5', '۶': '6', '۷': '7', '۸': '8', '۹': '9',
    };

    String result = input;
    arabicNumbers.forEach((arabic, english) {
      result = result.replaceAll(arabic, english);
    });
    return result;
  }

  /// إغلاق الـ recognizer
  void dispose() {
    _textRecognizer.close();
  }
}
