import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

class CameraService {
  CameraController? _controller;
  List<CameraDescription>? _cameras;

  /// تهيئة الكاميرا
  Future<CameraController> initializeCamera() async {
    _cameras = await availableCameras();
    if (_cameras == null || _cameras!.isEmpty) {
      throw Exception('No cameras available');
    }

    // استخدام الكاميرا الخلفية
    final backCamera = _cameras!.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => _cameras![0],
    );

    _controller = CameraController(
      backCamera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await _controller!.initialize();
    return _controller!;
  }

  /// بدء تدفق الصور
  void startImageStream(Function(CameraImage) onImage) {
    if (_controller != null && _controller!.value.isInitialized) {
      _controller!.startImageStream(onImage);
    }
  }

  /// إيقاف تدفق الصور
  void stopImageStream() {
    if (_controller != null && _controller!.value.isStreamingImages) {
      _controller!.stopImageStream();
    }
  }

  /// التقاط صورة
  Future<XFile?> captureImage() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      return null;
    }

    try {
      final XFile image = await _controller!.takePicture();
      return image;
    } catch (e) {
      print('Error capturing image: $e');
      return null;
    }
  }

  /// تحويل CameraImage إلى img.Image
  img.Image? convertCameraImageToImage(CameraImage cameraImage) {
    try {
      final rgbBytes = _convertYUV420ToRGB(cameraImage);
      if (rgbBytes == null) return null;

      final image = img.decodeImage(rgbBytes);
      return image;
    } catch (e) {
      print('Error converting CameraImage: $e');
      return null;
    }
  }

  /// قص جزء من CameraImage
  img.Image? cropCameraImage(
    CameraImage cameraImage,
    Rect rect,
    Size screenSize,
  ) {
    try {
      final originalImage = convertCameraImageToImage(cameraImage);
      if (originalImage == null) return null;

      // حساب إحداثيات القص
      final scaleX = originalImage.width / screenSize.width;
      final scaleY = originalImage.height / screenSize.height;

      final cropX = (rect.left * scaleX).toInt().clamp(
        0,
        originalImage.width - 1,
      );
      final cropY = (rect.top * scaleY).toInt().clamp(
        0,
        originalImage.height - 1,
      );
      final cropWidth = (rect.width * scaleX).toInt().clamp(
        1,
        originalImage.width - cropX,
      );
      final cropHeight = (rect.height * scaleY).toInt().clamp(
        1,
        originalImage.height - cropY,
      );

      final croppedImage = img.copyCrop(
        originalImage,
        x: cropX,
        y: cropY,
        width: cropWidth,
        height: cropHeight,
      );

      return croppedImage;
    } catch (e) {
      print('Error cropping camera image: $e');
      return null;
    }
  }

  /// تحويل YUV420 إلى RGB
  Uint8List? _convertYUV420ToRGB(CameraImage image) {
    try {
      final int width = image.width;
      final int height = image.height;

      final Uint8List rgbBytes = Uint8List(width * height * 3);

      final Uint8List yPlane = image.planes[0].bytes;
      final Uint8List uPlane = image.planes[1].bytes;
      final Uint8List vPlane = image.planes.length > 2
          ? image.planes[2].bytes
          : uPlane;

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

          int r = (yValue + 1.402 * (vValue - 128)).round();
          int g = (yValue - 0.344 * (uValue - 128) - 0.714 * (vValue - 128))
              .round();
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

  /// تبديل الفلاش
  Future<void> toggleFlash() async {
    if (_controller == null) return;

    final isFlashOn = _controller!.value.flashMode == FlashMode.torch;
    await _controller!.setFlashMode(
      isFlashOn ? FlashMode.off : FlashMode.torch,
    );
  }

  /// تغيير الكاميرا (خلفية/أمامية)
  Future<void> switchCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;

    final currentLens = _controller!.description.lensDirection;
    final newCamera = currentLens == CameraLensDirection.back
        ? _cameras!.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.front,
          )
        : _cameras!.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.back,
          );

    await _controller!.dispose();
    _controller = CameraController(newCamera, ResolutionPreset.medium);
    await _controller!.initialize();
  }

  /// إيقاف الكاميرا وتحرير الموارد
  void dispose() {
    stopImageStream();
    _controller?.dispose();
  }
}
