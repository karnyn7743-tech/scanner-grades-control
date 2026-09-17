import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class DigitRecognizer {
  Interpreter? _interpreter;
  bool _isReady = false;

  Future<void> init() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/models/mnist.tflite');
      _isReady = true;
      print('✅ تم تحميل نموذج الأرقام');
    } catch (e) {
      print('❌ فشل تحميل النموذج: $e');
      _isReady = false;
    }
  }

  bool get isReady => _isReady;

  /// التعرف على رقم واحد من صورة
  Future<int?> recognizeDigit(img.Image digitImage) async {
    if (!_isReady || _interpreter == null) return null;

    try {
      // 1. المعالجة المسبقة
      final processed = _preprocess(digitImage);

      // 2. تحويل إلى مصفوفة [1][28][28][1]
      final input = _toFloat32(processed);

      // 3. تشغيل النموذج
      final output = List.filled(10, 0.0).reshape([1, 10]);
      _interpreter!.run(input, output);

      // 4. استخراج النتيجة
      final probs = (output[0] as List).cast<double>();
      int best = 0;
      double bestP = probs[0];
      for (int i = 1; i < probs.length; i++) {
        if (probs[i] > bestP) {
          bestP = probs[i];
          best = i;
        }
      }

      print('🔢 الرقم: $best (ثقة: ${(bestP * 100).toStringAsFixed(1)}%)');

      // 5. رفض النتائج الضعيفة
      if (bestP < 0.55) return null;
      return best;
    } catch (e) {
      print('خطأ في التعرف: $e');
      return null;
    }
  }

  /// التعرف على درجة كاملة (قد تحتوي على رقمين أو أكثر)
  Future<String> recognizeGrade(img.Image image) async {
    // إذا كان النموذج غير جاهز، نرجع فارغ
    if (!_isReady) return '';

    // تقسيم الصورة إلى أرقام منفصلة
    final digits = _splitIntoDigits(image);
    if (digits.isEmpty) return '';

    final buffer = StringBuffer();
    for (var d in digits) {
      final digit = await recognizeDigit(d);
      if (digit != null) buffer.write(digit);
    }
    return buffer.toString();
  }

  /// المعالجة المسبقة
  img.Image _preprocess(img.Image src) {
    // 1. تحويل إلى رمادي
    var gray = img.grayscale(src);

    // 2. تحسين التباين
    gray = img.adjustColor(gray, contrast: 1.8);

    // 3. عكس الألوان (MNIST يتوقع خلفية سوداء وكتابة بيضاء)
    final inverted = img.invert(gray);

    // 4. تغيير الحجم إلى 28×28
    final resized = img.copyResize(
      inverted,
      width: 28,
      height: 28,
      interpolation: img.Interpolation.cubic,
    );

    return resized;
  }

  /// تحويل الصورة إلى مصفوفة float32
  List<List<List<List<double>>>> _toFloat32(img.Image image) {
    return List.generate(1, (_) =>
      List.generate(28, (y) =>
        List.generate(28, (x) {
          final p = image.getPixel(x, y);
          final value = (p.r + p.g + p.b) / 3.0 / 255.0;
          return [value];
        })
      )
    );
  }

  /// تقسيم الصورة إلى أرقام منفصلة
  List<img.Image> _splitIntoDigits(img.Image image) {
    // 1. حساب كثافة الأعمدة
    final hasContent = List<bool>.filled(image.width, false);
    for (int x = 0; x < image.width; x++) {
      for (int y = 0; y < image.height; y++) {
        final p = image.getPixel(x, y);
        final brightness = (p.r + p.g + p.b) / 3;
        if (brightness < 128) {
          hasContent[x] = true;
          break;
        }
      }
    }

    // 2. تجميع الأعمدة المتصلة
    final digits = <img.Image>[];
    int? start;
    for (int x = 0; x < hasContent.length; x++) {
      if (hasContent[x] && start == null) {
        start = x;
      } else if (!hasContent[x] && start != null) {
        // تجاهل المناطق الصغيرة جداً (ضجيج)
        if (x - start >= 3) {
          final d = img.copyCrop(
            image,
            x: start,
            y: 0,
            width: x - start,
            height: image.height,
          );
          digits.add(d);
        }
        start = null;
      }
    }

    // إذا كان النص مكتوباً بشكل متصل، نرجع الصورة كاملة
    if (digits.isEmpty) digits.add(image);

    return digits;
  }

  void dispose() {
    _interpreter?.close();
  }
}
