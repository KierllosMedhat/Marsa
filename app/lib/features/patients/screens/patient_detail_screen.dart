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
                  _buildHistoryTab(patient),
                  _buildDiagnosesTab(patient),
                  _buildMedicationsTab(patient),
                  _buildSessionHistoryTab(patient),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTab(PatientModel patient) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
        ],
      ),
    );
  }

  Widget _buildClinicalSectionCard({
    required String title,
    required IconData icon,
    required String content,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: const Color(0xFF1B4F72)),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1B4F72)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              content,
              style: const TextStyle(fontSize: 14, height: 1.6, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiagnosesTab(PatientModel patient) {
    if (patient.diagnoses.isEmpty) {
      return const Center(child: Text('لا توجد تشخيصات مسجلة للمريض حتى الآن'));
    }

    return ListView.builder(
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
              label: Text(d.status == 'active' ? 'نشط' : d.status),
              backgroundColor: d.status == 'active' ? Colors.green.shade100 : Colors.grey.shade200,
            ),
          ),
        );
      },
    );
  }

  Widget _buildMedicationsTab(PatientModel patient) {
    if (patient.medications.isEmpty) {
      return const Center(child: Text('لا توجد أدوية مسجلة في خطة المريض'));
    }

    return ListView.builder(
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
                  ],
                ),
                if (m.notes != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'تعليمات: ${m.notes}',
                    style: TextStyle(color: Colors.grey[700], fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
        );
      },
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
}
