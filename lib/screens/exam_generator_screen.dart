import 'package:flutter/material.dart';

class ExamGeneratorScreen extends StatefulWidget {
  const ExamGeneratorScreen({super.key});

  @override
  State<ExamGeneratorScreen> createState() => _ExamGeneratorScreenState();
}

class _ExamGeneratorScreenState extends State<ExamGeneratorScreen> {
  String? _selectedClass;
  String? _selectedSubject;
  final TextEditingController _examNameController = TextEditingController();
  final List<String> _classList = ['1A', '2B', '3C'];
  final List<String> _subjectList = ['رياضيات', 'فيزياء', 'كيمياء'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('توليد أوراق الامتحان')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: _selectedClass,
              hint: const Text('اختر الصف'),
              items: _classList.map((cls) => DropdownMenuItem(value: cls, child: Text(cls))).toList(),
              onChanged: (value) => setState(() => _selectedClass = value),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedSubject,
              hint: const Text('اختر المادة'),
              items: _subjectList.map((sub) => DropdownMenuItem(value: sub, child: Text(sub))).toList(),
              onChanged: (value) => setState(() => _selectedSubject = value),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _examNameController,
              decoration: const InputDecoration(labelText: 'اسم الامتحان', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: (_selectedClass != null && _selectedSubject != null)
                  ? () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('سيتم التوليد قريباً...')),
                      );
                    }
                  : null,
              child: const Text('توليد الأوراق'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _examNameController.dispose();
    super.dispose();
  }
}
