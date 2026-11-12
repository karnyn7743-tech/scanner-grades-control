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

  Future<int?> recognizeDigit(img.Image digitImage) async {
    if (!_isReady || _interpreter == null) return null;

    try {
      final processed = _preprocess(digitImage);
      final input = _toFloat32(processed);
      final output = List.filled(10, 0.0).reshape([1, 10]);

      _interpreter!.run(input, output);

      final probs = (output[0] as List).cast<double>();
      int best = 0;
      double bestP = probs[0];
      for (int i = 1; i < probs.length; i++) {
        if (probs[i] > bestP) {
          bestP = probs[i];
          best = i;
        }
      }

      if (bestP < 0.55) return null;
      return best;
    } catch (e) {
      print('خطأ في التعرف: $e');
      return null;
    }
  }

  Future<String> recognizeGrade(img.Image image) async {
    if (!_isReady) return '';

    final digits = _splitIntoDigits(image);
    if (digits.isEmpty) return '';

    final buffer = StringBuffer();
    for (var d in digits) {
      final digit = await recognizeDigit(d);
      if (digit != null) buffer.write(digit);
    }
    return buffer.toString();
  }

  img.Image _preprocess(img.Image src) {
    var gray = img.grayscale(src);
    gray = img.adjustColor(gray, contrast: 1.8);
    final inverted = img.invert(gray);
    final resized = img.copyResize(
      inverted,
      width: 28,
      height: 28,
      interpolation: img.Interpolation.cubic,
    );
    return resized;
  }

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

  List<img.Image> _splitIntoDigits(img.Image image) {
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

    final digits = <img.Image>[];
    int? start;
    for (int x = 0; x < hasContent.length; x++) {
      if (hasContent[x] && start == null) {
        start = x;
      } else if (!hasContent[x] && start != null) {
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

    if (digits.isEmpty) digits.add(image);
    return digits;
  }

  void dispose() {
    _interpreter?.close();
  }
}
