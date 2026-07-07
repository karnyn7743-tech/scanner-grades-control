import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class Helpers {
  /// عرض رسالة SnackBar
  static void showSnackBar(BuildContext context, String message, {
    Color backgroundColor = Colors.blue,
    Duration duration = const Duration(seconds: 2),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: duration,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// عرض حوار تأكيد
  static Future<bool> showConfirmDialog(BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'نعم',
    String cancelText = 'إلغاء',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancelText),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// عرض حوار إدخال نص
  static Future<String?> showInputDialog(BuildContext context, {
    required String title,
    String? initialValue,
    String hintText = '',
  }) async {
    final controller = TextEditingController(text: initialValue);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: hintText),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text('حفظ'),
          ),
        ],
      ),
    );
    return result;
  }

  /// إنشاء معرف فريد
  static String generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  /// الحصول على مسار التخزين المؤقت
  static Future<String> getTempPath() async {
    final tempDir = await getTemporaryDirectory();
    return tempDir.path;
  }

  /// حذف الملفات المؤقتة
  static Future<void> cleanTempFiles() async {
    final tempDir = await getTemporaryDirectory();
    final files = await tempDir.list().toList();
    for (var file in files) {
      if (file.path.contains('temp_')) {
        await file.delete();
      }
    }
  }

  /// تنسيق التاريخ
  static String formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
  }

  /// التحقق من صحة البريد الإلكتروني
  static bool isValidEmail(String email) {
    final regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return regex.hasMatch(email);
  }

  /// تحويل التاريخ إلى String
  static String dateToString(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
