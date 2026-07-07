class ScanZone {
  final String name;
  final String type; // 'subject_id', 'qr', 'grade'
  final Rect rect; // المنطقة على الشاشة

  ScanZone({
    required this.name,
    required this.type,
    required this.rect,
  });
}

class Rect {
  final double left;
  final double top;
  final double width;
  final double height;

  Rect({required this.left, required this.top, required this.width, required this.height});
}
