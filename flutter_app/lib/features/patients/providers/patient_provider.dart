import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/patient_model.dart';

class PatientState {
  final List<PatientModel> searchResults;
  final PatientModel? selectedPatient;
  final bool isLoading;
  final String? errorMessage;
  final List<String> duplicateWarnings;

  PatientState({
    this.searchResults = const [],
    this.selectedPatient,
    this.isLoading = false,
    this.errorMessage,
    this.duplicateWarnings = const [],
  });

  PatientState copyWith({
    List<PatientModel>? searchResults,
    PatientModel? selectedPatient,
    bool? isLoading,
    String? errorMessage,
    List<String>? duplicateWarnings,
  }) {
    return PatientState(
      searchResults: searchResults ?? this.searchResults,
      selectedPatient: selectedPatient ?? this.selectedPatient,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      duplicateWarnings: duplicateWarnings ?? this.duplicateWarnings,
    );
  }
}

final patientProvider = StateNotifierProvider<PatientNotifier, PatientState>((ref) {
  final apiClient = ref.read(apiClientProvider);
  ref.watch(authProvider.select((s) => '${s.isAuthenticated}_${s.user?.staffId}_${s.user?.role}'));
  return PatientNotifier(apiClient);
});

class PatientNotifier extends StateNotifier<PatientState> {
  final ApiClient _apiClient;

  PatientNotifier(this._apiClient) : super(PatientState()) {
    searchPatients('');
  }

  // Pre-populated offline demo patients for when the tablet is not connected to the backend
  final List<PatientModel> _offlinePatients = [
    PatientModel(
      patientId: 'pat-001',
      mrn: 'MRN-00012',
      nameAr: 'أحمد محمود السعيد',
      nameEn: 'Ahmed Mahmoud El-Saeed',
      phone: '01012345678',
      email: 'ahmed.m@example.com',
      dob: DateTime(1992, 5, 14),
      sex: 'male',
      address: 'المعادي، القاهرة',
      psychiatricHistory: 'بدأت نوبات الهلع منذ 8 أشهر بعد ضغوط في العمل. لا توجد محاولات إيذاء للنفس. تاريخ سابق باكتئاب خفيف عولج ذاتياً عام 2021.',
      medicalHistory: 'ضغط دم انقباضي منتظم. لا توجد أمراض مزمنة.',
      familyHistory: 'الوالدة تعاني من اضطراب قلق معمم (GAD).',
      socialHistory: 'متزوج، مهندس برمجيات، غير مدخن، لا يتناول الكحوليات.',
      allergies: ['Penicillin'],
      diagnoses: [
        DiagnosisItem(
          diagnosisId: 'diag-001',
          icd10Code: 'F41.0',
          descriptionAr: 'اضطراب الهلع (Panic Disorder)',
          descriptionEn: 'Panic disorder without agoraphobia',
          dateDiagnosed: DateTime(2026, 2, 10),
          status: 'active',
        ),
      ],
      medications: [
        MedicationItem(
          medicationId: 'med-001',
          nameAr: 'إسيتالوبرام (سبرالكس)',
          nameEn: 'Escitalopram',
          dose: '10 mg',
          frequency: 'مرة واحدة صباحاً',
          notes: 'البدء بنصف قرص (5 مجم) لمدة أسبوع لتجنب الغثيان الأولي',
          isActive: true,
        ),
        MedicationItem(
          medicationId: 'med-002',
          nameAr: 'ألبرازولام (زانكس)',
          nameEn: 'Alprazolam',
          dose: '0.25 mg',
          frequency: 'عند اللزوم فقط (PRN)',
          notes: 'ممنوع الاستخدام المنتظم — للسيطرة على نوبات الهلع الشديدة فقط وبحد أقصى مرتين أسبوعياً',
          isActive: true,
        ),
      ],
      sessionHistory: [
        SessionSummaryItem(
          sessionId: 'ses-001',
          startedAt: DateTime(2026, 2, 10, 10, 0),
          status: 'finalized',
          noteSnippet: 'الجلسة الاستكشافية الأولى: شكوى من تسارع دقات القلب وضيق التنفس وشعور باقتراب الموت. تم شرح النموذج النفسي لنوبات الهلع واستبعاد الأسباب العضوية.',
        ),
        SessionSummaryItem(
          sessionId: 'ses-002',
          startedAt: DateTime(2026, 3, 2, 11, 0),
          status: 'finalized',
          noteSnippet: 'المتابعة بعد 3 أسابيع: انخفاض تكرار النوبات من 4 أسبوعياً إلى نوبة واحدة. المريض ملتزم بالدواء دون أعراض جانبية ملحوظة.',
        ),
      ],
    ),
    PatientModel(
      patientId: 'pat-002',
      mrn: 'MRN-00015',
      nameAr: 'مريم عادل الشناوي',
      nameEn: 'Mariam Adel El-Shennawy',
      phone: '01123456789',
      dob: DateTime(1998, 11, 23),
      sex: 'female',
      address: 'مصر الجديدة، القاهرة',
      psychiatricHistory: 'وسواس قهري (أفكار تلوث وغسيل يدين متكرر) منذ المراهقة، تفاقم بعد ولادة طفلها الأول.',
      allergies: ['Sulfa'],
      diagnoses: [
        DiagnosisItem(
          diagnosisId: 'diag-002',
          icd10Code: 'F42.0',
          descriptionAr: 'اضطراب الوسواس القهري (OCD)',
          descriptionEn: 'Predominantly obsessional thoughts or ruminations',
          dateDiagnosed: DateTime(2026, 1, 15),
          status: 'active',
        ),
      ],
      medications: [
        MedicationItem(
          medicationId: 'med-003',
          nameAr: 'فلوفوكسامين (فافيرين)',
          nameEn: 'Fluvoxamine',
          dose: '100 mg',
          frequency: 'مساءً قبل النوم',
          isActive: true,
        ),
      ],
    ),
  ];

  Future<void> searchPatients(String query) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    final res = await _apiClient.getList(
      '/patients',
      queryParams: query.isNotEmpty ? {'q': query} : null,
    );

    if (res.isSuccess && res.data != null) {
      final list = res.data!
          .map((e) => PatientModel.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(isLoading: false, searchResults: list);
    } else {
      // Offline fallback
      final filtered = query.trim().isEmpty
          ? _offlinePatients
          : _offlinePatients.where((p) {
              return p.nameAr.contains(query) ||
                  p.mrn.toLowerCase().contains(query.toLowerCase()) ||
                  (p.phone?.contains(query) ?? false);
            }).toList();

      state = state.copyWith(isLoading: false, searchResults: filtered);
    }
  }

  Future<void> selectPatient(String patientId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    final res = await _apiClient.get('/patients/$patientId');

    if (res.isSuccess && res.data != null) {
      final patient = PatientModel.fromJson(res.data!);
      state = state.copyWith(isLoading: false, selectedPatient: patient);
    } else {
      // Offline fallback
      final p = _offlinePatients.firstWhere(
        (e) => e.patientId == patientId,
        orElse: () => _offlinePatients.first,
      );
      state = state.copyWith(isLoading: false, selectedPatient: p);
    }
  }

  Future<bool> createPatient({
    required String nameAr,
    String? nameEn,
    String? phone,
    String? email,
    DateTime? dob,
    String? sex,
  }) async {
    state = state.copyWith(isLoading: true, duplicateWarnings: []);

    final body = {
      'name_ar': nameAr.trim(),
      if (nameEn != null && nameEn.isNotEmpty) 'name_en': nameEn.trim(),
      if (phone != null && phone.isNotEmpty) 'phone': phone.trim(),
      if (email != null && email.isNotEmpty) 'email': email.trim(),
      if (dob != null) 'dob': dob.toIso8601String().substring(0, 10),
      if (sex != null) 'sex': sex,
    };

    final res = await _apiClient.post('/patients', body: body);

    if (res.isSuccess && res.data != null) {
      final data = res.data!;
      final warnings = (data['duplicate_warnings'] as List?)?.map((e) => e.toString()).toList() ?? [];
      
      await searchPatients('');
      state = state.copyWith(isLoading: false, duplicateWarnings: warnings);
      return true;
    } else {
      // Create locally in offline list
      final newPat = PatientModel(
        patientId: 'local-${DateTime.now().millisecondsSinceEpoch}',
        mrn: 'MRN-${(30 + _offlinePatients.length).toString().padLeft(5, '0')}',
        nameAr: nameAr,
        nameEn: nameEn,
        phone: phone,
        email: email,
        dob: dob,
        sex: sex,
      );
      _offlinePatients.insert(0, newPat);
      state = state.copyWith(
        isLoading: false,
        searchResults: List.from(_offlinePatients),
      );
      return true;
    }
  }

  Future<bool> updatePatientInfo(String patientId, Map<String, dynamic> body) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    final res = await _apiClient.put('/patients/$patientId', body: body);

    if (res.isSuccess && res.data != null) {
      final updated = PatientModel.fromJson(res.data!);
      state = state.copyWith(
        isLoading: false,
        selectedPatient: updated,
      );
      await searchPatients('');
      return true;
    } else {
      // Local offline fallback
      if (state.selectedPatient != null && state.selectedPatient!.patientId == patientId) {
        final current = state.selectedPatient!;
        final updated = PatientModel(
          patientId: current.patientId,
          mrn: current.mrn,
          nameAr: body['name_ar'] ?? current.nameAr,
          nameEn: body['name_en'] ?? current.nameEn,
          phone: body['phone'] ?? current.phone,
          email: body['email'] ?? current.email,
          dob: body['dob'] != null ? DateTime.tryParse(body['dob']) : current.dob,
          sex: body['sex'] ?? current.sex,
          nationalId: body['national_id'] ?? current.nationalId,
          address: body['address'] ?? current.address,
          occupation: body['occupation'] ?? current.occupation,
          maritalStatus: body['marital_status'] ?? current.maritalStatus,
          children: body['children'] ?? current.children,
          firstSessionDate: body['first_session_date'] != null ? DateTime.tryParse(body['first_session_date']) : current.firstSessionDate,
          lastSessionDate: body['last_session_date'] != null ? DateTime.tryParse(body['last_session_date']) : current.lastSessionDate,
          medicalHistory: current.medicalHistory,
          psychiatricHistory: current.psychiatricHistory,
          familyHistory: current.familyHistory,
          socialHistory: current.socialHistory,
          history: current.history,
          psychiatricExaminations: current.psychiatricExaminations,
          physicalNeurologicalExam: current.physicalNeurologicalExam,
          riskAssessment: current.riskAssessment,
          suicideAttempts: current.suicideAttempts,
          admittedBefore: current.admittedBefore,
          notes: current.notes,
          allergies: current.allergies,
          diagnoses: current.diagnoses,
          medications: current.medications,
          sessionHistory: current.sessionHistory,
          files: current.files,
          quickNotes: current.quickNotes,
        );
        state = state.copyWith(isLoading: false, selectedPatient: updated);
        return true;
      }
      state = state.copyWith(isLoading: false, errorMessage: res.errorMessage);
      return false;
    }
  }

  Future<bool> updateClinicalHistory(String patientId, {
    String? medicalHistory,
    String? psychiatricHistory,
    String? familyHistory,
    String? socialHistory,
    String? history,
    String? psychiatricExaminations,
    String? physicalNeurologicalExam,
    String? riskAssessment,
    String? suicideAttempts,
    String? admittedBefore,
    String? notes,
    List<String>? allergies,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    final body = <String, dynamic>{};
    if (medicalHistory != null) body['medical_history'] = medicalHistory;
    if (psychiatricHistory != null) body['psychiatric_history'] = psychiatricHistory;
    if (familyHistory != null) body['family_history'] = familyHistory;
    if (socialHistory != null) body['social_history'] = socialHistory;
    if (history != null) body['history'] = history;
    if (psychiatricExaminations != null) body['psychiatric_examinations'] = psychiatricExaminations;
    if (physicalNeurologicalExam != null) body['physical_neurological_exam'] = physicalNeurologicalExam;
    if (riskAssessment != null) body['risk_assessment'] = riskAssessment;
    if (suicideAttempts != null) body['suicide_attempts'] = suicideAttempts;
    if (admittedBefore != null) body['admitted_before'] = admittedBefore;
    if (notes != null) body['notes'] = notes;
    if (allergies != null) body['allergies'] = allergies;

    final res = await _apiClient.post('/clinical/patients/$patientId/clinical', body: body);

    if (res.isSuccess) {
      await selectPatient(patientId);
      return true;
    } else {
      // Local offline fallback
      if (state.selectedPatient != null && state.selectedPatient!.patientId == patientId) {
        final current = state.selectedPatient!;
        final updated = PatientModel(
          patientId: current.patientId,
          mrn: current.mrn,
          nameAr: current.nameAr,
          nameEn: current.nameEn,
          phone: current.phone,
          email: current.email,
          dob: current.dob,
          sex: current.sex,
          nationalId: current.nationalId,
          address: current.address,
          occupation: current.occupation,
          maritalStatus: current.maritalStatus,
          children: current.children,
          firstSessionDate: current.firstSessionDate,
          lastSessionDate: current.lastSessionDate,
          medicalHistory: medicalHistory ?? current.medicalHistory,
          psychiatricHistory: psychiatricHistory ?? current.psychiatricHistory,
          familyHistory: familyHistory ?? current.familyHistory,
          socialHistory: socialHistory ?? current.socialHistory,
          history: history ?? current.history,
          psychiatricExaminations: psychiatricExaminations ?? current.psychiatricExaminations,
          physicalNeurologicalExam: physicalNeurologicalExam ?? current.physicalNeurologicalExam,
          riskAssessment: riskAssessment ?? current.riskAssessment,
          suicideAttempts: suicideAttempts ?? current.suicideAttempts,
          admittedBefore: admittedBefore ?? current.admittedBefore,
          notes: notes ?? current.notes,
          allergies: allergies ?? current.allergies,
          diagnoses: current.diagnoses,
          medications: current.medications,
          sessionHistory: current.sessionHistory,
          files: current.files,
          quickNotes: current.quickNotes,
        );
        state = state.copyWith(isLoading: false, selectedPatient: updated);
        return true;
      }
      state = state.copyWith(isLoading: false, errorMessage: res.errorMessage);
      return false;
    }
  }

  Future<bool> addDiagnosis(String patientId, {
    required String descriptionAr,
    String? descriptionEn,
    String? icd10Code,
    String status = 'active',
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    final body = {
      'description_ar': descriptionAr.trim(),
      if (descriptionEn != null) 'description_en': descriptionEn.trim(),
      if (icd10Code != null) 'icd10_code': icd10Code.trim(),
      'status': status,
      'date_diagnosed': DateTime.now().toIso8601String().substring(0, 10),
    };

    final res = await _apiClient.post('/clinical/patients/$patientId/diagnoses', body: body);

    if (res.isSuccess) {
      await selectPatient(patientId);
      return true;
    } else {
      // Offline fallback
      if (state.selectedPatient != null && state.selectedPatient!.patientId == patientId) {
        final current = state.selectedPatient!;
        final newDiag = DiagnosisItem(
          diagnosisId: 'diag-local-${DateTime.now().millisecondsSinceEpoch}',
          descriptionAr: descriptionAr,
          descriptionEn: descriptionEn,
          icd10Code: icd10Code,
          dateDiagnosed: DateTime.now(),
          status: status,
        );
        final updated = PatientModel(
          patientId: current.patientId,
          mrn: current.mrn,
          nameAr: current.nameAr,
          nameEn: current.nameEn,
          phone: current.phone,
          email: current.email,
          dob: current.dob,
          sex: current.sex,
          nationalId: current.nationalId,
          address: current.address,
          occupation: current.occupation,
          maritalStatus: current.maritalStatus,
          children: current.children,
          firstSessionDate: current.firstSessionDate,
          lastSessionDate: current.lastSessionDate,
          medicalHistory: current.medicalHistory,
          psychiatricHistory: current.psychiatricHistory,
          familyHistory: current.familyHistory,
          socialHistory: current.socialHistory,
          history: current.history,
          psychiatricExaminations: current.psychiatricExaminations,
          physicalNeurologicalExam: current.physicalNeurologicalExam,
          riskAssessment: current.riskAssessment,
          suicideAttempts: current.suicideAttempts,
          admittedBefore: current.admittedBefore,
          notes: current.notes,
          allergies: current.allergies,
          diagnoses: [newDiag, ...current.diagnoses],
          medications: current.medications,
          sessionHistory: current.sessionHistory,
          files: current.files,
          quickNotes: current.quickNotes,
        );
        state = state.copyWith(isLoading: false, selectedPatient: updated);
        return true;
      }
      state = state.copyWith(isLoading: false, errorMessage: res.errorMessage);
      return false;
    }
  }

  Future<bool> addMedication(String patientId, {
    required String nameAr,
    String? nameEn,
    String? dose,
    String? frequency,
    String? route,
    String? duration,
    DateTime? date,
    String? notes,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    final body = {
      'name_ar': nameAr.trim(),
      if (nameEn != null) 'name_en': nameEn.trim(),
      if (dose != null) 'dose': dose.trim(),
      if (frequency != null) 'frequency': frequency.trim(),
      if (route != null) 'route': route.trim(),
      if (duration != null) 'duration': duration.trim(),
      if (date != null) 'date': date.toIso8601String().substring(0, 10),
      if (notes != null) 'notes': notes.trim(),
    };

    final res = await _apiClient.post('/clinical/patients/$patientId/medications', body: body);

    if (res.isSuccess) {
      await selectPatient(patientId);
      return true;
    } else {
      // Offline fallback
      if (state.selectedPatient != null && state.selectedPatient!.patientId == patientId) {
        final current = state.selectedPatient!;
        final newMed = MedicationItem(
          medicationId: 'med-local-${DateTime.now().millisecondsSinceEpoch}',
          nameAr: nameAr,
          nameEn: nameEn,
          dose: dose,
          frequency: frequency,
          route: route,
          duration: duration,
          date: date ?? DateTime.now(),
          notes: notes,
          isActive: true,
        );
        final updated = PatientModel(
          patientId: current.patientId,
          mrn: current.mrn,
          nameAr: current.nameAr,
          nameEn: current.nameEn,
          phone: current.phone,
          email: current.email,
          dob: current.dob,
          sex: current.sex,
          nationalId: current.nationalId,
          address: current.address,
          occupation: current.occupation,
          maritalStatus: current.maritalStatus,
          children: current.children,
          firstSessionDate: current.firstSessionDate,
          lastSessionDate: current.lastSessionDate,
          medicalHistory: current.medicalHistory,
          psychiatricHistory: current.psychiatricHistory,
          familyHistory: current.familyHistory,
          socialHistory: current.socialHistory,
          history: current.history,
          psychiatricExaminations: current.psychiatricExaminations,
          physicalNeurologicalExam: current.physicalNeurologicalExam,
          riskAssessment: current.riskAssessment,
          suicideAttempts: current.suicideAttempts,
          admittedBefore: current.admittedBefore,
          notes: current.notes,
          allergies: current.allergies,
          diagnoses: current.diagnoses,
          medications: [newMed, ...current.medications],
          sessionHistory: current.sessionHistory,
          files: current.files,
          quickNotes: current.quickNotes,
        );
        state = state.copyWith(isLoading: false, selectedPatient: updated);
        return true;
      }
      state = state.copyWith(isLoading: false, errorMessage: res.errorMessage);
      return false;
    }
  }

  Future<bool> addPatientFile(String patientId, {
    required String fileName,
    required String fileType,
    required String fileLocation,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    final body = {
      'file_name': fileName.trim(),
      'file_type': fileType.trim(),
      'file_location': fileLocation.trim(),
    };

    final res = await _apiClient.post('/clinical/patients/$patientId/files', body: body);

    if (res.isSuccess) {
      await selectPatient(patientId);
      return true;
    } else {
      // Offline fallback
      if (state.selectedPatient != null && state.selectedPatient!.patientId == patientId) {
        final current = state.selectedPatient!;
        final newFile = PatientFileItem(
          fileId: 'file-local-${DateTime.now().millisecondsSinceEpoch}',
          fileName: fileName,
          fileType: fileType,
          fileLocation: fileLocation,
          createdAt: DateTime.now(),
        );
        final updated = PatientModel(
          patientId: current.patientId,
          mrn: current.mrn,
          nameAr: current.nameAr,
          nameEn: current.nameEn,
          phone: current.phone,
          email: current.email,
          dob: current.dob,
          sex: current.sex,
          nationalId: current.nationalId,
          address: current.address,
          occupation: current.occupation,
          maritalStatus: current.maritalStatus,
          children: current.children,
          firstSessionDate: current.firstSessionDate,
          lastSessionDate: current.lastSessionDate,
          medicalHistory: current.medicalHistory,
          psychiatricHistory: current.psychiatricHistory,
          familyHistory: current.familyHistory,
          socialHistory: current.socialHistory,
          history: current.history,
          psychiatricExaminations: current.psychiatricExaminations,
          physicalNeurologicalExam: current.physicalNeurologicalExam,
          riskAssessment: current.riskAssessment,
          suicideAttempts: current.suicideAttempts,
          admittedBefore: current.admittedBefore,
          notes: current.notes,
          allergies: current.allergies,
          diagnoses: current.diagnoses,
          medications: current.medications,
          sessionHistory: current.sessionHistory,
          files: [newFile, ...current.files],
          quickNotes: current.quickNotes,
        );
        state = state.copyWith(isLoading: false, selectedPatient: updated);
        return true;
      }
      state = state.copyWith(isLoading: false, errorMessage: res.errorMessage);
      return false;
    }
  }

  Future<bool> addPatientNote(String patientId, {required String noteText}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    final body = {'note_text': noteText.trim()};
    final res = await _apiClient.post('/clinical/patients/$patientId/notes', body: body);

    if (res.isSuccess) {
      await selectPatient(patientId);
      return true;
    } else {
      // Offline fallback
      if (state.selectedPatient != null && state.selectedPatient!.patientId == patientId) {
        final current = state.selectedPatient!;
        final newNote = PatientNoteItem(
          noteId: 'note-local-${DateTime.now().millisecondsSinceEpoch}',
          noteText: noteText,
          lastModified: DateTime.now(),
        );
        final updated = PatientModel(
          patientId: current.patientId,
          mrn: current.mrn,
          nameAr: current.nameAr,
          nameEn: current.nameEn,
          phone: current.phone,
          email: current.email,
          dob: current.dob,
          sex: current.sex,
          nationalId: current.nationalId,
          address: current.address,
          occupation: current.occupation,
          maritalStatus: current.maritalStatus,
          children: current.children,
          firstSessionDate: current.firstSessionDate,
          lastSessionDate: current.lastSessionDate,
          medicalHistory: current.medicalHistory,
          psychiatricHistory: current.psychiatricHistory,
          familyHistory: current.familyHistory,
          socialHistory: current.socialHistory,
          history: current.history,
          psychiatricExaminations: current.psychiatricExaminations,
          physicalNeurologicalExam: current.physicalNeurologicalExam,
          riskAssessment: current.riskAssessment,
          suicideAttempts: current.suicideAttempts,
          admittedBefore: current.admittedBefore,
          notes: current.notes,
          allergies: current.allergies,
          diagnoses: current.diagnoses,
          medications: current.medications,
          sessionHistory: current.sessionHistory,
          files: current.files,
          quickNotes: [newNote, ...current.quickNotes],
        );
        state = state.copyWith(isLoading: false, selectedPatient: updated);
        return true;
      }
      state = state.copyWith(isLoading: false, errorMessage: res.errorMessage);
      return false;
    }
  }

  Future<bool> deletePatientNote(String patientId, String noteId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final res = await _apiClient.delete('/clinical/patients/$patientId/notes/$noteId');

    if (res.isSuccess) {
      await selectPatient(patientId);
      return true;
    } else {
      if (state.selectedPatient != null && state.selectedPatient!.patientId == patientId) {
        final current = state.selectedPatient!;
        final updatedNotes = current.quickNotes.where((n) => n.noteId != noteId).toList();
        final updated = PatientModel(
          patientId: current.patientId,
          mrn: current.mrn,
          nameAr: current.nameAr,
          nameEn: current.nameEn,
          phone: current.phone,
          email: current.email,
          dob: current.dob,
          sex: current.sex,
          nationalId: current.nationalId,
          address: current.address,
          occupation: current.occupation,
          maritalStatus: current.maritalStatus,
          children: current.children,
          firstSessionDate: current.firstSessionDate,
          lastSessionDate: current.lastSessionDate,
          medicalHistory: current.medicalHistory,
          psychiatricHistory: current.psychiatricHistory,
          familyHistory: current.familyHistory,
          socialHistory: current.socialHistory,
          history: current.history,
          psychiatricExaminations: current.psychiatricExaminations,
          physicalNeurologicalExam: current.physicalNeurologicalExam,
          riskAssessment: current.riskAssessment,
          suicideAttempts: current.suicideAttempts,
          admittedBefore: current.admittedBefore,
          notes: current.notes,
          allergies: current.allergies,
          diagnoses: current.diagnoses,
          medications: current.medications,
          sessionHistory: current.sessionHistory,
          files: current.files,
          quickNotes: updatedNotes,
        );
        state = state.copyWith(isLoading: false, selectedPatient: updated);
        return true;
      }
      state = state.copyWith(isLoading: false, errorMessage: res.errorMessage);
      return false;
    }
  }
}
