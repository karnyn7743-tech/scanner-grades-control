import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../models/exam_models.dart';
import '../services/activation_service.dart';
import '../services/exam_storage_service.dart';
import 'activation_screen.dart';
import 'exam_editor_screen.dart';
import 'grade_scanner_screen.dart';
import 'manual_grade_entry_screen.dart'; // ✅ تمت إضافة استدعاء الشاشة الجديدة

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isActivated = false;
  int _remainingDays = 0;

  @override
  void initState() {
    super.initState();
    _checkActivationStatus();
  }

  Future<void> _checkActivationStatus() async {
    final status = await ActivationService.getLicenseStatus();
    final remaining = await ActivationService.getRemainingTrialDays();
    if (mounted) {
      setState(() {
        _isActivated = (status == LicenseStatus.full);
        _remainingDays = remaining;
      });
    }
  }

  Future<bool> _verifyTrialOrActivated() async {
    final status = await ActivationService.getLicenseStatus();
    if (status == LicenseStatus.full || status == LicenseStatus.trial) {
      return true;
    }

    if (!mounted) return false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.lock_clock, color: Colors.amber),
            SizedBox(width: 8),
            Text('انتهت الفترة التجريبية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: const Text(
          'انتهت فترة الـ 30 يوماً المتاحة لتجربة التطبيق.\n'
          'لإنشاء المزيد من الاختبارات والوصول لجميع الميزات، يرجى تفعيل النسخة الكاملة.',
          style: TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B5E20)),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ActivationScreen()),
              ).then((_) => _checkActivationStatus());
            },
            child: const Text('إدخال مفتاح التنشيط', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return false;
  }

  // 1. تصميم اختبار شامل
  Future<void> _designTraditionalExam() async {
    if (!await _verifyTrialOrActivated()) return;

    if (!_isActivated) {
      await ActivationService.incrementTrialCount();
    }

    final newExam = ExamModel(
      id: const Uuid().v4(),
      fileName: 'اختبار_شامل_${DateTime.now().millisecondsSinceEpoch}',
      examType: ExamType.traditional,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      header: HeaderModel(),
      questions: [],
    );

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExamEditorScreen(initialExam: newExam, isNewExam: true),
      ),
    ).then((_) => _checkActivationStatus());
  }

  // 2. تصميم اختبار مؤتمت
  Future<void> _designAutomatedExam() async {
    if (!await _verifyTrialOrActivated()) return;

    final tfCountCtrl = TextEditingController(text: '10');
    final mcqCountCtrl = TextEditingController(text: '10');
    ChoiceSymbolType symbolType = ChoiceSymbolType.arabicLetters;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.checklist_rtl, color: Color(0xFF1B5E20)),
              SizedBox(width: 8),
              Text('إعدادات الاختبار المؤتمت (OMR)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('حدد عدد الفقرات لكل نمط سؤال:', style: TextStyle(fontSize: 12)),
                const SizedBox(height: 12),
                TextField(
                  controller: tfCountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'عدد فقرات الصح والخطأ (ص / خ)',
                    prefixIcon: Icon(Icons.check_circle_outline, color: Color(0xFF1B5E20)),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: mcqCountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'عدد فقرات الاختيار من متعدد',
                    prefixIcon: Icon(Icons.format_list_numbered, color: Color(0xFF1B5E20)),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('نوع رموز البدائل:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('أ ، ب ، جـ ، د')),
                        selected: symbolType == ChoiceSymbolType.arabicLetters,
                        selectedColor: const Color(0xFF1B5E20),
                        labelStyle: TextStyle(
                          color: symbolType == ChoiceSymbolType.arabicLetters ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                        onSelected: (val) {
                          if (val) setDlgState(() => symbolType = ChoiceSymbolType.arabicLetters);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('١ ، ٢ ، ٣ ، ٤')),
                        selected: symbolType == ChoiceSymbolType.numbers,
                        selectedColor: const Color(0xFF1B5E20),
                        labelStyle: TextStyle(
                          color: symbolType == ChoiceSymbolType.numbers ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                        onSelected: (val) {
                          if (val) setDlgState(() => symbolType = ChoiceSymbolType.numbers);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B5E20)),
              onPressed: () {
                final tf = int.tryParse(tfCountCtrl.text.trim()) ?? 10;
                final mcq = int.tryParse(mcqCountCtrl.text.trim()) ?? 10;
                Navigator.pop(ctx);
                _generateAutomatedExam(tfCount: tf, mcqCount: mcq, symbolType: symbolType);
              },
              child: const Text('توليد الاختبار', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _generateAutomatedExam({
    required int tfCount,
    required int mcqCount,
    required ChoiceSymbolType symbolType,
  }) {
    final List<QuestionModel> generatedQuestions = [];

    if (tfCount > 0) {
      final buffer = StringBuffer();
      buffer.writeln('ظلل الدائرة (ص) إذا كانت العبارة صحيحة، والدائرة (خ) إذا كانت العبارة خاطئة:');
      for (int i = 1; i <= tfCount; i++) {
        buffer.writeln('$i - (   ) ................................................................');
      }

      generatedQuestions.add(
        QuestionModel(
          id: const Uuid().v4(),
          title: 'س ١',
          titleOrientation: QuestionTitleOrientation.horizontal,
          mark: tfCount.toDouble(),
          spans: [
            TextSpanModel(text: buffer.toString().trim(), fontSize: 13.0, fontFamily: 'Amiri'),
          ],
          answerKey: '',
          isTwoColumns: false,
        ),
      );
    }

    if (mcqCount > 0) {
      final buffer = StringBuffer();
      final bool isLetters = symbolType == ChoiceSymbolType.arabicLetters;
      final choicesStr = isLetters ? '[ أ- .. | ب- .. | جـ- .. | د- .. ]' : '[ ١- .. | ٢- .. | ٣- .. | ٤- .. ]';

      buffer.writeln('ظلل الدائرة التي تمثل الإجابة الصحيحة لكل فقرة من الفقرات الآتية:');
      for (int i = 1; i <= mcqCount; i++) {
        buffer.writeln('$i - ........................................ $choicesStr');
      }

      generatedQuestions.add(
        QuestionModel(
          id: const Uuid().v4(),
          title: tfCount > 0 ? 'س ٢' : 'س ١',
          titleOrientation: QuestionTitleOrientation.horizontal,
          mark: mcqCount.toDouble(),
          spans: [
            TextSpanModel(text: buffer.toString().trim(), fontSize: 13.0, fontFamily: 'Amiri'),
          ],
          answerKey: '',
          isTwoColumns: true,
        ),
      );
    }

    final newExam = ExamModel(
      id: const Uuid().v4(),
      fileName: 'اختبار_مؤتمت_${DateTime.now().millisecondsSinceEpoch}',
      examType: ExamType.automated,
      automatedConfig: AutomatedExamConfig(
        trueFalseCount: tfCount,
        mcqCount: mcqCount,
        choiceSymbolType: symbolType,
      ),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      header: HeaderModel(
        examTitle: 'اختبار مؤتمت (نماذج التظليل الذكية)',
        instructionText: 'أجب بتظليل الدائرة المناسبة في ورقة الإجابة المخصصة',
      ),
      questions: generatedQuestions,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExamEditorScreen(initialExam: newExam, isNewExam: true),
      ),
    ).then((_) => _checkActivationStatus());
  }

  // 3. إدخال درجات الطلاب من أوراق الاختبار
  void _openGradeScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const GradeScannerScreen()),
    );
  }

  // 4. إدخال بقية درجات أعمال السنة (جديد)
  void _openManualGradeEntry() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ManualGradeEntryScreen()),
    );
  }

  // نافذة استعراض الاختبارات المحفوظة
  Future<void> _showSavedExamsModal() async {
    final exams = await ExamStorageService.getAllExams();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('الاختبارات المحفوظة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('${exams.length} اختبار', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: exams.isEmpty
                  ? const Center(child: Text('لا توجد اختبارات محفوظة بعد', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: exams.length,
                      itemBuilder: (context, i) {
                        final e = exams[i];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF1B5E20),
                            child: Icon(
                              e.examType == ExamType.automated ? Icons.checklist_rtl : Icons.description,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          title: Text(e.header.subject.isNotEmpty ? e.header.subject : 'مادة غير محددة',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(e.header.examTitle),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                            onPressed: () async {
                              await ExamStorageService.deleteExam(e.id);
                              Navigator.pop(ctx);
                              _showSavedExamsModal();
                            },
                          ),
                          onTap: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => ExamEditorScreen(initialExam: e, isNewExam: false)),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9), // أخضر فاتح للشاشة كاملة
      appBar: AppBar(
        title: const Text(
          'المحرر البسيط للإختبارات والأتمتة',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF1B5E20), // أخضر غامق للعنوان
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open, color: Colors.white),
            tooltip: 'الاختبارات المحفوظة',
            onPressed: _showSavedExamsModal,
          ),
          if (!_isActivated)
            IconButton(
              icon: const Icon(Icons.key, color: Colors.amberAccent),
              tooltip: 'تنشيط النسخة الكاملة',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ActivationScreen()),
                ).then((_) => _checkActivationStatus());
              },
            ),
        ],
      ),
      body: Column(
        children: [
          if (!_isActivated)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: Colors.amber.shade100,
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined, color: Colors.brown, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _remainingDays > 0
                          ? 'الفترة التجريبية: متبقي لديك $_remainingDays يوماً.'
                          : 'انتهت الفترة التجريبية للاختبار المجاني.',
                      style: const TextStyle(color: Colors.brown, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ActivationScreen()),
                      ).then((_) => _checkActivationStatus());
                    },
                    child: const Text('تنشيط الآن', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                ],
              ),
            ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // الزر الأول
                    _buildMainActionButton(
                      title: 'تصميم اختبار شامل',
                      icon: Icons.edit_document,
                      onTap: _designTraditionalExam,
                      backgroundColor: const Color(0xFF7E57C2), // بنفسجي
                    ),
                    const SizedBox(height: 20),

                    // الزر الثاني
                    _buildMainActionButton(
                      title: 'تصميم اختبار مؤتمت',
                      icon: Icons.checklist_rtl,
                      onTap: _designAutomatedExam,
                      backgroundColor: const Color(0xFF7E57C2), // بنفسجي
                    ),
                    const SizedBox(height: 20),

                    // الزر الثالث
                    _buildMainActionButton(
                      title: 'إدخال درجات الطلاب من أوراق الإختبار',
                      icon: Icons.qr_code_scanner,
                      onTap: _openGradeScanner,
                      backgroundColor: const Color(0xFF00897B), // أخضر مزرق للتمييز
                    ),
                    const SizedBox(height: 20),

                    // الزر الرابع (الجديد)
                    _buildMainActionButton(
                      title: 'إدخال بقية درجات أعمال السنة',
                      icon: Icons.playlist_add_check,
                      onTap: _openManualGradeEntry,
                      backgroundColor: const Color(0xFF00897B), // أخضر مزرق للتمييز
                    ),
                  ],
                ),
              ),
            ),
          ),

          // تفاصيل المطور وروابط التواصل الثابتة في الأسفل
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F8E9),
              border: Border(top: BorderSide(color: Colors.green.shade200, width: 1)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'إعداد وتطوير: أ. فواز سنان البعيثي',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B5E20),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    InkWell(
                      onTap: () {
                        Clipboard.setData(const ClipboardData(text: '00967778064679'));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم نسخ رقم الواتساب: 00967778064679'), duration: Duration(seconds: 2)),
                        );
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.phone_android, size: 14, color: Color(0xFF1B5E20)),
                          SizedBox(width: 4),
                          Text(
                            'واتساب: 778064679',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(const ClipboardData(text: 'https://t.me/fawaz132'));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم نسخ رابط قناة التليجرام'), duration: Duration(seconds: 2)),
                        );
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.send_rounded, size: 14, color: Color(0xFF0284C7)),
                          SizedBox(width: 4),
                          Text(
                            'تليجرام: @fawaz132',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ويدجت زر بتصميم مائل واللون بنفسجي خفيف
  Widget _buildMainActionButton({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    Color backgroundColor = const Color(0xFF7E57C2), // ✅ تمت إضافة خاصية اللون هنا
  }) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: backgroundColor, // استخدام اللون الممرر
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(icon, color: Colors.white, size: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
