import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/pdf_generator_service.dart';

class ExamGeneratorScreen extends StatefulWidget {
  const ExamGeneratorScreen({super.key});

  @override
  State<ExamGeneratorScreen> createState() => _ExamGeneratorScreenState();
}

class _ExamGeneratorScreenState extends State<ExamGeneratorScreen> {
  String? _selectedClass;
  String? _selectedSubject;
  final TextEditingController _examNameController = TextEditingController();
  final List<String> _classList = ['1A', '2B', '3C']; // مثال، يمكنك تعديلها
  final List<String> _subjectList = ['رياضيات', 'فيزياء', 'كيمياء']; // مثال

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('توليد أوراق الامتحان'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: _selectedClass,
              hint: const Text('اختر الصف'),
              items: _classList.map((cls) {
                return DropdownMenuItem(value: cls, child: Text(cls));
              }).toList(),
              onChanged: (value) => setState(() => _selectedClass = value),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedSubject,
              hint: const Text('اختر المادة'),
              items: _subjectList.map((sub) {
                return DropdownMenuItem(value: sub, child: Text(sub));
              }).toList(),
              onChanged: (value) => setState(() => _selectedSubject = value),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _examNameController,
              decoration: const InputDecoration(
                labelText: 'اسم الامتحان',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: (_selectedClass != null && _selectedSubject != null)
                  ? _generatePapers
                  : null,
              child: const Text('توليد الأوراق'),
            ),
          ],
        ),
      ),
    );
  }

  void _generatePapers() async {
    // طلب إذن التخزين
    var status = await Permission.storage.request();
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب منح إذن التخزين لتوليد الأوراق')),
      );
      return;
    }

    // عرض مؤشر تحميل
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await PdfGeneratorService.generateExamPapers(
        selectedClass: _selectedClass!,
        selectedSubject: _selectedSubject!,
        examName: _examNameController.text,
      );
      // إغلاق مؤشر التحميل
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم توليد الأوراق بنجاح!')),
      );
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل التوليد: $e')),
      );
    }
  }

  @override
  void dispose() {
    _examNameController.dispose();
    super.dispose();
  }
}
