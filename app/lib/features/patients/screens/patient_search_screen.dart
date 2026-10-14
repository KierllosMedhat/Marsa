import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/patient_provider.dart';
import 'patient_detail_screen.dart';
import 'patient_create_screen.dart';

class PatientSearchScreen extends ConsumerStatefulWidget {
  const PatientSearchScreen({super.key});

  @override
  ConsumerState<PatientSearchScreen> createState() => _PatientSearchScreenState();
}

class _PatientSearchScreenState extends ConsumerState<PatientSearchScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final patientState = ref.watch(patientProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('البحث في سجلات المرضى'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: 'إضافة مريض جديد',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PatientCreateScreen()),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Search Input
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'ابحث بالاسم العربي، رقم الملف (MRN)، أو رقم الهاتف...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(patientProvider.notifier).searchPatients('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (val) {
                ref.read(patientProvider.notifier).searchPatients(val);
              },
            ),
            const SizedBox(height: 16),

            // Search Results Count
            Row(
              children: [
                Text(
                  'نتائج البحث: ${patientState.searchResults.length} مريض',
                  style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Results List
            Expanded(
              child: patientState.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : patientState.searchResults.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_search, size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 12),
                              const Text('لا يوجد مرضى مطابقون لمعايير البحث'),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: patientState.searchResults.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (ctx, idx) {
                            final patient = patientState.searchResults[idx];
                            return Card(
                              elevation: 1.5,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: theme.primaryColor.withAlpha(30),
                                  child: Icon(Icons.person, color: theme.primaryColor),
                                ),
                                title: Row(
                                  children: [
                                    Text(
                                      patient.nameAr,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.blueGrey.shade100,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        patient.mrn,
                                        style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade800),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Text(
                                  [
                                    if (patient.phone != null) 'هاتف: ${patient.phone}',
                                    if (patient.sex != null) 'النوع: ${patient.sex == 'male' ? 'ذكر' : 'أنثى'}',
                                    if (patient.address != null) patient.address!,
                                  ].join(' | '),
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                ),
                                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                                onTap: () {
                                  ref.read(patientProvider.notifier).selectPatient(patient.patientId);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => PatientDetailScreen(patientId: patient.patientId),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
