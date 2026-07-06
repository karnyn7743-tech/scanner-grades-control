import 'package:flutter/material.dart';
import 'exam_generator_screen.dart'; // استيراد الشاشة الجديدة

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffeef7fe), // لون الخلفية الفاتح المريح للعين
      appBar: AppBar(
        title: const Text('...نظام الكنترول للأتمتة المصغرة للإمتحانات'),
        backgroundColor: const Color(0xff029ae4),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.dark_mode),
            onPressed: () {},
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 40),
            
            // الزر الأول
            _buildMenuButton(
              icon: Icons.qr_code_2,
              text: 'تكوين رموز إستجابة سريعة للطلاب',
              onPressed: () {
                // منطق توليد الرموز الحالي الخاص بك
              },
            ),
            const SizedBox(height: 20),

            // الزر الثاني
            _buildMenuButton(
              icon: Icons.qr_code_scanner,
              text: 'قراءة رموز الإستجابة السريعة للطلاب',
              onPressed: () {
                // منطق القراءة الحالي الخاص بك
              },
            ),
            const SizedBox(height: 20),

            // الزر الثالث
            _buildMenuButton(
              icon: Icons.edit_note,
              text: 'إدخال الدرجات من أوراق الإجابة',
              onPressed: () {
                // منطق إدخال الدرجات الحالي الخاص بك
              },
            ),
            const SizedBox(height: 20),

            // الزر الرابع الجديد: المخصص للميزة الجديدة
            _buildMenuButton(
              icon: Icons.print,
              text: 'توليد وطباعة أوراق الاختبارات مأتمتة',
              onPressed: () {
                // الانتقال إلى شاشة توليد أوراق الاختبارات الجديدة
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ExamGeneratorScreen()),
                );
              },
              backgroundColor: const Color(0xff00a65a), // لون أخضر مميز للطباعة والتوليد
            ),
          ],
        ),
      ),
    );
  }

  // دالة مساعدة لبناء الأزرار بنفس التصميم في الصورة المرفقة
  Widget _buildMenuButton({
    required IconData icon,
    required String text,
    required VoidCallback onPressed,
    Color backgroundColor = const Color(0xff029ae4),
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15), // حواف دائرية ناعمة كما بالأيقونة والتصميم
        ),
        elevation: 3,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo',
              ),
              textDirection: TextDirection.rtl,
            ),
          ),
        ],
      ),
    );
  }
}

