class Student {
  final String id;
  final String secretCode;
  final String name;
  final String className;
  final Map<String, String> grades; // subject -> grade

  Student({
    required this.id,
    required this.secretCode,
    required this.name,
    required this.className,
    Map<String, String>? grades,
  }) : grades = grades ?? {};

  factory Student.fromExcelRow(List<dynamic> row, int rowIndex) {
    return Student(
      id: row[0]?.toString() ?? '',
      name: row[1]?.toString() ?? '',
      className: row[2]?.toString() ?? '',
      secretCode: row[3]?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'secretCode': secretCode,
    'name': name,
    'className': className,
    'grades': grades,
  };
}
