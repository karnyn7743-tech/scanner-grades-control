import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

class QrService {
  // دالة حقيقية لقراءة رمز الـ QR واستخراج رقم الطالب أو رقم جلوسه
  Future<String> scanQrFromImage(Uint8List imageBytes, int counter) async {
    try {
      // 1. تحويل البايتات إلى ملف مؤقت ليتمكن المحرك من قراءته
      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/temp_qr_image.png').create();
      await file.writeAsBytes(imageBytes);

      // 2. تهيئة المعالج وصورة المدخلات
      final inputImage = InputImage.fromFile(file);
      final barcodeScanner = BarcodeScanner(formats: [BarcodeFormat.qrCode]);

      // 3. معالجة الصورة واستخراج الرموز
      final List<Barcode> barcodes = await barcodeScanner.processImage(inputImage);
      
      // إغلاق المعالج لتحرير الذاكرة
      await barcodeScanner.close();

      // 4. التحقق من وجود رمز QR مقروء داخل الصورة
      if (barcodes.isNotEmpty) {
        // إرجاع القيمة الحقيقية المخزنة داخل الـ QR (مثل رقم جلوس الطالب)
        return barcodes.first.displayValue ?? "رمز فارغ";
      } else {
        // في حال فشل القراءة أو عدم وضوح الرمز، نترك حلاً بديلاً مؤقتاً لتجنب توقف عملك
        return "لم يتم رصد QR (بديل: ${2333 + counter})";
      }
    } catch (e) {
      return "خطأ في مسح الـ QR: $e";
    }
  }
}
