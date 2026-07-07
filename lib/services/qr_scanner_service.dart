import 'dart:io';
import 'dart:typed_data';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class QRScannerService {

  /// مسح QR Code من ملف صورة
  static Future<String?> scanQRFromFile(String filePath) async {
    try {
      final Barcode? result = await MobileScanner.scanFile(File(filePath));
      return result?.rawValue;
    } catch (e) {
      print('QR scan from file error: $e');
      return null;
    }
  }

  /// مسح QR Code من Uint8List (بايتات الصورة)
  static Future<String?> scanQRFromBytes(Uint8List imageBytes) async {
    try {
      // حفظ مؤقت للصورة
      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/qr_${DateTime.now().millisecondsSinceEpoch}.png';
      await File(tempPath).writeAsBytes(imageBytes);

      // مسح QR
      final result = await scanQRFromFile(tempPath);

      // حذف الملف المؤقت
      await File(tempPath).delete();

      return result;
    } catch (e) {
      print('QR scan from bytes error: $e');
      return null;
    }
  }

  /// مسح QR Code من صورة (ككائن img.Image)
  static Future<String?> scanQRFromImage(img.Image image) async {
    try {
      final bytes = Uint8List.fromList(img.encodePng(image));
      return await scanQRFromBytes(bytes);
    } catch (e) {
      print('QR scan from image error: $e');
      return null;
    }
  }

  /// التحقق من صحة QR Code
  static bool isValidQRCode(String qrCode) {
    // يمكنك تخصيص هذا حسب احتياجك
    // مثلاً: التحقق من أن الرقم السري يتكون من أرقام فقط وبطول معين
    return qrCode.isNotEmpty && qrCode.length >= 4;
  }

  /// استخراج الرقم السري من QR Code (إذا كان هناك تنسيق خاص)
  static String extractSecretCode(String qrCode) {
    // إذا كان QR Code يحتوي على معلومات إضافية، استخرج الرقم السري فقط
    // مثال: "STUDENT:12345" -> "12345"
    final regex = RegExp(r'\d+');
    final match = regex.firstMatch(qrCode);
    return match?.group(0) ?? qrCode;
  }
}
