import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/patient_model.dart';
import '../providers/patient_provider.dart';
import '../../clinical/providers/clinical_provider.dart';
import '../../clinical/screens/session_workspace_screen.dart';

class PatientDetailScreen extends ConsumerWidget {
  final String patientId;

  const PatientDetailScreen({super.key, required this.patientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(patientProvider);
    final theme = Theme.of(context);
    final patient = state.selectedPatient;

    if (state.isLoading && patient == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (patient == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('الملف الطبي للمريض')),
        body: const Center(child: Text('لم يتم العثور على بيانات المريض')),
      );
    }

    final isMobile = MediaQuery.sizeOf(context).width < 700;

    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'الملف الطبي — ${patient.nameAr}',
            style: TextStyle(fontSize: isMobile ? 16 : 18, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'تعديل البيانات الشخصية',
              onPressed: () => _showEditDemographicsDialog(context, ref, patient),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.amber,
            indicatorWeight: 3,
            tabs: [
              Tab(icon: Icon(Icons.psychology_outlined), text: 'التاريخ والفحوصات النفسية'),
              Tab(icon: Icon(Icons.assignment_outlined), text: 'التشخيصات المسجلة'),
              Tab(icon: Icon(Icons.medication_outlined), text: 'الخطة الدوائية'),
              Tab(icon: Icon(Icons.history_edu_outlined), text: 'سجل الجلسات السابقة'),
              Tab(icon: Icon(Icons.folder_shared_outlined), text: 'الملفات والتقارير'),
              Tab(icon: Icon(Icons.note_alt_outlined), text: 'ملاحظات الطبيب السريعة'),
            ],
          ),
        ),
        body: Column(
          children: [
            // Patient Header Info Strip
            Container(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: isMobile ? 22 : 30,
                        backgroundColor: theme.primaryColor.withAlpha(25),
                        child: Icon(Icons.person, size: isMobile ? 26 : 38, color: theme.primaryColor),
                      ),
                      SizedBox(width: isMobile ? 10 : 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  patient.nameAr,
                                  style: TextStyle(fontSize: isMobile ? 16 : 20, fontWeight: FontWeight.bold),
                                ),
                                if (patient.nameEn != null && patient.nameEn!.isNotEmpty)
                                  Text(
                                    '(${patient.nameEn})',
                                    style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic, fontSize: 12),
                                  ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blueGrey.shade100,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    patient.mrn,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blueGrey.shade900,
                                    ),
                                  ),
                                ),
                                if (patient.sex != null)
                                  Text(
                                    '• ${patient.sex == 'male' ? 'ذكر' : 'أنثى'}',
                                    style: TextStyle(color: Colors.grey[700], fontSize: 13),
                                  ),
                                if (patient.age != null)
                                  Text(
                                    '• ${patient.age} سنة',
                                    style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1B4F72), fontSize: 13),
                                  ),
                                if (patient.maritalStatus != null && patient.maritalStatus!.isNotEmpty)
                                  Text(
                                    '• ${patient.maritalStatus}',
                                    style: TextStyle(color: Colors.grey[700], fontSize: 13),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 14,
                              runSpacing: 4,
                              children: [
                                if (patient.phone != null && patient.phone!.isNotEmpty)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.phone, size: 14, color: Colors.grey[600]),
                                      const SizedBox(width: 4),
                                      Text(patient.phone!, style: TextStyle(color: Colors.grey[700], fontSize: 12.5)),
                                    ],
                                  ),
                                if (patient.occupation != null && patient.occupation!.isNotEmpty)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.work_outline, size: 14, color: Colors.grey[600]),
                                      const SizedBox(width: 4),
                                      Text(patient.occupation!, style: TextStyle(color: Colors.grey[700], fontSize: 12.5)),
                                    ],
                                  ),
                                if (patient.children != null && patient.children!.isNotEmpty)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.child_care_outlined, size: 14, color: Colors.grey[600]),
                                      const SizedBox(width: 4),
                                      Text('الأبناء: ${patient.children}', style: TextStyle(color: Colors.grey[700], fontSize: 12.5)),
                                    ],
                                  ),
                                if (patient.address != null && patient.address!.isNotEmpty)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.location_on_outlined, size: 14, color: Colors.grey[600]),
                                      const SizedBox(width: 4),
                                      Text(patient.address!, style: TextStyle(color: Colors.grey[700], fontSize: 12.5)),
                                    ],
                                  ),
                                if (patient.firstSessionDate != null)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.event_available, size: 14, color: Colors.teal.shade700),
                                      const SizedBox(width: 4),
                                      Text('أول جلسة: ${DateFormat('yyyy/MM/dd').format(patient.firstSessionDate!)}',
                                          style: TextStyle(color: Colors.teal.shade800, fontSize: 12, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (!isMobile) ...[
                        if (patient.allergies.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade300),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 20),
                                const SizedBox(width: 6),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'حساسية دوائية مسجلة:',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red.shade900),
                                    ),
                                    Text(
                                      patient.allergies.join('، '),
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.red.shade800),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        OutlinedButton.icon(
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text('تعديل البيانات'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          ),
                          onPressed: () => _showEditDemographicsDialog(context, ref, patient),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.edit_note),
                          label: const Text('بدء جلسة جديدة'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          ),
                          onPressed: () {
                            ref.read(clinicalSessionProvider.notifier).startNewSession(
                                  patientId: patient.patientId,
                                  patientName: patient.nameAr,
                                  patientMrn: patient.mrn,
                                );
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const SessionWorkspaceScreen()),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                  if (isMobile) ...[
                    if (patient.allergies.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 18),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'حساسية دوائية: ${patient.allergies.join('، ')}',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red.shade900),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.edit, size: 16),
                            label: const Text('تعديل البيانات', style: TextStyle(fontSize: 12.5)),
                            onPressed: () => _showEditDemographicsDialog(context, ref, patient),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.edit_note, size: 18),
                            label: const Text('بدء جلسة جديدة', style: TextStyle(fontSize: 12.5)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.primaryColor,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () {
                              ref.read(clinicalSessionProvider.notifier).startNewSession(
                                    patientId: patient.patientId,
                                    patientName: patient.nameAr,
                                    patientMrn: patient.mrn,
                                  );
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const SessionWorkspaceScreen()),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),

            // Tab Views
            Expanded(
              child: TabBarView(
                children: [
                  _buildHistoryTab(context, ref, patient),
                  _buildDiagnosesTab(context, ref, patient),
                  _buildMedicationsTab(context, ref, patient),
                  _buildSessionHistoryTab(patient),
                  _buildFilesTab(context, ref, patient),
                  _buildQuickNotesTab(context, ref, patient),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 1: Psychiatric History & Examinations
  // ==========================================

  Widget _buildHistoryTab(BuildContext context, WidgetRef ref, PatientModel patient) {
    final isMobile = MediaQuery.sizeOf(context).width < 640;
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              const Text(
                'الملف والفحص الإكلينيكي النفسي الكامل',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.edit_note, size: 18),
                label: const Text('تعديل التاريخ السريري', style: TextStyle(fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B4F72),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                onPressed: () => _showEditClinicalHistoryDialog(context, ref, patient),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildClinicalSectionCard(
            title: 'التاريخ المرضي والنفسي الكامل (History)',
            icon: Icons.history_edu,
            content: patient.history ?? patient.psychiatricHistory ?? 'لا يوجد تاريخ نفسي مدون سابقاً.',
          ),
          const SizedBox(height: 14),
          _buildClinicalSectionCard(
            title: 'الفحوصات والتقييمات النفسية (Psychiatric Examinations)',
            icon: Icons.psychology,
            content: patient.psychiatricExaminations ?? 'لا توجد فحوصات نفسية سابقة مسجلة.',
          ),
          const SizedBox(height: 14),
          _buildClinicalSectionCard(
            title: 'الفحص الجسدي والعصبي (Physical & Neurological Exam)',
            icon: Icons.health_and_safety_outlined,
            content: patient.physicalNeurologicalExam ?? 'لا توجد ملاحظات على الفحص الجسدي أو العصبي.',
          ),
          const SizedBox(height: 14),
          _buildClinicalSectionCard(
            title: 'تقييم الخطورة (Risk Assessment)',
            icon: Icons.shield_outlined,
            content: patient.riskAssessment ?? 'تم تقييم الخطورة: منخفضة / مستقرة.',
            isAlert: patient.riskAssessment != null && patient.riskAssessment!.toLowerCase().contains('high'),
          ),
          const SizedBox(height: 14),
          if (isMobile) ...[
            _buildClinicalSectionCard(
              title: 'محاولات الانتحار السابقة (Suicide Attempts)',
              icon: Icons.emergency_outlined,
              content: patient.suicideAttempts ?? 'لا توجد محاولات مسجلة.',
              isAlert: patient.suicideAttempts != null &&
                  patient.suicideAttempts!.isNotEmpty &&
                  !patient.suicideAttempts!.contains('لا'),
            ),
            const SizedBox(height: 14),
            _buildClinicalSectionCard(
              title: 'الحجز والدخول السابق (Admitted Before)',
              icon: Icons.local_hospital_outlined,
              content: patient.admittedBefore ?? 'لا يوجد دخول سابق لمستشفيات.',
            ),
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildClinicalSectionCard(
                    title: 'محاولات الانتحار السابقة (Suicide Attempts)',
                    icon: Icons.emergency_outlined,
                    content: patient.suicideAttempts ?? 'لا توجد محاولات مسجلة.',
                    isAlert: patient.suicideAttempts != null &&
                        patient.suicideAttempts!.isNotEmpty &&
                        !patient.suicideAttempts!.contains('لا'),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildClinicalSectionCard(
                    title: 'الحجز والدخول السابق (Admitted Before)',
                    icon: Icons.local_hospital_outlined,
                    content: patient.admittedBefore ?? 'لا يوجد دخول سابق لمستشفيات.',
                  ),
                ),
              ],
            ),
          const SizedBox(height: 14),
          _buildClinicalSectionCard(
            title: 'التاريخ الطبي والجراحي (Medical & Surgical History)',
            icon: Icons.medical_services_outlined,
            content: patient.medicalHistory ?? 'لا توجد أمراض طبية مزمنة أو جراحات مسجلة.',
          ),
          const SizedBox(height: 14),
          _buildClinicalSectionCard(
            title: 'التاريخ العائلي لاضطرابات نفسية (Family History)',
            icon: Icons.family_restroom,
            content: patient.familyHistory ?? 'لا يوجد تاريخ عائلي لاضطرابات نفسية.',
          ),
          const SizedBox(height: 14),
          _buildClinicalSectionCard(
            title: 'التاريخ الاجتماعي ونمط الحياة (Social History)',
            icon: Icons.people_outline,
            content: patient.socialHistory ?? 'لا توجد ملاحظات اجتماعية مسجلة.',
          ),
          const SizedBox(height: 14),
          _buildClinicalSectionCard(
            title: 'الحساسية الدوائية (Drug Allergies)',
            icon: Icons.warning_amber_rounded,
            content: patient.allergies.isEmpty ? 'لا توجد حساسية دوائية مسجلة.' : patient.allergies.join('، '),
            isAlert: patient.allergies.isNotEmpty,
          ),
          if (patient.notes != null && patient.notes!.isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildClinicalSectionCard(
              title: 'ملاحظات الطبيب العامة حول المريض (Notes)',
              icon: Icons.sticky_note_2_outlined,
              content: patient.notes!,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildClinicalSectionCard({
    required String title,
    required IconData icon,
    required String content,
    bool isAlert = false,
  }) {
    return Card(
      elevation: 1,
      color: isAlert ? Colors.red.shade50 : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: isAlert ? BorderSide(color: Colors.red.shade200) : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 20, color: isAlert ? Colors.red.shade700 : const Color(0xFF1B4F72)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14.5,
                      color: isAlert ? Colors.red.shade900 : const Color(0xFF1B4F72),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              content,
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: isAlert ? Colors.red.shade900 : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 2: Diagnoses
  // ==========================================

  Widget _buildDiagnosesTab(BuildContext context, WidgetRef ref, PatientModel patient) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          color: Colors.grey.shade50,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'التشخيصات المسجلة (${patient.diagnoses.length})',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('إضافة تشخيص', style: TextStyle(fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onPressed: () => _showAddDiagnosisDialog(context, ref, patient),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: patient.diagnoses.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.assignment_outlined, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text('لا توجد تشخيصات مسجلة للمريض حتى الآن'),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('إضافة أول تشخيص'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700, foregroundColor: Colors.white),
                        onPressed: () => _showAddDiagnosisDialog(context, ref, patient),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: patient.diagnoses.length,
                  itemBuilder: (ctx, idx) {
                    final d = patient.diagnoses[idx];
                    return Card(
                      elevation: 1.5,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.teal.shade50,
                          child: Icon(Icons.assignment_turned_in, color: Colors.teal.shade800),
                        ),
                        title: Text(
                          d.descriptionAr,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          [
                            if (d.icd10Code != null) 'رمز ICD-10: ${d.icd10Code}',
                            if (d.descriptionEn != null) d.descriptionEn!,
                            'تاريخ التشخيص: ${DateFormat('yyyy/MM/dd').format(d.dateDiagnosed)}',
                          ].join(' | '),
                        ),
                        trailing: Chip(
                          label: Text(
                            d.status == 'active'
                                ? 'نشط'
                                : d.status == 'resolved'
                                    ? 'تم الشفاء'
                                    : 'في حالة هدوء',
                          ),
                          backgroundColor: d.status == 'active'
                              ? Colors.green.shade100
                              : d.status == 'resolved'
                                  ? Colors.blue.shade100
                                  : Colors.grey.shade200,
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ==========================================
  // TAB 3: Medications
  // ==========================================

  Widget _buildMedicationsTab(BuildContext context, WidgetRef ref, PatientModel patient) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          color: Colors.grey.shade50,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'الخطة الدوائية الحالية (${patient.medications.length})',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('إضافة دواء', style: TextStyle(fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onPressed: () => _showAddMedicationDialog(context, ref, patient),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: patient.medications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.medication_outlined, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text('لا توجد أدوية مسجلة في خطة المريض العلاجية'),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('إضافة دواء جديد'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo.shade700, foregroundColor: Colors.white),
                        onPressed: () => _showAddMedicationDialog(context, ref, patient),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: patient.medications.length,
                  itemBuilder: (ctx, idx) {
                    final m = patient.medications[idx];
                    return Card(
                      elevation: 1.5,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Text(
                                  m.nameAr,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                if (m.nameEn != null)
                                  Text(
                                    m.nameEn!,
                                    style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                if (m.dose != null) Chip(label: Text('الجرعة: ${m.dose}')),
                                if (m.frequency != null) Chip(label: Text('التكرار: ${m.frequency}')),
                                if (m.duration != null) Chip(label: Text('المدة: ${m.duration}')),
                                if (m.date != null) Chip(label: Text('التاريخ: ${DateFormat('yyyy/MM/dd').format(m.date!)}')),
                                if (m.route != null) Chip(label: Text('طريقة الاستخدام: ${m.route}')),
                              ],
                            ),
                            if (m.notes != null && m.notes!.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                'تعليمات وإرشادات: ${m.notes}',
                                style: TextStyle(color: Colors.grey[700], fontSize: 13),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ==========================================
  // TAB 4: Session History
  // ==========================================

  Widget _buildSessionHistoryTab(PatientModel patient) {
    if (patient.sessionHistory.isEmpty) {
      return const Center(child: Text('لا توجد جلسات سابقة مسجلة'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: patient.sessionHistory.length,
      itemBuilder: (ctx, idx) {
        final s = patient.sessionHistory[idx];
        return Card(
          elevation: 1.5,
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      'جلسة ${s.sessionNumber ?? '#${idx + 1}'}: ${DateFormat('yyyy/MM/dd — hh:mm a', 'ar').format(s.startedAt)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                    ),
                    Chip(
                      label: Text(s.status == 'finalized' ? 'معتمدة نهائياً' : 'مسودة', style: const TextStyle(fontSize: 12)),
                      backgroundColor: s.status == 'finalized' ? Colors.blue.shade50 : Colors.amber.shade50,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                if (s.chiefComplaint != null && s.chiefComplaint!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('الشكوى: ${s.chiefComplaint!}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ],
                if (s.mood != null && s.mood!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('المزاج: ${s.mood!}', style: TextStyle(fontSize: 13, color: Colors.blueGrey.shade800)),
                ],
                if (s.treatmentPlan != null && s.treatmentPlan!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('الخطة العلاجية: ${s.treatmentPlan!}', style: TextStyle(fontSize: 13, color: Colors.teal.shade900)),
                ],
                if (s.noteSnippet != null && s.noteSnippet!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    s.noteSnippet!,
                    style: const TextStyle(fontSize: 13, height: 1.5),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // ==========================================
  // TAB 5: Files & Scans
  // ==========================================

  Widget _buildFilesTab(BuildContext context, WidgetRef ref, PatientModel patient) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          color: Colors.grey.shade50,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'الملفات والتقارير المرفقة (${patient.files.length})',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.upload_file, size: 18),
                label: const Text('إرفاق ملف', style: TextStyle(fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey.shade800,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onPressed: () => _showAddFileDialog(context, ref, patient),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: patient.files.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.folder_open, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text('لا توجد ملفات أو تقارير مرفقة لهذا المريض'),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.upload_file),
                        label: const Text('إرفاق تقرير طبي أو تحليل'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey.shade800, foregroundColor: Colors.white),
                        onPressed: () => _showAddFileDialog(context, ref, patient),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: patient.files.length,
                  itemBuilder: (ctx, idx) {
                    final f = patient.files[idx];
                    return Card(
                      elevation: 1.5,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blueGrey.shade50,
                          child: Icon(
                            f.fileType.contains('pdf')
                                ? Icons.picture_as_pdf
                                : f.fileType.contains('image')
                                    ? Icons.image
                                    : Icons.insert_drive_file,
                            color: Colors.blueGrey.shade800,
                          ),
                        ),
                        title: Text(f.fileName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          'نوع الملف: ${f.fileType} | تاريخ الرفع: ${DateFormat('yyyy/MM/dd').format(f.createdAt)}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.download_outlined),
                          tooltip: 'فتح / تحميل الملف',
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('مسار الملف: ${f.fileLocation}')),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ==========================================
  // TAB 6: Quick Doctor Notes
  // ==========================================

  Widget _buildQuickNotesTab(BuildContext context, WidgetRef ref, PatientModel patient) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          color: Colors.grey.shade50,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'ملاحظات الطبيب السريعة (${patient.quickNotes.length})',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.note_add, size: 18),
                label: const Text('إضافة ملاحظة', style: TextStyle(fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B4F72),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onPressed: () => _showAddNoteDialog(context, ref, patient),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: patient.quickNotes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_note, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text('لا توجد ملاحظات سريعة مدونة'),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.note_add),
                        label: const Text('إضافة أول ملاحظة سريعة'),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B4F72), foregroundColor: Colors.white),
                        onPressed: () => _showAddNoteDialog(context, ref, patient),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: patient.quickNotes.length,
                  itemBuilder: (ctx, idx) {
                    final n = patient.quickNotes[idx];
                    return Card(
                      elevation: 1.5,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.access_time, size: 14, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(
                                      'تاريخ التعديل: ${DateFormat('yyyy/MM/dd — hh:mm a', 'ar').format(n.lastModified)}',
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                    ),
                                  ],
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                  tooltip: 'حذف الملاحظة',
                                  onPressed: () async {
                                    final ok = await ref.read(patientProvider.notifier).deletePatientNote(patient.patientId, n.noteId);
                                    if (context.mounted && ok) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('تم حذف الملاحظة بنجاح')),
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              n.noteText,
                              style: const TextStyle(fontSize: 14, height: 1.5),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ==========================================
  // DIALOGS
  // ==========================================

  void _showEditDemographicsDialog(BuildContext context, WidgetRef ref, PatientModel patient) {
    final formKey = GlobalKey<FormState>();
    final nameArCtrl = TextEditingController(text: patient.nameAr);
    final nameEnCtrl = TextEditingController(text: patient.nameEn ?? '');
    final phoneCtrl = TextEditingController(text: patient.phone ?? '');
    final emailCtrl = TextEditingController(text: patient.email ?? '');
    final nationalIdCtrl = TextEditingController(text: patient.nationalId ?? '');
    final occupationCtrl = TextEditingController(text: patient.occupation ?? '');
    final maritalStatusCtrl = TextEditingController(text: patient.maritalStatus ?? '');
    final childrenCtrl = TextEditingController(text: patient.children ?? '');
    final addressCtrl = TextEditingController(text: patient.address ?? '');
    String? selectedSex = patient.sex;
    DateTime? selectedDob = patient.dob;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.person_outline, color: Color(0xFF1B4F72)),
              SizedBox(width: 8),
              Text('تعديل البيانات الشخصية والاجتماعية'),
            ],
          ),
          content: SizedBox(
            width: 580,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameArCtrl,
                      decoration: const InputDecoration(labelText: 'الاسم الكامل بالعربية *', prefixIcon: Icon(Icons.badge_outlined)),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'الاسم بالعربية مطلوب' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: nameEnCtrl,
                      decoration: const InputDecoration(labelText: 'الاسم بالإنجليزية (اختياري)', prefixIcon: Icon(Icons.badge_outlined)),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: phoneCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(labelText: 'رقم الهاتف', prefixIcon: Icon(Icons.phone_outlined)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(labelText: 'البريد الإلكتروني', prefixIcon: Icon(Icons.email_outlined)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: nationalIdCtrl,
                            decoration: const InputDecoration(labelText: 'الرقم القومي (14 رقم)', prefixIcon: Icon(Icons.credit_card)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedSex,
                            decoration: const InputDecoration(labelText: 'النوع', prefixIcon: Icon(Icons.wc)),
                            items: const [
                              DropdownMenuItem(value: 'male', child: Text('ذكر')),
                              DropdownMenuItem(value: 'female', child: Text('أنثى')),
                              DropdownMenuItem(value: 'other', child: Text('آخر')),
                            ],
                            onChanged: (val) => setState(() => selectedSex = val),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: occupationCtrl,
                            decoration: const InputDecoration(labelText: 'المهنة / العمل (Occupation)', prefixIcon: Icon(Icons.work_outline)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: maritalStatusCtrl,
                            decoration: const InputDecoration(labelText: 'الحالة الاجتماعية (أعزب، متزوج..)', prefixIcon: Icon(Icons.favorite_border)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: childrenCtrl,
                            decoration: const InputDecoration(labelText: 'الأبناء (عدد وأعمار)', prefixIcon: Icon(Icons.child_care)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(color: Colors.grey.shade400),
                            ),
                            leading: const Icon(Icons.calendar_today_outlined),
                            title: Text(
                              selectedDob != null
                                  ? 'تاريخ الميلاد: ${DateFormat('yyyy/MM/dd').format(selectedDob!)}'
                                  : 'تحديد تاريخ الميلاد',
                              style: TextStyle(color: selectedDob != null ? Colors.black87 : Colors.grey.shade600, fontSize: 13),
                            ),
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: selectedDob ?? DateTime(1995, 1, 1),
                                firstDate: DateTime(1920),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) {
                                setState(() => selectedDob = picked);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: addressCtrl,
                      decoration: const InputDecoration(labelText: 'العنوان ومحل الإقامة', prefixIcon: Icon(Icons.home_outlined)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B4F72),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(ctx);

                final body = <String, dynamic>{
                  'name_ar': nameArCtrl.text.trim(),
                  if (nameEnCtrl.text.trim().isNotEmpty) 'name_en': nameEnCtrl.text.trim(),
                  if (phoneCtrl.text.trim().isNotEmpty) 'phone': phoneCtrl.text.trim(),
                  if (emailCtrl.text.trim().isNotEmpty) 'email': emailCtrl.text.trim(),
                  if (nationalIdCtrl.text.trim().isNotEmpty) 'national_id': nationalIdCtrl.text.trim(),
                  if (occupationCtrl.text.trim().isNotEmpty) 'occupation': occupationCtrl.text.trim(),
                  if (maritalStatusCtrl.text.trim().isNotEmpty) 'marital_status': maritalStatusCtrl.text.trim(),
                  if (childrenCtrl.text.trim().isNotEmpty) 'children': childrenCtrl.text.trim(),
                  if (addressCtrl.text.trim().isNotEmpty) 'address': addressCtrl.text.trim(),
                  if (selectedSex != null) 'sex': selectedSex,
                  if (selectedDob != null) 'dob': selectedDob!.toIso8601String().substring(0, 10),
                };

                final ok = await ref.read(patientProvider.notifier).updatePatientInfo(patient.patientId, body);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(ok ? 'تم تحديث البيانات بنجاح' : 'تعذر حفظ البيانات'),
                      backgroundColor: ok ? Colors.green.shade700 : Colors.red.shade700,
                    ),
                  );
                }
              },
              child: const Text('حفظ التعديلات'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditClinicalHistoryDialog(BuildContext context, WidgetRef ref, PatientModel patient) {
    final formKey = GlobalKey<FormState>();
    final historyCtrl = TextEditingController(text: patient.history ?? patient.psychiatricHistory ?? '');
    final psychExamCtrl = TextEditingController(text: patient.psychiatricExaminations ?? '');
    final physicalExamCtrl = TextEditingController(text: patient.physicalNeurologicalExam ?? '');
    final riskCtrl = TextEditingController(text: patient.riskAssessment ?? '');
    final suicideCtrl = TextEditingController(text: patient.suicideAttempts ?? '');
    final admittedCtrl = TextEditingController(text: patient.admittedBefore ?? '');
    final medCtrl = TextEditingController(text: patient.medicalHistory ?? '');
    final famCtrl = TextEditingController(text: patient.familyHistory ?? '');
    final socCtrl = TextEditingController(text: patient.socialHistory ?? '');
    final notesCtrl = TextEditingController(text: patient.notes ?? '');
    final allergiesCtrl = TextEditingController(text: patient.allergies.join('، '));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.psychology, color: Color(0xFF1B4F72)),
            SizedBox(width: 8),
            Text('تعديل الملف السريري والفحص النفسي الشامل'),
          ],
        ),
        content: SizedBox(
          width: 650,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ملاحظة: جميع هذه البيانات مشفرة وتخضع لسرية الطبيب النفسي التامة.',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: historyCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'التاريخ المرضي والنفسي الكامل (History)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: psychExamCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'الفحوصات والتقييمات النفسية (Psychiatric Examinations)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: physicalExamCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'الفحص الجسدي والعصبي (Physical & Neurological Exam)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: riskCtrl,
                          decoration: const InputDecoration(
                            labelText: 'تقييم الخطورة (Risk Assessment)',
                            hintText: 'منخفضة / متوسطة / مرتفعة',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: suicideCtrl,
                          decoration: const InputDecoration(
                            labelText: 'محاولات الانتحار (Suicide Attempts)',
                            hintText: 'نعم / لا والتفاصيل',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: admittedCtrl,
                    decoration: const InputDecoration(
                      labelText: 'الحجز والدخول السابق لمستشفيات (Admitted Before)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: medCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'التاريخ الطبي والجراحي (Medical & Surgical History)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: famCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'التاريخ العائلي (Family History)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: socCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'التاريخ الاجتماعي ونمط الحياة (Social History)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: allergiesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'الحساسية الدوائية (افصل بين الأدوية بفاصلة)',
                      hintText: 'مثال: البنسلين، سالفا، أسبرين',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.warning_amber_rounded, color: Colors.red),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: notesCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظات الطبيب العامة (Doctor Notes)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B4F72),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);

              final rawAllergies = allergiesCtrl.text
                  .split(RegExp(r'[,،]'))
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList();

              final ok = await ref.read(patientProvider.notifier).updateClinicalHistory(
                    patient.patientId,
                    history: historyCtrl.text.trim(),
                    psychiatricHistory: historyCtrl.text.trim(),
                    psychiatricExaminations: psychExamCtrl.text.trim(),
                    physicalNeurologicalExam: physicalExamCtrl.text.trim(),
                    riskAssessment: riskCtrl.text.trim(),
                    suicideAttempts: suicideCtrl.text.trim(),
                    admittedBefore: admittedCtrl.text.trim(),
                    medicalHistory: medCtrl.text.trim(),
                    familyHistory: famCtrl.text.trim(),
                    socialHistory: socCtrl.text.trim(),
                    notes: notesCtrl.text.trim(),
                    allergies: rawAllergies,
                  );

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok ? 'تم حفظ التعديلات السريرية بنجاح' : 'تعذر حفظ التاريخ السريري'),
                    backgroundColor: ok ? Colors.green.shade700 : Colors.red.shade700,
                  ),
                );
              }
            },
            child: const Text('حفظ التعديلات السريرية'),
          ),
        ],
      ),
    );
  }

  void _showAddDiagnosisDialog(BuildContext context, WidgetRef ref, PatientModel patient) {
    final formKey = GlobalKey<FormState>();
    final descArCtrl = TextEditingController();
    final descEnCtrl = TextEditingController();
    final icdCtrl = TextEditingController();
    String status = 'active';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.assignment_turned_in, color: Colors.teal),
              SizedBox(width: 8),
              Text('إضافة تشخيص جديد للمريض'),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: descArCtrl,
                      decoration: const InputDecoration(
                        labelText: 'وصف التشخيص بالعربية *',
                        hintText: 'مثال: اضطراب الهلع، اكتئاب جسيم، إلخ',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'وصف التشخيص مطلوب' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descEnCtrl,
                      decoration: const InputDecoration(
                        labelText: 'التشخيص بالإنجليزية (اختياري)',
                        hintText: 'e.g. Panic Disorder without Agoraphobia',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: icdCtrl,
                      decoration: const InputDecoration(
                        labelText: 'رمز التصنيف الدولي (ICD-10)',
                        hintText: 'e.g. F41.0, F32.1',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: status,
                      decoration: const InputDecoration(labelText: 'حالة التشخيص الحالية'),
                      items: const [
                        DropdownMenuItem(value: 'active', child: Text('نشط (Active)')),
                        DropdownMenuItem(value: 'in_remission', child: Text('في حالة هدوء (In Remission)')),
                        DropdownMenuItem(value: 'resolved', child: Text('تم الشفاء (Resolved)')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => status = val);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700, foregroundColor: Colors.white),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(ctx);

                final ok = await ref.read(patientProvider.notifier).addDiagnosis(
                      patient.patientId,
                      descriptionAr: descArCtrl.text.trim(),
                      descriptionEn: descEnCtrl.text.trim().isNotEmpty ? descEnCtrl.text.trim() : null,
                      icd10Code: icdCtrl.text.trim().isNotEmpty ? icdCtrl.text.trim() : null,
                      status: status,
                    );

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(ok ? 'تم إضافة التشخيص بنجاح' : 'تعذر إضافة التشخيص'),
                      backgroundColor: ok ? Colors.green.shade700 : Colors.red.shade700,
                    ),
                  );
                }
              },
              child: const Text('إضافة التشخيص'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddMedicationDialog(BuildContext context, WidgetRef ref, PatientModel patient) {
    final formKey = GlobalKey<FormState>();
    final nameArCtrl = TextEditingController();
    final nameEnCtrl = TextEditingController();
    final doseCtrl = TextEditingController();
    final freqCtrl = TextEditingController();
    final durationCtrl = TextEditingController(text: '3 أشهر');
    final routeCtrl = TextEditingController(text: 'فموي');
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.medication, color: Colors.indigo),
            SizedBox(width: 8),
            Text('إضافة دواء جديد للخطة العلاجية'),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameArCtrl,
                    decoration: const InputDecoration(
                      labelText: 'اسم الدواء التجاري أو العلمي بالعربية (Drug) *',
                      hintText: 'مثال: سيرترالين (لوسترال)',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'اسم الدواء بالعربية مطلوب' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: nameEnCtrl,
                    decoration: const InputDecoration(
                      labelText: 'الاسم العلمي بالإنجليزية',
                      hintText: 'e.g. Sertraline HCl',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: doseCtrl,
                          decoration: const InputDecoration(
                            labelText: 'الجرعة (Dose)',
                            hintText: 'مثال: 50 mg',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: durationCtrl,
                          decoration: const InputDecoration(
                            labelText: 'مدة العلاج (Duration)',
                            hintText: 'مثال: 6 أسابيع',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: freqCtrl,
                          decoration: const InputDecoration(
                            labelText: 'التكرار',
                            hintText: 'مثال: مرة يومياً مساءً',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: routeCtrl,
                          decoration: const InputDecoration(
                            labelText: 'طريقة التناول (Route)',
                            hintText: 'مثال: فموي',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: notesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظات وإرشادات للمريض (Notes)',
                      hintText: 'مثال: البدء بنصف قرص لمدة 4 أيام لتجنب الغثيان',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo.shade700, foregroundColor: Colors.white),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(ctx);

              final ok = await ref.read(patientProvider.notifier).addMedication(
                    patient.patientId,
                    nameAr: nameArCtrl.text.trim(),
                    nameEn: nameEnCtrl.text.trim().isNotEmpty ? nameEnCtrl.text.trim() : null,
                    dose: doseCtrl.text.trim().isNotEmpty ? doseCtrl.text.trim() : null,
                    frequency: freqCtrl.text.trim().isNotEmpty ? freqCtrl.text.trim() : null,
                    duration: durationCtrl.text.trim().isNotEmpty ? durationCtrl.text.trim() : null,
                    route: routeCtrl.text.trim().isNotEmpty ? routeCtrl.text.trim() : null,
                    notes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
                  );

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok ? 'تم إضافة الدواء للخطة العلاجية بنجاح' : 'تعذر إضافة الدواء'),
                    backgroundColor: ok ? Colors.green.shade700 : Colors.red.shade700,
                  ),
                );
              }
            },
            child: const Text('إضافة الدواء'),
          ),
        ],
      ),
    );
  }

  void _showAddFileDialog(BuildContext context, WidgetRef ref, PatientModel patient) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    String fileType = 'تقرير طبي (Medical Report)';
    final locationCtrl = TextEditingController(text: '/uploads/reports/');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.upload_file, color: Colors.blueGrey),
              SizedBox(width: 8),
              Text('إرفاق ملف أو فحص للمريض'),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'اسم الملف أو التقرير *', hintText: 'مثال: تقرير رسم مخ EEG، تحاليل الغدة'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'اسم الملف مطلوب' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: fileType,
                    decoration: const InputDecoration(labelText: 'نوع الملف (File Type)'),
                    items: const [
                      DropdownMenuItem(value: 'تقرير طبي (Medical Report)', child: Text('تقرير طبي (Medical Report)')),
                      DropdownMenuItem(value: 'تحاليل مخبرية (Lab Results)', child: Text('تحاليل مخبرية (Lab Results)')),
                      DropdownMenuItem(value: 'أشعة أو فحص مخ (EEG / Brain Scan)', child: Text('أشعة أو فحص مخ (EEG / Brain Scan)')),
                      DropdownMenuItem(value: 'اختبار مقياس نفسي (Psychometric Test)', child: Text('اختبار مقياس نفسي (Psychometric Test)')),
                      DropdownMenuItem(value: 'أخرى (Other)', child: Text('أخرى (Other)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => fileType = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: locationCtrl,
                    decoration: const InputDecoration(labelText: 'المسار أو الرابط (File Location)'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey.shade800, foregroundColor: Colors.white),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(ctx);
                final ok = await ref.read(patientProvider.notifier).addPatientFile(
                      patient.patientId,
                      fileName: nameCtrl.text.trim(),
                      fileType: fileType,
                      fileLocation: locationCtrl.text.trim(),
                    );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(ok ? 'تم إرفاق الملف بنجاح' : 'تعذر حفظ الملف'),
                      backgroundColor: ok ? Colors.green.shade700 : Colors.red.shade700,
                    ),
                  );
                }
              },
              child: const Text('حفظ الملف'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddNoteDialog(BuildContext context, WidgetRef ref, PatientModel patient) {
    final formKey = GlobalKey<FormState>();
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.note_alt, color: Color(0xFF1B4F72)),
            SizedBox(width: 8),
            Text('إضافة ملاحظة سريرية سريعة'),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Form(
            key: formKey,
            child: TextFormField(
              controller: noteCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'نص الملاحظة (Note Text) *',
                hintText: 'دون ملاحظاتك السريعة التي تريد الرجوع إليها لاحقاً...',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'نص الملاحظة مطلوب' : null,
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B4F72), foregroundColor: Colors.white),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(ctx);
              final ok = await ref.read(patientProvider.notifier).addPatientNote(patient.patientId, noteText: noteCtrl.text.trim());
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok ? 'تمت إضافة الملاحظة بنجاح' : 'تعذر حفظ الملاحظة'),
                    backgroundColor: ok ? Colors.green.shade700 : Colors.red.shade700,
                  ),
                );
              }
            },
            child: const Text('إضافة الملاحظة'),
          ),
        ],
      ),
    );
  }
}
