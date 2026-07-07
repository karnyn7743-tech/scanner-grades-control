import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class ImageProcessor {

  // تحويل CameraImage إلى InputImage
  static Future<InputImage?> convertCameraImageToInputImage(CameraImage image) async {
    try {
      // تحويل تنسيق YUV420 إلى RGB
      final imageBytes = _convertYUV420ToRGB(image);
      if (imageBytes == null) return null;

      // إنشاء InputImage
      final inputImageData = InputImageData(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        imageRotation: InputImageRotation.Rotation_0deg,
        inputImageFormat: InputImageFormat.nv21,
        planeBytes: image.planes.map((plane) => plane.bytes).toList(),
        planeStrides: image.planes.map((plane) => plane.bytesPerRow).toList(),
      );

      return InputImage.fromBytes(bytes: imageBytes, inputImageData: inputImageData);
    } catch (e) {
      print('Error converting image: $e');
      return null;
    }
  }

  // قص منطقة محددة من الصورة
  static Future<InputImage?> cropImage(InputImage inputImage, Rect rect) async {
    try {
      // تحويل InputImage إلى صورة قابلة للقص
      final img.Image? originalImage = img.decodeImage(
          Uint8List.fromList(inputImage.bytes!)
      );

      if (originalImage == null) return null;

      // قص المنطقة
      final croppedImage = img.copyCrop(
        originalImage,
        x: rect.left.toInt(),
        y: rect.top.toInt(),
        width: rect.width.toInt(),
        height: rect.height.toInt(),
      );

      // تحويل الصورة المقصوصة إلى InputImage
      final croppedBytes = img.encodePng(croppedImage);
      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/temp_cropped.png';
      await File(tempPath).writeAsBytes(croppedBytes);

      final inputImageData = InputImageData(
        size: Size(croppedImage.width.toDouble(), croppedImage.height.toDouble()),
        imageRotation: InputImageRotation.Rotation_0deg,
        inputImageFormat: InputImageFormat.png,
      );

      return InputImage.fromFilePath(tempPath);
    } catch (e) {
      print('Error cropping image: $e');
      return null;
    }
  }

  // تحويل YUV420 إلى RGB (داخلية)
  static Uint8List? _convertYUV420ToRGB(CameraImage image) {
    try {
      final int width = image.width;
      final int height = image.height;
      final int uvPixelStride = image.planes[1].bytesPerPixel ?? 2;
      final int uvRowStride = image.planes[1].bytesPerRow;

      final Uint8List yuvBytes = Uint8List(width * height * 3 ~/ 2);
      int yIndex = 0;
      int uvIndex = 0;

      // نسخ Y plane
      yuvBytes.setAll(0, image.planes[0].bytes);
      yIndex = width * height;

      // نسخ UV planes
      final Uint8List uBytes = Uint8List(width * height ~/ 4);
      final Uint8List vBytes = Uint8List(width * height ~/ 4);

      for (int i = 0; i < image.planes[1].bytes.length; i += uvPixelStride) {
        uBytes[uvIndex] = image.planes[1].bytes[i];
        if (uvPixelStride == 2) {
          vBytes[uvIndex] = image.planes[1].bytes[i + 1];
        } else {
          vBytes[uvIndex] = image.planes[2]?.bytes[i] ?? 0;
        }
        uvIndex++;
      }

      // دمج YUV إلى RGB
      final Uint8List rgbBytes = Uint8List(width * height * 3);
      for (int i = 0; i < width * height; i++) {
        final int y = yuvBytes[i] & 0xFF;
        final int u = uBytes[i ~/ 4] & 0xFF;
        final int v = vBytes[i ~/ 4] & 0xFF;

        // تحويل YUV إلى RGB
        int r = (y + (1.370705 * (v - 128))).round();
        int g = (y - (0.698001 * (v - 128)) - (0.337633 * (u - 128))).round();
        int b = (y + (1.732446 * (u - 128))).round();

        rgbBytes[i * 3] = r.clamp(0, 255);
        rgbBytes[i * 3 + 1] = g.clamp(0, 255);
        rgbBytes[i * 3 + 2] = b.clamp(0, 255);
      }

      return rgbBytes;
    } catch (e) {
      print('Error converting YUV to RGB: $e');
      return null;
    }
  }
}
