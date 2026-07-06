import 'package:flutter/material.dart';
import 'screens/exam_generator_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scanner Grades Control',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const ExamGeneratorScreen(),
    );
  }
}
