import 'package:flutter/material.dart';

class Note {
  final String id;
  final String type; // 'error', 'warning', 'success', 'info'
  final String title;
  final String message;
  final DateTime timestamp;
  final String? studentId;
  final String? studentName;

  Note({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.timestamp,
    this.studentId,
    this.studentName,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'title': title,
    'message': message,
    'timestamp': timestamp.toIso8601String(),
    'studentId': studentId,
    'studentName': studentName,
  }
}

class NotesScreen extends StatefulWidget {
  final List<Note> notes;
  final Function(List<Note>) onNotesChanged;

  const NotesScreen({
    Key? key,
    required this.notes,
    required this.onNotesChanged,
  }) : super(key: key);

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  String _filter = 'all'; // all, error, warning, success
  String _searchQuery = '';

  List<Note> get _filteredNotes {
    var filtered = widget.notes;

    // تطبيق الفلتر
    if (_filter != 'all') {
      filtered = filtered.where((note) => note.type == _filter).toList();
    }

    // تطبيق البحث
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((note) =>
      note.title.contains(_searchQuery) ||
          note.message.contains(_searchQuery) ||
          (note.studentName?.contains(_searchQuery) ?? false)
      ).toList();
    }

    // ترتيب من الأحدث إلى الأقدم
    filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return filtered;
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'error': return Colors.red;
      case 'warning': return Colors.orange;
      case 'success': return Colors.green;
      case 'info': return Colors.blue;
      default: return Colors.grey;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'error': return Icons.error;
      case 'warning': return Icons.warning;
      case 'success': return Icons.check_circle;
      case 'info': return Icons.info;
      default: return Icons.note;
    }
  }

  void _exportNotes() {
    // تصدير الملاحظات إلى ملف نصي
    final content = StringBuffer();
    content.writeln('تقرير الملاحظات - ${DateTime.now()}');
    content.writeln('=' * 50);
    content.writeln();

    for (var note in widget.notes) {
      content.writeln('[${note.timestamp.toString().substring(0, 19)}] ${note.type.toUpperCase()}');
      content.writeln('   ${note.title}: ${note.message}');
      if (note.studentName != null) {
        content.writeln('   الطالب: ${note.studentName} (${note.studentId ?? "بدون رقم"})');
      }
      content.writeln();
    }

    // هنا يمكن إضافة كود لحفظ الملف
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم تصدير ${widget.notes.length} ملاحظة')),
    );
  }

  void _clearAllNotes() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('مسح جميع الملاحظات'),
        content: Text('هل أنت متأكد من رغبتك في مسح جميع الملاحظات؟ هذا الإجراء لا يمكن التراجع عنه.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              widget.onNotesChanged([]);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('تم مسح جميع الملاحظات')),
              );
            },
            child: Text('مسح الكل', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('الملاحظات (${widget.notes.length})'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.download),
            onPressed: _exportNotes,
            tooltip: 'تصدير',
          ),
          if (widget.notes.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_sweep),
              onPressed: _clearAllNotes,
              tooltip: 'مسح الكل',
            ),
        ],
      ),
      body: Column(
        children: [
          // شريط البحث والفلتر
          Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              children: [
                // حقل البحث
                TextField(
                  decoration: InputDecoration(
                    hintText: 'بحث...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
                SizedBox(height: 10),
                // أزرار الفلتر
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('الكل', 'all'),
                      _buildFilterChip('أخطاء', 'error'),
                      _buildFilterChip('تحذيرات', 'warning'),
                      _buildFilterChip('نجاح', 'success'),
                      _buildFilterChip('معلومات', 'info'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // قائمة الملاحظات
          Expanded(
            child: _filteredNotes.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.note_add, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'لا توجد ملاحظات',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  Text(
                    'ستظهر هنا أي ملاحظات أو أخطاء أثناء المسح',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: EdgeInsets.all(8),
              itemCount: _filteredNotes.length,
              itemBuilder: (context, index) {
                final note = _filteredNotes[index];
                return Card(
                  margin: EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getTypeColor(note.type).withOpacity(0.2),
                      child: Icon(
                        _getTypeIcon(note.type),
                        color: _getTypeColor(note.type),
                      ),
                    ),
                    title: Text(
                      note.title,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(note.message),
                        if (note.studentName != null)
                          Text(
                            '👤 ${note.studentName}',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        Text(
                          '🕐 ${note.timestamp.toString().substring(11, 19)}',
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ),
                    isThreeLine: true,
                    trailing: IconButton(
                      icon: Icon(Icons.close, size: 20),
                      onPressed: () {
                        final newNotes = List<Note>.from(widget.notes);
                        newNotes.removeWhere((n) => n.id == note.id);
                        widget.onNotesChanged(newNotes);
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: _filter == value,
        onSelected: (selected) {
          setState(() {
            _filter = selected ? value : 'all';
          });
        },
        backgroundColor: Colors.grey[200],
        selectedColor: Colors.blue[100],
        checkmarkColor: Colors.blue,
      ),
    );
  }
}
