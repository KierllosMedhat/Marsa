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

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text('الملف الطبي — ${patient.nameAr}'),
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
              Tab(icon: Icon(Icons.psychology_outlined), text: 'التاريخ النفسي والطبي'),
              Tab(icon: Icon(Icons.assignment_outlined), text: 'التشخيصات المسجلة'),
              Tab(icon: Icon(Icons.medication_outlined), text: 'الخطة الدوائية'),
              Tab(icon: Icon(Icons.history_edu_outlined), text: 'سجل الجلسات السابقة'),
            ],
          ),
        ),
        body: Column(
          children: [
            // Patient Header Info Strip
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: theme.primaryColor.withAlpha(25),
                    child: Icon(Icons.person, size: 36, color: theme.primaryColor),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              patient.nameAr,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blueGrey.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                patient.mrn,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueGrey.shade900,
                                ),
                              ),
                            ),
                            if (patient.sex != null) ...[
                              const SizedBox(width: 8),
                              Text(
                                '(${patient.sex == 'male' ? 'ذكر' : 'أنثى'})',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (patient.phone != null) ...[
                              Icon(Icons.phone, size: 14, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(patient.phone!, style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                              const SizedBox(width: 16),
                            ],
                            if (patient.address != null) ...[
                              Icon(Icons.location_on_outlined, size: 14, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(patient.address!, style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Allergies Alert Warning
                  if (patient.allergies.isNotEmpty)
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
                  const SizedBox(width: 16),

                  // Edit Demographics Button
                  OutlinedButton.icon(
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('تعديل البيانات'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    ),
                    onPressed: () => _showEditDemographicsDialog(context, ref, patient),
                  ),
                  const SizedBox(width: 10),

                  // Start Session Button
                  ElevatedButton.icon(
                    icon: const Icon(Icons.edit_note),
                    label: const Text('بدء جلسة جديدة لهذا المريض'),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTab(BuildContext context, WidgetRef ref, PatientModel patient) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'الملف السريري والتاريخ الطبي الكامل',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.edit_note, size: 20),
                label: const Text('تعديل التاريخ السريري والحساسية'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B4F72),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onPressed: () => _showEditClinicalHistoryDialog(context, ref, patient),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildClinicalSectionCard(
            title: 'التاريخ النفسي (Psychiatric History)',
            icon: Icons.psychology,
            content: patient.psychiatricHistory ?? 'لا يوجد تاريخ نفسي مدون سابقاً.',
          ),
          const SizedBox(height: 16),
          _buildClinicalSectionCard(
            title: 'التاريخ الطبي والجراحي (Medical & Surgical History)',
            icon: Icons.local_hospital_outlined,
            content: patient.medicalHistory ?? 'لا توجد أمراض طبية مزمنة أو جراحات مسجلة.',
          ),
          const SizedBox(height: 16),
          _buildClinicalSectionCard(
            title: 'التاريخ العائلي (Family Psychiatric History)',
            icon: Icons.family_restroom,
            content: patient.familyHistory ?? 'لا يوجد تاريخ عائلي لاضطرابات نفسية.',
          ),
          const SizedBox(height: 16),
          _buildClinicalSectionCard(
            title: 'التاريخ الاجتماعي ونمط الحياة (Social History)',
            icon: Icons.people_outline,
            content: patient.socialHistory ?? 'لا توجد ملاحظات اجتماعية مسجلة.',
          ),
          const SizedBox(height: 16),
          _buildClinicalSectionCard(
            title: 'الحساسية الدوائية (Drug Allergies)',
            icon: Icons.warning_amber_rounded,
            content: patient.allergies.isEmpty ? 'لا توجد حساسية دوائية مسجلة.' : patient.allergies.join('، '),
            isAlert: patient.allergies.isNotEmpty,
          ),
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
              children: [
                Icon(icon, size: 20, color: isAlert ? Colors.red.shade700 : const Color(0xFF1B4F72)),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isAlert ? Colors.red.shade900 : const Color(0xFF1B4F72),
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

  Widget _buildDiagnosesTab(BuildContext context, WidgetRef ref, PatientModel patient) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          color: Colors.grey.shade50,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'التشخيصات المسجلة (${patient.diagnoses.length})',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('إضافة تشخيص جديد'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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

  Widget _buildMedicationsTab(BuildContext context, WidgetRef ref, PatientModel patient) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          color: Colors.grey.shade50,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'الخطة الدوائية الحالية (${patient.medications.length})',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('إضافة دواء للخطة'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                  padding: const EdgeInsets.all(20),
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                            Row(
                              children: [
                                if (m.dose != null) ...[
                                  Chip(label: Text('الجرعة: ${m.dose}')),
                                  const SizedBox(width: 8),
                                ],
                                if (m.frequency != null)
                                  Chip(label: Text('التكرار: ${m.frequency}')),
                                if (m.route != null) ...[
                                  const SizedBox(width: 8),
                                  Chip(label: Text('طريقة الاستخدام: ${m.route}')),
                                ],
                              ],
                            ),
                            if (m.notes != null) ...[
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

  Widget _buildSessionHistoryTab(PatientModel patient) {
    if (patient.sessionHistory.isEmpty) {
      return const Center(child: Text('لا توجد جلسات سابقة مسجلة'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'جلسة: ${DateFormat('yyyy/MM/dd — hh:mm a', 'ar').format(s.startedAt)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Chip(
                      label: Text(s.status == 'finalized' ? 'معتمدة نهائياً' : 'مسودة'),
                      backgroundColor: s.status == 'finalized' ? Colors.blue.shade50 : Colors.amber.shade50,
                    ),
                  ],
                ),
                if (s.noteSnippet != null) ...[
                  const SizedBox(height: 8),
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

  // --- Dialogs for Editing ---

  void _showEditDemographicsDialog(BuildContext context, WidgetRef ref, PatientModel patient) {
    final formKey = GlobalKey<FormState>();
    final nameArCtrl = TextEditingController(text: patient.nameAr);
    final nameEnCtrl = TextEditingController(text: patient.nameEn ?? '');
    final phoneCtrl = TextEditingController(text: patient.phone ?? '');
    final emailCtrl = TextEditingController(text: patient.email ?? '');
    final nationalIdCtrl = TextEditingController(text: patient.nationalId ?? '');
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
              Text('تعديل البيانات الشخصية للمريض'),
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
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.grey.shade400),
                      ),
                      leading: const Icon(Icons.calendar_today_outlined),
                      title: Text(
                        selectedDob != null
                            ? 'تاريخ الميلاد: ${DateFormat('yyyy/MM/dd').format(selectedDob!)}'
                            : 'تحديد تاريخ الميلاد',
                        style: TextStyle(color: selectedDob != null ? Colors.black87 : Colors.grey.shade600),
                      ),
                      trailing: const Icon(Icons.arrow_drop_down),
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
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: addressCtrl,
                      decoration: const InputDecoration(labelText: 'العنوان ومحل السكن', prefixIcon: Icon(Icons.home_outlined)),
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
                  if (addressCtrl.text.trim().isNotEmpty) 'address': addressCtrl.text.trim(),
                  if (selectedSex != null) 'sex': selectedSex,
                  if (selectedDob != null) 'dob': selectedDob!.toIso8601String().substring(0, 10),
                };

                final ok = await ref.read(patientProvider.notifier).updatePatientInfo(patient.patientId, body);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(ok ? 'تم تحديث البيانات الشخصية بنجاح' : 'تعذر حفظ البيانات'),
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
    final psychCtrl = TextEditingController(text: patient.psychiatricHistory ?? '');
    final medCtrl = TextEditingController(text: patient.medicalHistory ?? '');
    final famCtrl = TextEditingController(text: patient.familyHistory ?? '');
    final socCtrl = TextEditingController(text: patient.socialHistory ?? '');
    final allergiesCtrl = TextEditingController(text: patient.allergies.join('، '));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.psychology, color: Color(0xFF1B4F72)),
            SizedBox(width: 8),
            Text('تعديل الملف السريري والحساسية'),
          ],
        ),
        content: SizedBox(
          width: 580,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ملاحظة: جميع هذه البيانات مشفرة وتخضع لسرية الطبيب التامة.',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: psychCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'التاريخ النفسي (Psychiatric History)',
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
                    psychiatricHistory: psychCtrl.text.trim(),
                    medicalHistory: medCtrl.text.trim(),
                    familyHistory: famCtrl.text.trim(),
                    socialHistory: socCtrl.text.trim(),
                    allergies: rawAllergies,
                  );

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok ? 'تم تحديث التاريخ السريري بنجاح' : 'تعذر حفظ التاريخ السريري'),
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
          width: 500,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameArCtrl,
                    decoration: const InputDecoration(
                      labelText: 'اسم الدواء التجاري أو العلمي بالعربية *',
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
                            labelText: 'الجرعة',
                            hintText: 'مثال: 50 mg',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: freqCtrl,
                          decoration: const InputDecoration(
                            labelText: 'التكرار',
                            hintText: 'مثال: مرة يومياً بعد العشاء',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: routeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'طريقة التناول (Route)',
                      hintText: 'مثال: فموي، تحت اللسان، حقن عضلي',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: notesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظات وإرشادات للمريض',
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
}
