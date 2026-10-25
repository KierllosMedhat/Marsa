import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../handwriting/providers/canvas_provider.dart';
import '../../handwriting/widgets/ink_canvas.dart';
import '../../handwriting/widgets/tool_bar.dart';
import '../../../core/utils/stroke_serializer.dart';
import '../models/clinical_session.dart';
import '../providers/clinical_provider.dart';

class SessionWorkspaceScreen extends ConsumerStatefulWidget {
  const SessionWorkspaceScreen({super.key});

  @override
  ConsumerState<SessionWorkspaceScreen> createState() => _SessionWorkspaceScreenState();
}

class _SessionWorkspaceScreenState extends ConsumerState<SessionWorkspaceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Controllers for typed notes
  late TextEditingController _complaintController;
  late TextEditingController _sleepController;
  late TextEditingController _appetiteController;
  late TextEditingController _moodController;
  late TextEditingController _anxietyController;
  late TextEditingController _suicideController;
  late TextEditingController _substanceController;
  late TextEditingController _mseController;
  late TextEditingController _planController;
  late TextEditingController _followUpController;
  late TextEditingController _generalNotesController;

  // Prescription dialog inputs
  final _medNameController = TextEditingController();
  final _medDoseController = TextEditingController();
  final _medFreqController = TextEditingController();
  final _medDurationController = TextEditingController(text: '3 أشهر');
  final _medNotesController = TextEditingController();

  // Diagnosis dialog input
  final _diagController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    final session = ref.read(clinicalSessionProvider).currentSession;
    _complaintController = TextEditingController(text: session?.chiefComplaint ?? '');
    _sleepController = TextEditingController(text: session?.sleep ?? '');
    _appetiteController = TextEditingController(text: session?.appetite ?? '');
    _moodController = TextEditingController(text: session?.mood ?? '');
    _anxietyController = TextEditingController(text: session?.anxiety ?? '');
    _suicideController = TextEditingController(text: session?.suicidalSelfHarmAssessment ?? '');
    _substanceController = TextEditingController(text: session?.substanceUse ?? '');
    _mseController = TextEditingController(text: session?.mentalStatusExam ?? '');
    _planController = TextEditingController(text: session?.treatmentPlan ?? '');
    _followUpController = TextEditingController(text: session?.followUp ?? '');
    _generalNotesController = TextEditingController(text: session?.generalNotesTyped ?? '');
  }

  @override
  void dispose() {
    _tabController.dispose();
    _complaintController.dispose();
    _sleepController.dispose();
    _appetiteController.dispose();
    _moodController.dispose();
    _anxietyController.dispose();
    _suicideController.dispose();
    _substanceController.dispose();
    _mseController.dispose();
    _planController.dispose();
    _followUpController.dispose();
    _generalNotesController.dispose();
    _medNameController.dispose();
    _medDoseController.dispose();
    _medFreqController.dispose();
    _medDurationController.dispose();
    _medNotesController.dispose();
    _diagController.dispose();
    super.dispose();
  }

  void _syncTypedNotes() {
    ref.read(clinicalSessionProvider.notifier).updatePsychiatricSession(
          chiefComplaint: _complaintController.text,
          sleep: _sleepController.text,
          appetite: _appetiteController.text,
          mood: _moodController.text,
          anxiety: _anxietyController.text,
          suicidalSelfHarmAssessment: _suicideController.text,
          substanceUse: _substanceController.text,
          mentalStatusExam: _mseController.text,
          treatmentPlan: _planController.text,
          followUp: _followUpController.text,
          generalNotesTyped: _generalNotesController.text,
        );
  }

  void _showAddPrescriptionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.medication, color: Color(0xFF1B4F72)),
            SizedBox(width: 8),
            Text('إضافة وصفة دوائية للجلسة'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _medNameController,
                decoration: const InputDecoration(
                  labelText: 'اسم الدواء التجاري أو العلمي *',
                  hintText: 'مثال: سبرالكس (إسيتالوبرام)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _medDoseController,
                      decoration: const InputDecoration(
                        labelText: 'الجرعة',
                        hintText: '10 mg',
                        border: OutlineInputBorder(),
                      ),
                      textDirection: TextDirection.ltr,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _medFreqController,
                      decoration: const InputDecoration(
                        labelText: 'التكرار',
                        hintText: 'قرص صباحاً',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _medDurationController,
                decoration: const InputDecoration(
                  labelText: 'المدة (Duration)',
                  hintText: 'مثال: شهر، 6 أسابيع',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _medNotesController,
                decoration: const InputDecoration(
                  labelText: 'تعليمات الطبيب للمريض',
                  hintText: 'تؤخذ مع الطعام، مراجعة بعد 3 أسابيع',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_medNameController.text.trim().isNotEmpty) {
                ref.read(clinicalSessionProvider.notifier).addPrescription(
                      PrescriptionDraft(
                        medicationName: _medNameController.text.trim(),
                        dose: _medDoseController.text.trim(),
                        frequency: _medFreqController.text.trim(),
                        duration: _medDurationController.text.trim(),
                        instructions: _medNotesController.text.trim(),
                      ),
                    );
                _medNameController.clear();
                _medDoseController.clear();
                _medFreqController.clear();
                _medNotesController.clear();
                Navigator.pop(ctx);
              }
            },
            child: const Text('إضافة للروشتة'),
          ),
        ],
      ),
    );
  }

  void _showAddDiagnosisDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.assignment_turned_in, color: Color(0xFF1B4F72)),
            SizedBox(width: 8),
            Text('تسجيل تشخيص إكلينيكي'),
          ],
        ),
        content: TextField(
          controller: _diagController,
          decoration: const InputDecoration(
            labelText: 'التشخيص أو كود ICD-10',
            hintText: 'مثال: F41.1 اضطراب القلق المعمم',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_diagController.text.trim().isNotEmpty) {
                ref.read(clinicalSessionProvider.notifier).addDiagnosis(
                      _diagController.text.trim(),
                    );
                _diagController.clear();
                Navigator.pop(ctx);
              }
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  void _confirmFinalizeSession() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock_clock, color: Colors.indigo),
            SizedBox(width: 8),
            Text('اعتماد وقفل الجلسة السريرية؟'),
          ],
        ),
        content: const Text(
          'تنبيه أمني وإكلينيكي:\n'
          'بمجرد اعتماد الجلسة، سيتم تجميد الملاحظات السريرية بصفتها سجلاً طبياً نهائياً موقعاً باسمك وتاريخ اليوم.\n\n'
          'لا يمكن تعديل النص المعتمد لاحقاً إلا عبر ملحق إلحاقي (Amendment) موثق بالتاريخ والسبب.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('متابعة التحرير كمسودة'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B4F72),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              _syncTypedNotes();
              await ref.read(clinicalSessionProvider.notifier).finalizeSession();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم اعتماد الجلسة السريرية وقفلها بنجاح')),
                );
              }
            },
            child: const Text('تأكيد الاعتماد والقفل'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(clinicalSessionProvider);
    final session = sessionState.currentSession;

    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('جلسة استشارية')),
        body: const Center(child: Text('لم يتم بدء جلسة بعد')),
      );
    }

    final isMobile = MediaQuery.sizeOf(context).width < 680;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: isMobile ? 8 : 16,
        title: Row(
          children: [
            const Icon(Icons.psychology, size: 22),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'جلسة: ${session.patientName}',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 15 : 18),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!isMobile && session.patientMrn != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  session.patientMrn!,
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                ),
              ),
            ],
            SizedBox(width: isMobile ? 6 : 16),

            // Draft vs Finalized Status Pill
            Container(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 10, vertical: 4),
              decoration: BoxDecoration(
                color: session.isFinalized ? Colors.teal.shade700 : Colors.amber.shade800,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    session.isFinalized ? Icons.lock : Icons.edit,
                    size: 12,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isMobile
                        ? (session.isFinalized ? 'معتمدة' : 'مسودة')
                        : (session.isFinalized ? 'معتمدة ومقفلة' : 'مسودة قيد التحرير'),
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Auto-save notification text (desktop/tablet)
          if (!isMobile && sessionState.lastSavedMessage != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (sessionState.isSaving)
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    else
                      const Icon(Icons.check_circle_outline, size: 14, color: Colors.greenAccent),
                    const SizedBox(width: 6),
                    Text(
                      sessionState.lastSavedMessage!,
                      style: const TextStyle(fontSize: 11, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),

          if (!session.isFinalized) ...[
            if (isMobile) ...[
              IconButton(
                icon: const Icon(Icons.save_outlined),
                tooltip: 'حفظ كمسودة',
                onPressed: () {
                  _syncTypedNotes();
                  ref.read(clinicalSessionProvider.notifier).autoSaveDraft();
                },
              ),
              IconButton(
                icon: const Icon(Icons.lock),
                tooltip: 'اعتماد وقفل الجلسة',
                onPressed: _confirmFinalizeSession,
              ),
            ] else ...[
              OutlinedButton.icon(
                icon: const Icon(Icons.save_outlined, size: 18, color: Colors.white),
                label: const Text('حفظ كمسودة', style: TextStyle(color: Colors.white)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white60),
                ),
                onPressed: () {
                  _syncTypedNotes();
                  ref.read(clinicalSessionProvider.notifier).autoSaveDraft();
                },
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.lock, size: 18),
                label: const Text('اعتماد وقفل الجلسة'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade800,
                  foregroundColor: Colors.white,
                ),
                onPressed: _confirmFinalizeSession,
              ),
            ],
          ],
          SizedBox(width: isMobile ? 4 : 12),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: isMobile,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.amber,
          indicatorWeight: 3,
          tabs: [
            Tab(
              icon: const Icon(Icons.edit_note),
              text: isMobile ? 'الملاحظات وفحص الحالة (MSE)' : 'الملاحظات المطبوعة وفحص الحالة (MSE & Typed)',
            ),
            Tab(
              icon: const Icon(Icons.draw),
              text: isMobile ? 'لوحة خط اليد (M-Pencil)' : 'لوحة خط اليد بقلم Huawei M-Pencil',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(), // Don't swipe while writing with stylus
        children: [
          // Tab 1: Typed Notes & Mental Status Exam Workspace
          _buildTypedNotesWorkspace(session),

          // Tab 2: Native Stylus Handwriting Workspace
          _buildHandwritingWorkspace(),
        ],
      ),
    );
  }

  Widget _buildTypedNotesWorkspace(ClinicalSession session) {
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Diagnoses Strip
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.assignment_turned_in, color: Color(0xFF1B4F72)),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'التشخيصات الإكلينيكية للجلسة',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ),
                        ],
                      ),
                      if (!session.isFinalized)
                        OutlinedButton.icon(
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('إضافة تشخيص', style: TextStyle(fontSize: 13)),
                          onPressed: _showAddDiagnosisDialog,
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (session.activeDiagnoses.isEmpty)
                    Text(
                      'لم يتم تسجيل تشخيص في هذه الجلسة بعد',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: session.activeDiagnoses.map((d) {
                        return Chip(
                          label: Text(d),
                          backgroundColor: Colors.teal.shade50,
                          side: BorderSide(color: Colors.teal.shade200),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Chief Complaint
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'الشكوى الرئيسية (Chief Complaint):',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1B4F72)),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _complaintController,
                    maxLines: 2,
                    enabled: !session.isFinalized,
                    decoration: const InputDecoration(
                      hintText: 'دون شكوى المريض بكلماته الخاصة ومبرر الزيارة...',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => _syncTypedNotes(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Biological & Affective Functions (Sleep, Appetite, Mood, Anxiety)
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'الوظائف البيولوجية والوجدانية (Biological & Affective Functions):',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1B4F72)),
                  ),
                  const SizedBox(height: 12),
                  if (isMobile) ...[
                    TextField(
                      controller: _sleepController,
                      enabled: !session.isFinalized,
                      decoration: const InputDecoration(
                        labelText: 'النوم (Sleep)',
                        hintText: 'ساعات النوم، الأرق، الكوابيس',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.bedtime_outlined),
                      ),
                      onChanged: (_) => _syncTypedNotes(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _appetiteController,
                      enabled: !session.isFinalized,
                      decoration: const InputDecoration(
                        labelText: 'الشهية (Appetite)',
                        hintText: 'طبيعية، منخفضة، شراهة',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.restaurant_outlined),
                      ),
                      onChanged: (_) => _syncTypedNotes(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _moodController,
                      enabled: !session.isFinalized,
                      decoration: const InputDecoration(
                        labelText: 'المزاج (Mood)',
                        hintText: 'اكتئابي، قلق، منبسط، متقلب',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.sentiment_neutral_outlined),
                      ),
                      onChanged: (_) => _syncTypedNotes(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _anxietyController,
                      enabled: !session.isFinalized,
                      decoration: const InputDecoration(
                        labelText: 'القلق والتوتر (Anxiety)',
                        hintText: 'توتر عام، نوبات هلع، أفكار ملحة',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.psychology_alt_outlined),
                      ),
                      onChanged: (_) => _syncTypedNotes(),
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _sleepController,
                            enabled: !session.isFinalized,
                            decoration: const InputDecoration(
                              labelText: 'النوم (Sleep)',
                              hintText: 'ساعات النوم، الأرق، الكوابيس',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.bedtime_outlined),
                            ),
                            onChanged: (_) => _syncTypedNotes(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _appetiteController,
                            enabled: !session.isFinalized,
                            decoration: const InputDecoration(
                              labelText: 'الشهية (Appetite)',
                              hintText: 'طبيعية، منخفضة، شراهة',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.restaurant_outlined),
                            ),
                            onChanged: (_) => _syncTypedNotes(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _moodController,
                            enabled: !session.isFinalized,
                            decoration: const InputDecoration(
                              labelText: 'المزاج (Mood)',
                              hintText: 'اكتئابي، قلق، منبسط، متقلب',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.sentiment_neutral_outlined),
                            ),
                            onChanged: (_) => _syncTypedNotes(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _anxietyController,
                            enabled: !session.isFinalized,
                            decoration: const InputDecoration(
                              labelText: 'القلق والتوتر (Anxiety)',
                              hintText: 'توتر عام، نوبات هلع، أفكار ملحة',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.psychology_alt_outlined),
                            ),
                            onChanged: (_) => _syncTypedNotes(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Safety & Risk Assessment (Suicide/Self-Harm & Substance Use)
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'تقييم السلامة والخطورة (Safety & Substance Assessment):',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1B4F72)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _suicideController,
                    enabled: !session.isFinalized,
                    decoration: const InputDecoration(
                      labelText: 'تقييم الانتحار وإيذاء النفس (Suicidal / Self-Harm Assessment)',
                      hintText: 'أفكار انتحارية، خطط، نية، عوامل حماية',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.warning_amber_rounded, color: Colors.amber),
                    ),
                    onChanged: (_) => _syncTypedNotes(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _substanceController,
                    enabled: !session.isFinalized,
                    decoration: const InputDecoration(
                      labelText: 'تعاطي المواد المخدرة والكحوليات (Substance Use)',
                      hintText: 'تدخين، كحول، مهدئات، مخدرات أخرى',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.smoke_free_outlined),
                    ),
                    onChanged: (_) => _syncTypedNotes(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Mental Status Exam (MSE)
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'فحص الحالة العقلية الإكلينيكي (Mental Status Examination - MSE):',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1B4F72)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'المظهر العام، التواصل البصري، النشاط الحركي، المزاج والوجدان، مجرى ومحتوى التفكير، الإدراك الحسي، والاستبصار.',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _mseController,
                    maxLines: 4,
                    enabled: !session.isFinalized,
                    decoration: const InputDecoration(
                      hintText: 'سجل نتائج فحص الحالة العقلية بتفصيل...',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => _syncTypedNotes(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Assessment and Treatment Plan & Follow-up
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'الخطة العلاجية والمتابعة (Treatment Plan & Follow-Up):',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1B4F72)),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _planController,
                    maxLines: 3,
                    enabled: !session.isFinalized,
                    decoration: const InputDecoration(
                      labelText: 'الخطة العلاجية الدوائية والسلوكية',
                      hintText: 'الأهداف العلاجية، الواجبات المنزلية، التدخلات السلوكية...',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => _syncTypedNotes(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _followUpController,
                    enabled: !session.isFinalized,
                    decoration: const InputDecoration(
                      labelText: 'توصيات وموعد المتابعة القادمة (Follow-Up)',
                      hintText: 'مثال: المتابعة بعد أسبوعين لمراجعة الجرعة وتأثير الدواء',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.event_repeat),
                    ),
                    onChanged: (_) => _syncTypedNotes(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Prescriptions List Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.medication_liquid, color: Color(0xFF1B4F72)),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'الوصفة الدوائية (الروشتة)',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ),
                        ],
                      ),
                      if (!session.isFinalized)
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('إضافة دواء للروشتة', style: TextStyle(fontSize: 13)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1B4F72),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _showAddPrescriptionDialog,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (session.prescriptions.isEmpty)
                    Text(
                      'لا توجد أدوية مقررة في هذه الجلسة',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: session.prescriptions.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (ctx, idx) {
                        final p = session.prescriptions[idx];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: Colors.teal.shade50,
                            child: Icon(Icons.medication, color: Colors.teal.shade800),
                          ),
                          title: Text(
                            p.medicationName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            [
                              if (p.dose.isNotEmpty) 'الجرعة: ${p.dose}',
                              if (p.frequency.isNotEmpty) 'التكرار: ${p.frequency}',
                              if (p.instructions != null && p.instructions!.isNotEmpty)
                                'التعليمات: ${p.instructions}',
                            ].join(' | '),
                          ),
                          trailing: session.isFinalized
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  onPressed: () {
                                    ref
                                        .read(clinicalSessionProvider.notifier)
                                        .removePrescription(idx);
                                  },
                                ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHandwritingWorkspace() {
    return Stack(
      children: [
        // Full Ink Canvas
        const Positioned.fill(
          child: InkCanvas(
            backgroundColor: Color(0xFFF9F7F2), // PaperMatte background feel
          ),
        ),

        // Vertical Floating Toolbar for Huawei M-Pencil
        Positioned(
          top: 16,
          right: 16,
          bottom: 16,
          child: ToolBar(
            onSave: () async {
              final strokes = ref.read(canvasProvider).strokes;
              final jsonStr = StrokeSerializer.strokesToJson(strokes);
              ref.read(clinicalSessionProvider.notifier).setHandwritingInk(jsonStr);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم حفظ خطوط الملاحظات اليدوية في سجل الجلسة')),
                );
              }
            },
            onLoad: () async {
              final saved = await StrokeSerializer.loadStrokes();
              if (saved != null) {
                ref.read(canvasProvider.notifier).loadStrokes(saved);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم استرجاع الملاحظات اليدوية السابقة')),
                  );
                }
              }
            },
          ),
        ),
      ],
    );
  }
}
