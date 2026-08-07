import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'generate_qr_screen.dart';
import 'scan_qr_screen.dart';
import 'grade_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('نظام إدارة الدرجات'),
        centerTitle: true,
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildMainButton(
              context,
              title: 'تكوين QR Code للأرقام السرية للطلاب',
              icon: Icons.qr_code,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GenerateQRScreen()),
                );
              },
            ),
            const SizedBox(height: 20),
            _buildMainButton(
              context,
              title: 'قراءة الـ QR Code للطلاب',
              icon: Icons.qr_code_scanner,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ScanQRScreen()),
                );
              },
            ),
            const SizedBox(height: 20),
            _buildMainButton(
              context,
              title: 'إدخال الدرجات من أوراق الإجابة',
              icon: Icons.edit_note,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GradeEntryScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainButton(
    BuildContext context, {
    required String title,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 80,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 32, color: Colors.white),
        label: Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          textAlign: TextAlign.center,
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 6,
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
    );
  }
}
