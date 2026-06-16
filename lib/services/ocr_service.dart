import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  // دالة حقيقية لقراءة الدرجة المتواجدة على يسار كود الـ QR
  Future<String> readGradeFromLeftOfQr(Uint8List imageBytes) async {
    try {
      // 1. تحويل البايتات إلى ملف مؤقت لأن مكتبة جوجل تحتاج مسار ملف
      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/temp_ocr_image.png').create();
      await file.writeAsBytes(imageBytes);

      // 2. تهيئة المعالج وصورة المدخلات
      final inputImage = InputImage.fromFile(file);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

      // 3. معالجة الصورة واستخراج النصوص
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      
      // إغلاق المعالج لتحرير الذاكرة
      await textRecognizer.close();

      // 4. البحث عن أول رقم يمثل الدرجة في النص المستخرج
      String extractedText = recognizedText.text.trim();
      
      // تعبير نمطي (RegExp) للبحث عن أي رقم مكون من خانة أو خانتين داخل النص
      RegExp regExp = RegExp(r'\b\d{1,2}\b'); 
      Match? match = regExp.firstMatch(extractedText);

      if (match != null) {
        return match.group(0)!; // إرجاع الدرجة الحقيقية المستخرجة
      } else {
        return "لم يتم رصد درجة"; // في حال لم يجد أي رقم في منطقة الفحص
      }
    } catch (e) {
      return "خطأ في القراءة: $e";
    }
  }
}
