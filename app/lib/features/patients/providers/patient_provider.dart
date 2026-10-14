import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
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
}
