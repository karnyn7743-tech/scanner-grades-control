class GradeParser {

  // تحويل الأرقام العربية إلى أرقام إنجليزية
  static String convertArabicNumbers(String input) {
    const arabicNumbers = {
      '٠': '0', '١': '1', '٢': '2', '٣': '3', '٤': '4',
      '٥': '5', '٦': '6', '٧': '7', '٨': '8', '٩': '9',
    };

    String result = input;
    arabicNumbers.forEach((arabic, english) {
      result = result.replaceAll(arabic, english);
    });
    return result;
  }

  // استخراج الدرجة من النص (تتعامل مع أرقام عربية وإنجليزية وعلامات عشرية)
  static String extractGrade(String text) {
    // تحويل الأرقام العربية أولاً
    String normalized = convertArabicNumbers(text);

    // البحث عن أرقام (قد تحتوي على نقطة عشرية)
    final regex = RegExp(r'\d+(?:\.\d+)?');
    final match = regex.firstMatch(normalized);

    if (match != null) {
      return match.group(0)!;
    }

    return '';
  }

  // التحقق من صحة الدرجة (مثلاً بين 0 و 100)
  static bool isValidGrade(String grade, {double min = 0, double max = 100}) {
    try {
      final value = double.parse(grade);
      return value >= min && value <= max;
    } catch (e) {
      return false;
    }
  }
}
